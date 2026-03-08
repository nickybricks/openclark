import Foundation

/// Claude API Provider via URLSession.
struct AnthropicProvider: LLMProvider, Sendable {
    let name = "Anthropic (Claude)"
    let apiKey: String
    let model: String

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func analyze(filename: String, extension ext: String, text: String) async throws -> LLMAnalysisResult {
        let prompt = LLMPrompt.generate(filename: filename, extension: ext, text: text)

        // Request Body
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 200,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        // Request
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await URLSession.shared.data(for: request)

        // Response prüfen
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        // JSON parsen
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let responseText = firstContent["text"] as? String else {
            throw LLMError.invalidResponse
        }

        return try LLMResponseParser.parse(responseText)
    }
}
