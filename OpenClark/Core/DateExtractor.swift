import Foundation

/// Extrahiert Datum aus Dateinamen, PDF-Text oder Filesystem-Metadaten.
enum DateExtractor {

    enum DatePrecision: String {
        case full   // YYYY-MM-DD
        case month  // YYYY-MM
        case year   // YYYY
    }

    struct ExtractedDate {
        let dateString: String
        let precision: DatePrecision
    }

    // MARK: - Regex Patterns

    private static let patterns: [(NSRegularExpression, String)] = {
        let defs: [(String, String)] = [
            // YYYY-MM-DD, YYYY.MM.DD, YYYY_MM_DD
            (#"(\d{4})[-_.](\d{2})[-_.](\d{2})"#, "full"),
            // DD.MM.YYYY, DD/MM/YYYY
            (#"(\d{2})[./](\d{2})[./](\d{4})"#, "reversed"),
            // Month DD, YYYY (english)
            (#"(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),?\s+(\d{4})"#, "english"),
            // DD. Month YYYY (german)
            (#"(\d{1,2})\.\s*(Januar|Februar|März|Maerz|April|Mai|Juni|Juli|August|September|Oktober|November|Dezember)\s+(\d{4})"#, "german"),
            // YYYY-MM
            (#"(\d{4})[-_.](\d{2})"#, "month"),
            // YYYY (nur Jahr)
            (#"(\d{4})"#, "year"),
        ]
        return defs.compactMap { pattern, fmt in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            return (regex, fmt)
        }
    }()

    private static let englishMonths: [String: String] = [
        "january": "01", "february": "02", "march": "03", "april": "04",
        "may": "05", "june": "06", "july": "07", "august": "08",
        "september": "09", "october": "10", "november": "11", "december": "12",
    ]

    private static let germanMonths: [String: String] = [
        "januar": "01", "februar": "02", "märz": "03", "maerz": "03",
        "april": "04", "mai": "05", "juni": "06", "juli": "07",
        "august": "08", "september": "09", "oktober": "10",
        "november": "11", "dezember": "12",
    ]

    /// Extrahiere Datum aus einem Text (Dateiname oder PDF-Inhalt).
    static func extract(from text: String) -> ExtractedDate? {
        let range = NSRange(text.startIndex..., in: text)

        for (regex, fmt) in patterns {
            guard let match = regex.firstMatch(in: text, range: range) else { continue }

            switch fmt {
            case "full":
                let year = substring(of: text, match: match, at: 1)
                let month = substring(of: text, match: match, at: 2)
                let day = substring(of: text, match: match, at: 3)
                if isValidDate(year: year, month: month, day: day) {
                    return ExtractedDate(dateString: "\(year)-\(month)-\(day)", precision: .full)
                }

            case "reversed":
                let day = substring(of: text, match: match, at: 1)
                let month = substring(of: text, match: match, at: 2)
                let year = substring(of: text, match: match, at: 3)
                if isValidDate(year: year, month: month, day: day) {
                    return ExtractedDate(dateString: "\(year)-\(month)-\(day)", precision: .full)
                }

            case "english":
                let monthName = substring(of: text, match: match, at: 1).lowercased()
                let day = substring(of: text, match: match, at: 2)
                let year = substring(of: text, match: match, at: 3)
                if let monthNum = englishMonths[monthName] {
                    let paddedDay = day.count == 1 ? "0\(day)" : day
                    return ExtractedDate(dateString: "\(year)-\(monthNum)-\(paddedDay)", precision: .full)
                }

            case "german":
                let day = substring(of: text, match: match, at: 1)
                let monthName = substring(of: text, match: match, at: 2).lowercased()
                let year = substring(of: text, match: match, at: 3)
                if let monthNum = germanMonths[monthName] {
                    let paddedDay = day.count == 1 ? "0\(day)" : day
                    return ExtractedDate(dateString: "\(year)-\(monthNum)-\(paddedDay)", precision: .full)
                }

            case "month":
                let year = substring(of: text, match: match, at: 1)
                let month = substring(of: text, match: match, at: 2)
                if let y = Int(year), let m = Int(month),
                   (1900...2100).contains(y), (1...12).contains(m) {
                    return ExtractedDate(dateString: "\(year)-\(month)", precision: .month)
                }

            case "year":
                let year = substring(of: text, match: match, at: 1)
                if let y = Int(year), (2000...2100).contains(y) {
                    return ExtractedDate(dateString: year, precision: .year)
                }

            default:
                break
            }
        }

        return nil
    }

    /// Extrahiere Datum aus Datei-Metadaten (Erstellungsdatum).
    static func extractFromFileSystem(at path: String) -> ExtractedDate {
        let fm = FileManager.default
        if let attrs = try? fm.attributesOfItem(atPath: path),
           let creationDate = attrs[.creationDate] as? Date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return ExtractedDate(dateString: formatter.string(from: creationDate), precision: .full)
        }
        // Fallback: heute
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return ExtractedDate(dateString: formatter.string(from: Date()), precision: .full)
    }

    /// Extrahiere Datum mit Priorität: Text → Dateiname → Filesystem
    static func extractBest(filename: String, filePath: String, pdfText: String? = nil) -> ExtractedDate {
        // Priorität 1: PDF-Text
        if let text = pdfText, let date = extract(from: text) {
            return date
        }
        // Priorität 2: Dateiname
        if let date = extract(from: filename) {
            return date
        }
        // Priorität 3: Filesystem
        return extractFromFileSystem(at: filePath)
    }

    // MARK: - Helpers

    private static func substring(of text: String, match: NSTextCheckingResult, at index: Int) -> String {
        guard let range = Range(match.range(at: index), in: text) else { return "" }
        return String(text[range])
    }

    private static func isValidDate(year: String, month: String, day: String) -> Bool {
        guard let y = Int(year), let m = Int(month), let d = Int(day) else { return false }
        return (1900...2100).contains(y) && (1...12).contains(m) && (1...31).contains(d)
    }
}
