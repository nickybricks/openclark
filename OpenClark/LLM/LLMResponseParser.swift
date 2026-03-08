import Foundation

/// Parst LLM-Antworten und extrahiert JSON.
enum LLMResponseParser {

    /// Extrahiere LLMAnalysisResult aus LLM-Antworttext.
    /// Sucht nach JSON `{...}` auch wenn drumherum Text ist.
    static func parse(_ responseText: String) throws -> LLMAnalysisResult {
        // JSON-Block finden (auch wenn drumherum Text/Markdown ist)
        guard let jsonString = extractJSON(from: responseText) else {
            throw LLMError.invalidResponse
        }

        guard let data = jsonString.data(using: .utf8) else {
            throw LLMError.invalidResponse
        }

        // JSON parsen
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse
        }

        guard let date = json["date"] as? String,
              let category = json["category"] as? String,
              let description = json["description"] as? String else {
            throw LLMError.invalidResponse
        }

        // Bereinigen
        let cleanDate = TextSanitizer.sanitize(date)
        let cleanCategory = TextSanitizer.sanitize(category)
        let cleanDescription = TextSanitizer.capitalizeWords(TextSanitizer.sanitize(description))

        return LLMAnalysisResult(
            date: cleanDate,
            category: cleanCategory,
            description: cleanDescription.isEmpty ? "Unbenannt" : cleanDescription
        )
    }

    /// Finde den ersten JSON-Block `{...}` im Text.
    private static func extractJSON(from text: String) -> String? {
        // Suche nach { ... } Pattern
        guard let regex = try? NSRegularExpression(pattern: #"\{[^}]+\}"#, options: .dotMatchesLineSeparators) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let matchRange = Range(match.range, in: text) else {
            return nil
        }

        return String(text[matchRange])
    }
}
