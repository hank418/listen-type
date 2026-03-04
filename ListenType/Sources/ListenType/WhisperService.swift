import Foundation

class WhisperService {
    var whisperPath: String
    var modelPath: String

    init() {
        // Look for whisper-cli in app bundle first, fallback to ~/tools
        if let bundledPath = Bundle.main.path(forResource: "whisper-cli", ofType: nil) {
            self.whisperPath = bundledPath
        } else {
            self.whisperPath = "\(NSHomeDirectory())/tools/whisper.cpp/whisper-cli"
        }

        // Model in ~/Library/Application Support/ListenType/models/
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelDir = appSupport.appendingPathComponent("ListenType/models")
        self.modelPath = modelDir.appendingPathComponent("ggml-large-v3.bin").path
    }

    var isModelAvailable: Bool {
        FileManager.default.fileExists(atPath: modelPath)
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard isModelAvailable else {
            throw WhisperError.modelNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: whisperPath)
        process.arguments = [
            "-m", modelPath,
            "-l", "zh",
            "-f", audioURL.path,
            "--no-timestamps",
            "-nt",
            "--prompt", "以下是繁體中文的語音轉錄。"
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

    enum WhisperError: LocalizedError {
        case modelNotFound

        var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "Whisper model not found. Please wait for model download to complete."
            }
        }
    }
}
