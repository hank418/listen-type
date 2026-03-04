# ListenType Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS menu bar app that uses Option+S to record speech, transcribe it locally with Whisper, polish with Ollama, and type the result into the active app.

**Architecture:** Swift macOS menu bar app using SwiftUI MenuBarExtra. Audio captured via AVAudioEngine, transcribed by whisper.cpp CLI (subprocess), polished by Ollama HTTP API, output via clipboard + CGEvent paste simulation.

**Tech Stack:** Swift/SwiftUI, AVAudioEngine, whisper.cpp (CLI), Ollama, CGEvent

---

### Task 1: Install Prerequisites

**Files:** None (system setup)

**Step 1: Install whisper.cpp**

```bash
cd /tmp
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp
make -j
```

**Step 2: Download Whisper small model**

```bash
cd /tmp/whisper.cpp
bash models/download-ggml-model.sh small
```

Expected: `models/ggml-small.bin` (466 MB) downloaded.

**Step 3: Test whisper.cpp works**

```bash
cd /tmp/whisper.cpp
# Record a short test audio (say something in Chinese)
# Or use the included sample:
./main -m models/ggml-small.bin -l zh -f samples/jfk.wav
```

Expected: Transcription output printed to terminal.

**Step 4: Install whisper.cpp to a stable location**

```bash
mkdir -p ~/tools/whisper.cpp
cp /tmp/whisper.cpp/main ~/tools/whisper.cpp/whisper-cli
cp -r /tmp/whisper.cpp/models ~/tools/whisper.cpp/models
```

**Step 5: Install Ollama**

```bash
brew install ollama
```

**Step 6: Start Ollama and pull a model**

```bash
ollama serve &
ollama pull gemma3:4b
```

Expected: `gemma3:4b` model downloaded and ready.

**Step 7: Test Ollama works**

```bash
curl -s http://localhost:11434/api/generate -d '{
  "model": "gemma3:4b",
  "prompt": "將以下口語整理成書面文字：嗯那個我覺得就是說這個東西其實還不錯啦",
  "stream": false
}' | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])"
```

Expected: Polished Chinese text output.

**Step 8: Commit**

```bash
# Nothing to commit yet - prerequisites installed
```

---

### Task 2: Create Swift Project Skeleton

**Files:**
- Create: `ListenType/Package.swift`
- Create: `ListenType/Sources/ListenType/ListenTypeApp.swift`
- Create: `ListenType/Sources/ListenType/AppState.swift`
- Create: `ListenType/Sources/ListenType/MenuBarView.swift`
- Create: `ListenType/Sources/ListenType/Info.plist`
- Create: `ListenType/Sources/ListenType/ListenType.entitlements`

**Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ListenType",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ListenType",
            path: "Sources/ListenType"
        )
    ]
)
```

**Step 2: Create AppState.swift**

```swift
import SwiftUI

enum RecordingState {
    case idle
    case recording
    case processing
}

@MainActor
class AppState: ObservableObject {
    @Published var recordingState: RecordingState = .idle

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
}
```

**Step 3: Create MenuBarView.swift**

```swift
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(appState.statusText)
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private var statusColor: Color {
        switch appState.recordingState {
        case .idle: return .gray
        case .recording: return .red
        case .processing: return .orange
        }
    }
}
```

**Step 4: Create ListenTypeApp.swift**

```swift
import SwiftUI

@main
struct ListenTypeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("ListenType", systemImage: appState.statusIcon) {
            MenuBarView(appState: appState)
        }
        .menuBarExtraStyle(.menu)
    }
}
```

**Step 5: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>ListenType needs microphone access to record your speech for transcription.</string>
</dict>
</plist>
```

**Step 6: Create entitlements file**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
```

**Step 7: Build and verify**

```bash
cd ListenType
swift build
```

Expected: Builds successfully.

**Step 8: Run and verify menu bar icon appears**

```bash
swift run &
# Look for microphone icon in menu bar
# Click it to see the menu
# Use "Quit" to exit
```

Expected: Mic icon in menu bar, clicking shows status + Quit button.

**Step 9: Commit**

```bash
git init
git add -A
git commit -m "feat: initial menu bar app skeleton with SwiftUI MenuBarExtra"
```

---

### Task 3: Add Global Hotkey (Option+S)

**Files:**
- Create: `ListenType/Sources/ListenType/HotKeyManager.swift`
- Modify: `ListenType/Sources/ListenType/ListenTypeApp.swift`

**Step 1: Create HotKeyManager.swift**

```swift
import Carbon
import CoreGraphics
import Cocoa

class HotKeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var onHotKeyPressed: (() -> Void)?

    func start() {
        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue)
        )

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, userInfo in
                guard let userInfo = userInfo else {
                    return Unmanaged.passUnretained(event)
                }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userInfo)
                    .takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = eventTap else {
            print("Failed to create event tap. Check Accessibility permissions.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Re-enable tap if it gets disabled by the system
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Option+S: keyCode 1 = 'S', maskAlternate = Option
        let isOptionOnly = flags.contains(.maskAlternate)
            && !flags.contains(.maskCommand)
            && !flags.contains(.maskControl)
            && !flags.contains(.maskShift)

        if keyCode == 1 && isOptionOnly {
            DispatchQueue.main.async {
                self.onHotKeyPressed?()
            }
            return nil // Swallow the event
        }

        return Unmanaged.passUnretained(event)
    }
}
```

**Step 2: Wire HotKeyManager into ListenTypeApp.swift**

Replace `ListenTypeApp.swift` with:

```swift
import SwiftUI

@main
struct ListenTypeApp: App {
    @StateObject private var appState = AppState()
    private let hotKeyManager = HotKeyManager()

    var body: some Scene {
        MenuBarExtra("ListenType", systemImage: appState.statusIcon) {
            MenuBarView(appState: appState)
        }
        .menuBarExtraStyle(.menu)
    }

    init() {
        hotKeyManager.onHotKeyPressed = { [appState] in
            Task { @MainActor in
                switch appState.recordingState {
                case .idle:
                    appState.recordingState = .recording
                    print("[ListenType] Recording started")
                case .recording:
                    appState.recordingState = .processing
                    print("[ListenType] Recording stopped, processing...")
                    // TODO: Process audio
                    try? await Task.sleep(for: .seconds(1))
                    appState.recordingState = .idle
                case .processing:
                    break // Ignore during processing
                }
            }
        }
        hotKeyManager.start()
    }
}
```

**Step 3: Build**

```bash
cd ListenType && swift build
```

Expected: Builds successfully.

**Step 4: Run and test hotkey**

```bash
swift run &
# Press Option+S — terminal should print "Recording started"
# Press Option+S again — should print "Recording stopped, processing..."
# Menu bar icon should change accordingly
```

Expected: Option+S toggles recording state, console prints state changes.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add global hotkey manager (Option+S)"
```

---

### Task 4: Add Audio Recording

**Files:**
- Create: `ListenType/Sources/ListenType/AudioRecorder.swift`
- Modify: `ListenType/Sources/ListenType/ListenTypeApp.swift`

**Step 1: Create AudioRecorder.swift**

```swift
import AVFoundation

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var outputURL: URL?

    func startRecording() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("listentype_recording.wav")
        self.outputURL = outputURL

        // Remove old file if exists
        try? FileManager.default.removeItem(at: outputURL)

        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Target format for Whisper: 16kHz, mono, 16-bit PCM
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        ) else {
            throw RecorderError.formatError
        }

        // Create converter
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw RecorderError.converterError
        }

        // Create output file
        audioFile = try AVAudioFile(
            forWriting: outputURL,
            settings: targetFormat.settings
        )

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
            [weak self] buffer, _ in
            guard let self = self, let audioFile = self.audioFile else { return }

            let frameCount = AVAudioFrameCount(
                Double(buffer.frameLength) * 16000.0 / inputFormat.sampleRate
            )
            guard frameCount > 0 else { return }

            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: frameCount
            ) else { return }

            var error: NSError?
            var consumed = false
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                if consumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                consumed = true
                outStatus.pointee = .haveData
                return buffer
            }

            if error == nil && convertedBuffer.frameLength > 0 {
                try? audioFile.write(from: convertedBuffer)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        return outputURL
    }

    func stopRecording() -> URL? {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        return outputURL
    }

    enum RecorderError: Error {
        case formatError
        case converterError
    }
}
```

**Step 2: Wire AudioRecorder into ListenTypeApp.swift**

Replace the `init()` in ListenTypeApp:

```swift
init() {
    let recorder = AudioRecorder()

    hotKeyManager.onHotKeyPressed = { [appState] in
        Task { @MainActor in
            switch appState.recordingState {
            case .idle:
                do {
                    let url = try recorder.startRecording()
                    appState.recordingState = .recording
                    print("[ListenType] Recording to: \(url.path)")
                } catch {
                    print("[ListenType] Recording error: \(error)")
                }
            case .recording:
                if let url = recorder.stopRecording() {
                    appState.recordingState = .processing
                    print("[ListenType] Saved: \(url.path)")
                    // TODO: Transcribe
                    appState.recordingState = .idle
                }
            case .processing:
                break
            }
        }
    }
    hotKeyManager.start()
}
```

**Step 3: Build**

```bash
cd ListenType && swift build
```

**Step 4: Run and test recording**

```bash
swift run &
# Press Option+S, speak for a few seconds, press Option+S again
# Check the output file:
file /tmp/listentype_recording.wav
afinfo /tmp/listentype_recording.wav
```

Expected: WAV file created, 16kHz sample rate, 1 channel, 16-bit.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add audio recording with AVAudioEngine (16kHz mono WAV)"
```

---

### Task 5: Add Whisper Transcription

**Files:**
- Create: `ListenType/Sources/ListenType/WhisperService.swift`
- Modify: `ListenType/Sources/ListenType/ListenTypeApp.swift`

**Step 1: Create WhisperService.swift**

```swift
import Foundation

class WhisperService {
    let whisperPath: String
    let modelPath: String

    init(
        whisperPath: String = "\(NSHomeDirectory())/tools/whisper.cpp/whisper-cli",
        modelPath: String = "\(NSHomeDirectory())/tools/whisper.cpp/models/ggml-small.bin"
    ) {
        self.whisperPath = whisperPath
        self.modelPath = modelPath
    }

    func transcribe(audioURL: URL) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: whisperPath)
        process.arguments = [
            "-m", modelPath,
            "-l", "zh",
            "-f", audioURL.path,
            "--no-timestamps",
            "-nt"  // no timestamps in output
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                continuation.resume(returning: output)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

**Step 2: Wire into ListenTypeApp.swift**

In the `.recording` case, after `stopRecording()`:

```swift
case .recording:
    if let url = recorder.stopRecording() {
        appState.recordingState = .processing
        print("[ListenType] Transcribing...")

        Task {
            do {
                let text = try await whisperService.transcribe(audioURL: url)
                print("[ListenType] Transcription: \(text)")
                // TODO: Polish and type
                await MainActor.run {
                    appState.recordingState = .idle
                }
            } catch {
                print("[ListenType] Transcription error: \(error)")
                await MainActor.run {
                    appState.recordingState = .idle
                }
            }
        }
    }
```

Add `let whisperService = WhisperService()` alongside the recorder.

**Step 3: Build**

```bash
cd ListenType && swift build
```

**Step 4: Test end-to-end (record → transcribe)**

```bash
swift run &
# Press Option+S, say something in Chinese, press Option+S
# Watch terminal for transcription output
```

Expected: Chinese text appears in terminal after processing.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add Whisper transcription via whisper.cpp CLI"
```

---

### Task 6: Add Ollama Text Polishing

**Files:**
- Create: `ListenType/Sources/ListenType/OllamaService.swift`
- Modify: `ListenType/Sources/ListenType/ListenTypeApp.swift`

**Step 1: Create OllamaService.swift**

```swift
import Foundation

class OllamaService {
    let baseURL: String
    let model: String

    init(
        baseURL: String = "http://localhost:11434",
        model: String = "gemma3:4b"
    ) {
        self.baseURL = baseURL
        self.model = model
    }

    func polish(text: String) async throws -> String {
        let url = URL(string: "\(baseURL)/api/generate")!

        let requestBody: [String: Any] = [
            "model": model,
            "prompt": """
            將以下語音轉錄的口語化中文整理成通順的書面文字。
            規則：
            - 保留原意，不添加原文沒有的內容
            - 去除贅字（嗯、那個、就是說、然後）和語助詞
            - 修正語法和標點符號
            - 只輸出整理後的文字，不要任何解釋

            原文：\(text)
            """,
            "stream": false,
            "options": [
                "temperature": 0.3
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = json["response"] as? String else {
            throw OllamaError.invalidResponse
        }

        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func isAvailable() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    enum OllamaError: Error {
        case invalidResponse
    }
}
```

**Step 2: Wire into ListenTypeApp.swift**

After transcription, add polish step:

```swift
let text = try await whisperService.transcribe(audioURL: url)
print("[ListenType] Raw: \(text)")

var finalText = text
if await ollamaService.isAvailable() {
    let polished = try await ollamaService.polish(text: text)
    print("[ListenType] Polished: \(polished)")
    finalText = polished
} else {
    print("[ListenType] Ollama not available, using raw text")
}
// TODO: Type finalText
```

Add `let ollamaService = OllamaService()` alongside the other services.

**Step 3: Build**

```bash
cd ListenType && swift build
```

**Step 4: Test with Ollama running**

```bash
ollama serve &  # if not already running
swift run &
# Press Option+S, speak, press Option+S
# Watch for Raw vs Polished output in terminal
```

Expected: Raw transcription followed by polished version.

**Step 5: Test without Ollama (graceful fallback)**

```bash
# Stop ollama, then test — should fall back to raw text
```

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add Ollama text polishing with graceful fallback"
```

---

### Task 7: Add Type Simulator

**Files:**
- Create: `ListenType/Sources/ListenType/TypeSimulator.swift`
- Modify: `ListenType/Sources/ListenType/ListenTypeApp.swift`

**Step 1: Create TypeSimulator.swift**

```swift
import Cocoa
import Carbon

class TypeSimulator {
    /// Types text by splitting into chunks, copying each to clipboard, and pasting
    func type(text: String, charDelay: TimeInterval = 0.02) async {
        // Save current clipboard
        let pasteboard = NSPasteboard.general
        let savedItems = pasteboard.pasteboardItems?.compactMap { item -> (String, String)? in
            guard let types = item.types.first,
                  let data = item.string(forType: types) else { return nil }
            return (types.rawValue, data)
        }

        // Type character by character via clipboard + paste
        for char in text {
            pasteboard.clearContents()
            pasteboard.setString(String(char), forType: .string)
            simulatePaste()
            try? await Task.sleep(for: .milliseconds(Int(charDelay * 1000)))
        }

        // Restore clipboard after a short delay
        try? await Task.sleep(for: .milliseconds(100))
        pasteboard.clearContents()
        if let saved = savedItems {
            for (typeStr, data) in saved {
                pasteboard.setString(data, forType: NSPasteboard.PasteboardType(typeStr))
            }
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down: Cmd+V
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(9), keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        // Key up: Cmd+V
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(9), keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}
```

**Step 2: Wire into ListenTypeApp.swift**

Replace the TODO comment with:

```swift
var finalText = text
if await ollamaService.isAvailable() {
    let polished = try await ollamaService.polish(text: text)
    print("[ListenType] Polished: \(polished)")
    finalText = polished
} else {
    print("[ListenType] Ollama not available, using raw text")
}

await typeSimulator.type(text: finalText)
print("[ListenType] Done typing")

await MainActor.run {
    appState.recordingState = .idle
}
```

Add `let typeSimulator = TypeSimulator()` alongside other services.

**Step 3: Build**

```bash
cd ListenType && swift build
```

**Step 4: Test full pipeline**

```bash
swift run &
# Open TextEdit or any text field
# Press Option+S, say something, press Option+S
# Watch text appear character by character
```

Expected: Polished text typed into the active text field.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add type simulator with clipboard-based character input"
```

---

### Task 8: Add Sound Feedback and Polish

**Files:**
- Modify: `ListenType/Sources/ListenType/AppState.swift`
- Modify: `ListenType/Sources/ListenType/MenuBarView.swift`
- Modify: `ListenType/Sources/ListenType/ListenTypeApp.swift`

**Step 1: Add sound feedback to AppState**

Add to `AppState.swift`:

```swift
import AppKit

extension AppState {
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
```

**Step 2: Update MenuBarView with more info**

```swift
struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(appState.statusText)
            }
            Divider()
            Text("⌥S to record")
                .font(.caption)
                .foregroundColor(.secondary)
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private var statusColor: Color {
        switch appState.recordingState {
        case .idle: return .gray
        case .recording: return .red
        case .processing: return .orange
        }
    }
}
```

**Step 3: Add sounds to the flow in ListenTypeApp.swift**

Add `appState.playStartSound()` when recording starts, `appState.playStopSound()` when recording stops, `appState.playDoneSound()` after typing completes, and `appState.playErrorSound()` in catch blocks.

**Step 4: Build and test**

```bash
cd ListenType && swift build && swift run &
# Test the full flow — should hear sound feedback at each stage
```

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add sound feedback and polish menu bar UI"
```

---

### Task 9: Create Build Script and .app Bundle

**Files:**
- Create: `scripts/build.sh`
- Create: `scripts/run.sh`

**Step 1: Create build script**

```bash
#!/bin/bash
set -e

cd "$(dirname "$0")/.."
cd ListenType

echo "Building ListenType..."
swift build -c release

APP_DIR="$HOME/Applications/ListenType.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"

mkdir -p "$MACOS"

# Copy binary
cp .build/release/ListenType "$MACOS/ListenType"

# Copy Info.plist
cp Sources/ListenType/Info.plist "$CONTENTS/Info.plist"

# Copy entitlements
cp Sources/ListenType/ListenType.entitlements "$CONTENTS/ListenType.entitlements"

echo "Built: $APP_DIR"
echo "Run: open $APP_DIR"
```

**Step 2: Create run script**

```bash
#!/bin/bash
APP="$HOME/Applications/ListenType.app"
if [ ! -d "$APP" ]; then
    echo "Run scripts/build.sh first"
    exit 1
fi
open "$APP"
```

**Step 3: Make scripts executable**

```bash
chmod +x scripts/build.sh scripts/run.sh
```

**Step 4: Build and test as .app**

```bash
./scripts/build.sh
open ~/Applications/ListenType.app
```

Expected: App launches in menu bar, Option+S works, full pipeline works.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add build script for .app bundle"
```

---

## Summary

| Task | Description | Dependencies |
|------|------------|-------------|
| 1 | Install whisper.cpp + Ollama | None |
| 2 | Swift project skeleton + menu bar | None |
| 3 | Global hotkey (Option+S) | Task 2 |
| 4 | Audio recording | Task 2 |
| 5 | Whisper transcription | Task 1, 4 |
| 6 | Ollama polishing | Task 1, 5 |
| 7 | Type simulator | Task 6 |
| 8 | Sound feedback + polish | Task 7 |
| 9 | Build script + .app bundle | Task 8 |
