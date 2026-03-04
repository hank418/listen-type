import Foundation
import SwiftUI

@MainActor
class ModelManager: ObservableObject {
    static let modelFileName = "ggml-large-v3.bin"
    static let downloadURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin"

    @Published var state: ModelState = .checking
    @Published var downloadProgress: Double = 0
    @Published var downloadedMB: Int = 0
    @Published var totalMB: Int = 0

    enum ModelState {
        case checking
        case ready
        case downloading
        case error(String)
    }

    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    var modelDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ListenType/models")
    }

    var modelPath: URL {
        modelDir.appendingPathComponent(Self.modelFileName)
    }

    private var downloadTask: URLSessionDownloadTask?
    private var downloadSession: URLSession?
    private var downloadDelegate: DownloadDelegate?

    private static var initStarted = false

    init() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !ModelManager.initStarted else { return }
            ModelManager.initStarted = true
            self.checkAndDownloadIfNeeded()
        }
    }

    func checkAndDownloadIfNeeded() {
        if FileManager.default.fileExists(atPath: modelPath.path) {
            state = .ready
            debugLog("[ModelManager] Model found")
        } else {
            debugLog("[ModelManager] Model not found, downloading...")
            startDownload()
        }
    }

    func startDownload() {
        state = .downloading
        downloadProgress = 0
        debugLog("[ModelManager] startDownload()")

        try? FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

        let url = URL(string: Self.downloadURL)!

        let delegate = DownloadDelegate(
            onProgress: { [weak self] bytesWritten, totalBytes in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.downloadProgress = totalBytes > 0 ? Double(bytesWritten) / Double(totalBytes) : 0
                    self.downloadedMB = Int(bytesWritten / 1_048_576)
                    self.totalMB = Int(totalBytes / 1_048_576)
                }
            },
            onComplete: { [weak self] location, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.handleDownloadComplete(location: location, error: error)
                }
            }
        )

        self.downloadDelegate = delegate
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        self.downloadSession = session
        let task = session.downloadTask(with: url)
        self.downloadTask = task
        task.resume()
        debugLog("[ModelManager] Download task resumed")
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        state = .error("下載已取消")
    }

    private func handleDownloadComplete(location: URL?, error: Error?) {
        if let error = error {
            if (error as NSError).code == NSURLErrorCancelled { return }
            self.state = .error("下載失敗：\(error.localizedDescription)")
            debugLog("[ModelManager] Download error: \(error)")
            return
        }

        guard let location = location else {
            self.state = .error("下載失敗：找不到暫存檔")
            return
        }

        do {
            if FileManager.default.fileExists(atPath: self.modelPath.path) {
                try FileManager.default.removeItem(at: self.modelPath)
            }
            try FileManager.default.moveItem(at: location, to: self.modelPath)
            self.state = .ready
            debugLog("[ModelManager] Model downloaded OK")
        } catch {
            self.state = .error("無法儲存模型：\(error.localizedDescription)")
            debugLog("[ModelManager] Save error: \(error)")
        }
    }
}

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: (Int64, Int64) -> Void
    let onComplete: (URL?, Error?) -> Void

    init(onProgress: @escaping (Int64, Int64) -> Void, onComplete: @escaping (URL?, Error?) -> Void) {
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        onProgress(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let tmpCopy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bin")
        try? FileManager.default.copyItem(at: location, to: tmpCopy)
        onComplete(tmpCopy, nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            onComplete(nil, error)
        }
    }
}
