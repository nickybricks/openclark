import Foundation
import PDFKit

/// Lokal laufender Qwen-Provider via integriertem Ollama-Server.
/// OllamaManager startet den Server automatisch bei Bedarf.
struct QwenProvider: LLMProvider, Sendable {
    let name = "Qwen (Lokal)"
    let model: String

    private let baseURL = "http://127.0.0.1:11434"

    init(model: String) {
        self.model = model.isEmpty ? "qwen2.5vl:7b" : model
    }

    func analyze(filename: String, extension ext: String, text: String) async throws -> LLMAnalysisResult {
        try await OllamaManager.shared.ensureServerRunning()

        let prompt = LLMPrompt.generate(filename: filename, extension: ext, text: text)

        guard let endpoint = URL(string: "\(baseURL)/api/generate") else {
            throw LLMError.apiError("Ungültige Ollama URL")
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

    func analyzePDF(filename: String, pdfPath: String, extractedText: String) async throws -> LLMAnalysisResult {
        let images = PDFTextExtractor.renderPagesAsBase64JPEG(from: pdfPath)
        guard !images.isEmpty else {
            return try await analyze(filename: filename, extension: "pdf", text: extractedText)
        }

        try await OllamaManager.shared.ensureServerRunning()

        guard let endpoint = URL(string: "\(baseURL)/api/generate") else {
            throw LLMError.apiError("Ungültige Ollama URL")
        }

        let body: [String: Any] = [
            "model": model,
            "prompt": LLMPrompt.generateForPDF(filename: filename),
            "images": images,
            "stream": false,
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
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
