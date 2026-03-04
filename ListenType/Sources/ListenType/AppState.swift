import SwiftUI
import AppKit

enum RecordingState {
    case idle
    case recording
    case processing
}

@MainActor
class AppState: ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var ollamaAvailable: Bool = false
    private static var pollingStarted = false

    init() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !AppState.pollingStarted else { return }
            AppState.pollingStarted = true
            self.startOllamaPolling()
        }
    }

    var statusIcon: String {
        switch recordingState {
        case .idle: return "mic"
        case .recording: return "record.circle.fill"
        case .processing: return "hourglass"
        }
    }

    var statusText: String {
        switch recordingState {
        case .idle: return "Ready"
        case .recording: return "Recording..."
        case .processing: return "Processing..."
        }
    }

    func startOllamaPolling() {
        Task.detached {
            while true {
                let service = OllamaService()
                let available = await service.isAvailable()
                await MainActor.run { [weak self] in
                    self?.ollamaAvailable = available
                }
                debugLog("[Ollama] available: \(available)")
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
            }
        }
    }

    func playStartSound() {
        NSSound(named: .init("Tink"))?.play()
    }

    func playStopSound() {
        NSSound(named: .init("Pop"))?.play()
    }

    func playDoneSound() {
        NSSound(named: .init("Purr"))?.play()
    }

    func playErrorSound() {
        NSSound(named: .init("Basso"))?.play()
    }
}
