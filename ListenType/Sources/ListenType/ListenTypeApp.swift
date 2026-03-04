import SwiftUI

@main
struct ListenTypeApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var modelManager = ModelManager()
    private let hotKeyManager = HotKeyManager()
    private let recorder = AudioRecorder()
    private let whisperService = WhisperService()
    private let ollamaService = OllamaService()
    private let typeSimulator = TypeSimulator()
    private let overlay = StatusOverlayController()

    var body: some Scene {
        MenuBarExtra("ListenType", systemImage: appState.statusIcon) {
            MenuBarView(appState: appState, modelManager: modelManager)
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: modelManager.downloadedMB) { _ in
            if case .downloading = modelManager.state {
                overlay.showMessage("下載語音模型中… \(modelManager.downloadedMB) / \(modelManager.totalMB) MB", autoDismissAfter: 0)
            }
        }
        .onChange(of: modelManager.isReady) { ready in
            if ready {
                overlay.showMessage("模型下載完成，可以開始使用 ⌥S 錄音", autoDismissAfter: 4.0)
                appState.playDoneSound()
            }
        }
    }

    init() {
        hotKeyManager.onHotKeyPressed = { [appState, modelManager, recorder, whisperService, ollamaService, typeSimulator, overlay] in
            Task { @MainActor in
                // Block recording if model not ready
                guard modelManager.isReady else {
                    debugLog("[ListenType] Model not ready, ignoring hotkey")
                    if case .downloading = modelManager.state {
                        overlay.showMessage("模型下載中（\(modelManager.downloadedMB)/\(modelManager.totalMB) MB）…")
                    } else {
                        overlay.showMessage("模型尚未就緒")
                    }
                    appState.playErrorSound()
                    return
                }

                switch appState.recordingState {
                case .idle:
                    do {
                        let url = try recorder.startRecording()
                        appState.recordingState = .recording
                        overlay.show(state: .recording)
                        appState.playStartSound()
                        debugLog("[ListenType] Recording to: \(url.path)")
                    } catch {
                        appState.playErrorSound()
                        debugLog("[ListenType] Recording error: \(error)")
                    }
                case .recording:
                    guard let url = recorder.stopRecording() else { return }
                    appState.recordingState = .processing
                    overlay.show(state: .processing)
                    appState.playStopSound()
                    debugLog("[ListenType] Processing...")

                    Task.detached {
                        do {
                            let text = try await whisperService.transcribe(audioURL: url)
                            debugLog("[ListenType] Raw: \(text)")

                            var finalText = text
                            if await ollamaService.isAvailable() {
                                let polished = try await ollamaService.polish(text: text)
                                debugLog("[ListenType] Polished: \(polished)")
                                finalText = polished
                            } else {
                                debugLog("[ListenType] Ollama unavailable, using raw text")
                            }

                            await MainActor.run {
                                overlay.hide()
                            }
                            await typeSimulator.type(text: finalText)
                            debugLog("[ListenType] Done")

                            await MainActor.run {
                                appState.playDoneSound()
                                appState.recordingState = .idle
                            }
                        } catch {
                            debugLog("[ListenType] Error: \(error)")
                            await MainActor.run {
                                overlay.hide()
                                appState.playErrorSound()
                                appState.recordingState = .idle
                            }
                        }
                    }
                case .processing:
                    break
                }
            }
        }
        debugLog("App init starting...")
        hotKeyManager.start()
        debugLog("App init complete")
    }
}
