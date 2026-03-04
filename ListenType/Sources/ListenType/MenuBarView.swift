import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var modelManager: ModelManager

    var body: some View {
        VStack {
            // Recording status
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(appState.statusText)
            }

            Divider()

            // Model status
            switch modelManager.state {
            case .checking:
                Label("Checking model...", systemImage: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .ready:
                Label("Model ready", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            case .downloading:
                VStack(alignment: .leading, spacing: 4) {
                    Label("Downloading model...", systemImage: "arrow.down.circle")
                        .font(.caption)
                    ProgressView(value: modelManager.downloadProgress)
                    Text("\(modelManager.downloadedMB) / \(modelManager.totalMB) MB")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            case .error(let message):
                VStack(alignment: .leading, spacing: 4) {
                    Label("Model error", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(message)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Button("Retry Download") {
                        modelManager.startDownload()
                    }
                    .font(.caption)
                }
                .padding(.horizontal, 4)
            }

            Divider()

            // Ollama status
            HStack {
                Circle()
                    .fill(appState.ollamaAvailable ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                Text(appState.ollamaAvailable ? "Ollama 已連線（文字潤飾）" : "Ollama 未執行（選用）")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !appState.ollamaAvailable {
                Text("安裝並啟動 Ollama 可自動潤飾文字")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
