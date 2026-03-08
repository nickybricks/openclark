import Foundation

/// Custom OpenAI-kompatibler Endpoint Provider.
struct CustomProvider: LLMProvider, Sendable {
    let name = "Custom Endpoint"
    let apiKey: String
    let model: String
    let endpoint: String

    func analyze(filename: String, extension ext: String, text: String) async throws -> LLMAnalysisResult {
        let prompt = LLMPrompt.generate(filename: filename, extension: ext, text: text)

        // OpenAI-kompatibles Format
        let url: URL
        if endpoint.isEmpty {
            throw LLMError.apiError("Kein Custom Endpoint konfiguriert")
        } else {
            guard let parsedURL = URL(string: endpoint) else {
                throw LLMError.apiError("Ungültige Custom URL: \(endpoint)")
            }
            url = parsedURL
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 200,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        // OpenAI-kompatibles Response-Format
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
