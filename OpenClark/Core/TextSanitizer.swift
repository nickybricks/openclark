import Foundation

/// Bereinigt Text für Dateinamen: Umlaute, Sonderzeichen, Capitalize.
enum TextSanitizer {

    // MARK: - Umlaut-Map

    private static let umlautMap: [(Character, String)] = [
        ("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss"),
        ("Ä", "Ae"), ("Ö", "Oe"), ("Ü", "Ue"),
    ]

    /// Ersetze deutsche Umlaute durch ASCII-Äquivalente.
    static func replaceUmlauts(_ text: String) -> String {
        var result = text
        for (umlaut, replacement) in umlautMap {
            result = result.replacingOccurrences(of: String(umlaut), with: replacement)
        }
        return result
    }

    /// Vollständige Bereinigung: Umlaute, Unicode, Sonderzeichen, Leerzeichen.
    static func sanitize(_ text: String) -> String {
        var result = replaceUmlauts(text)

        // Unicode NFKD normalisieren, nur ASCII behalten
        result = result.decomposedStringWithCompatibilityMapping
        result = String(result.unicodeScalars.filter { $0.isASCII })

        // Leerzeichen → Bindestriche
        result = result.replacingOccurrences(
            of: #"\s+"#, with: "-", options: .regularExpression
        )

        // Nur alphanumerisch, Bindestrich, Unterstrich, Punkt
        result = result.replacingOccurrences(
            of: #"[^a-zA-Z0-9\-_.]"#, with: "", options: .regularExpression
        )

        // Doppelte Bindestriche entfernen
        result = result.replacingOccurrences(
            of: #"-{2,}"#, with: "-", options: .regularExpression
        )

        // Führende/folgende Bindestriche entfernen
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return result
    }

    /// Erster Buchstabe jedes Worts groß (getrennt durch Bindestrich).
    static func capitalizeWords(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        return text.split(separator: "-", omittingEmptySubsequences: false)
            .map { part in
                guard let first = part.first else { return String(part) }
                return String(first).uppercased() + part.dropFirst()
            }
            .joined(separator: "-")
    }
}
