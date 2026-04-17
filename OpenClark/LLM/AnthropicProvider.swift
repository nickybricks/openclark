import Foundation

/// Claude API Provider via URLSession.
struct AnthropicProvider: LLMProvider, Sendable {
    let name = "Anthropic (Claude)"
    let apiKey: String
    let model: String

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func analyze(filename: String, extension ext: String, text: String) async throws -> LLMAnalysisResult {
        let prompt = LLMPrompt.generate(filename: filename, extension: ext, text: text)
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "messages": [["role": "user", "content": prompt]]
        ]
        return try await sendRequest(body: body)
    }

    /// Sendet PDF als base64 document – Claude kann damit auch Scans lesen.
    func analyzePDF(filename: String, pdfPath: String, extractedText: String) async throws -> LLMAnalysisResult {
        guard let pdfData = try? Data(contentsOf: URL(fileURLWithPath: pdfPath)) else {
            // Fallback auf Text-Analyse wenn PDF nicht lesbar
            return try await analyze(filename: filename, extension: "pdf", text: extractedText)
        }

        let base64PDF = pdfData.base64EncodedString()
        let promptText = LLMPrompt.generateForPDF(filename: filename)

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "document",
                        "source": [
                            "type": "base64",
                            "media_type": "application/pdf",
                            "data": base64PDF
                        ]
                    ],
                    ["type": "text", "text": promptText]
                ]
            ]]
        ]
        return try await sendRequest(body: body)
    }

    private func sendRequest(body: [String: Any]) async throws -> LLMAnalysisResult {
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let responseText = firstContent["text"] as? String else {
            throw LLMError.invalidResponse
        }

        return try LLMResponseParser.parse(responseText)
    }
}
