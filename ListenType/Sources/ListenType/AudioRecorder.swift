import AVFoundation

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var rawURL: URL?
    private var outputURL: URL?

    func startRecording() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let rawURL = tempDir.appendingPathComponent("listentype_raw.caf")
        let outputURL = tempDir.appendingPathComponent("listentype_recording.wav")
        self.rawURL = rawURL
        self.outputURL = outputURL

        try? FileManager.default.removeItem(at: rawURL)
        try? FileManager.default.removeItem(at: outputURL)

        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        debugLog("Recording format: \(recordingFormat)")

        // Write in native format first (no conversion on realtime thread)
        audioFile = try AVAudioFile(
            forWriting: rawURL,
            settings: recordingFormat.settings
        )

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) {
            [weak self] buffer, _ in
            guard let self = self, let audioFile = self.audioFile else { return }
            try? audioFile.write(from: buffer)
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

        // Convert to 16kHz mono WAV for Whisper
        guard let rawURL = rawURL, let outputURL = outputURL else { return nil }

        do {
            try convertToWhisperFormat(input: rawURL, output: outputURL)
            try? FileManager.default.removeItem(at: rawURL)
            debugLog("Converted to 16kHz WAV: \(outputURL.path)")
            return outputURL
        } catch {
            debugLog("Conversion error: \(error)")
            return nil
        }
    }

    private func convertToWhisperFormat(input: URL, output: URL) throws {
        // Use macOS built-in afconvert for reliable format conversion
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [
            "-f", "WAVE",      // WAV format
            "-d", "LEI16@16000", // 16-bit little-endian integer, 16kHz
            "-c", "1",          // mono
            input.path,
            output.path
        ]
        let pipe = Pipe()
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "unknown"
            debugLog("afconvert error: \(errMsg)")
            throw RecorderError.conversionFailed
        }
    }

    enum RecorderError: Error {
        case conversionFailed
    }
}
