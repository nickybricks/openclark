import Foundation

/// OpenAI GPT Provider via URLSession.
struct OpenAIProvider: LLMProvider, Sendable {
    let name = "OpenAI (GPT)"
    let apiKey: String
    let model: String

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func analyze(filename: String, extension ext: String, text: String) async throws -> LLMAnalysisResult {
        let prompt = LLMPrompt.generate(filename: filename, extension: ext, text: text)

        let body: [String: Any] = [
            "model": model.isEmpty ? "gpt-4o-mini" : model,
            "max_tokens": 200,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let responseText = message["content"] as? String else {
            throw LLMError.invalidResponse
        }

        return try LLMResponseParser.parse(responseText)
    }
}
