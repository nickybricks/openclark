import Foundation

/// Lokaler Ollama Provider via URLSession.
struct OllamaProvider: LLMProvider, Sendable {
    let name = "Ollama (Lokal)"
    let model: String
    let baseURL: String

    init(model: String, baseURL: String = "http://localhost:11434") {
        self.model = model.isEmpty ? "llama3.2" : model
        self.baseURL = baseURL
    }

    func analyze(filename: String, extension ext: String, text: String) async throws -> LLMAnalysisResult {
        let prompt = LLMPrompt.generate(filename: filename, extension: ext, text: text)

        guard let endpoint = URL(string: "\(baseURL)/api/generate") else {
            throw LLMError.apiError("Ungültige Ollama URL: \(baseURL)")
        }

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            throw LLMError.invalidResponse
        }

        return try LLMResponseParser.parse(responseText)
    }
}
