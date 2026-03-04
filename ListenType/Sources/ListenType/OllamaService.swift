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
            你是語音轉文字的後處理器。整理以下語音轉錄文字。

            規則：
            1. 使用繁體中文，英文技術詞彙保持原文（如 deploy、production、API）
            2. 口誤修正：「不對」「我是說」「更正」後面的才是正確的，刪除前面說錯的部分
            3. 去除贅字和語助詞
            4. 加上正確標點符號
            5. 嚴禁添加、翻譯或改寫原文沒有的內容
            6. 只輸出結果，不要解釋

            範例：
            輸入：晚上8點deploy production不對,晚上10點deploy production
            輸出：晚上10點 deploy production
            輸入：晚上8點deploy不對晚上10點deploy production包含worker
            輸出：晚上10點 deploy production，包含 worker
            輸入：嗯那個我想要買三個不對五個蘋果
            輸出：我想要買五個蘋果

            輸入：\(text)
            輸出：
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
