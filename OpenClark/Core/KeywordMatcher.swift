import Foundation

/// Keyword-basierte Kategorie-Erkennung mit Konfidenz-Berechnung.
enum KeywordMatcher {

    struct MatchResult: Sendable {
        let category: String
        let confidence: Double
        let description: String
    }

    /// Erkenne Kategorie aus beliebigem Text (Dateiname oder PDF-Inhalt).
    /// Gibt (Kategorie, Konfidenz 0.0-1.0) zurück.
    static func detectCategory(from text: String, keywords: [String: [String]]? = nil) -> (category: String?, confidence: Double) {
        let keywordsMap = keywords ?? CategoryDefinitions.keywordsMap
        let textLower = text.lowercased()
        let textNormalized = TextSanitizer.replaceUmlauts(textLower)

        var scores: [String: Int] = [:]

        for (category, categoryKeywords) in keywordsMap {
            for keyword in categoryKeywords {
                let kwLower = keyword.lowercased()
                // Zähle Treffer in Original und normalisiertem Text
                let countOrig = countOccurrences(of: kwLower, in: textLower)
                let countNorm = countOccurrences(of: kwLower, in: textNormalized)
                let hits = max(countOrig, countNorm)
                if hits > 0 {
                    // Gewichtung: längere Keywords = spezifischer = höherer Score
                    let score = hits * kwLower.count
                    scores[category, default: 0] += score
                }
            }
        }

        guard !scores.isEmpty else {
            return (nil, 0.0)
        }

        // Beste Kategorie
        let bestCategory = scores.max(by: { $0.value < $1.value })!
        let bestScore = bestCategory.value

        // Konfidenz: Abstand zum Zweitbesten
        let sortedScores = scores.values.sorted(by: >)
        let confidence: Double
        if sortedScores.count >= 2 {
            confidence = 1.0 - (Double(sortedScores[1]) / Double(sortedScores[0]))
        } else {
            confidence = min(1.0, Double(bestScore) / 20.0)
        }

        return (bestCategory.key, confidence)
    }

    /// Erkenne Kategorie aus Dateinamen und extrahiere Beschreibung.
    static func matchFilename(_ filename: String, keywords: [String: [String]]? = nil) -> MatchResult? {
        let keywordsMap = keywords ?? CategoryDefinitions.keywordsMap
        let nameLower = filename.lowercased()
        let nameNormalized = TextSanitizer.replaceUmlauts(nameLower)

        var matchedCategory: String?
        var matchedKeyword = ""

        // Finde längsten matchenden Keyword (spezifischste Kategorie)
        for category in CategoryDefinitions.all {
            for keyword in category.keywords {
                let kwLower = keyword.lowercased()
                if nameLower.contains(kwLower) || nameNormalized.contains(kwLower) {
                    if kwLower.count > matchedKeyword.count {
                        matchedCategory = category.name
                        matchedKeyword = kwLower
                    }
                }
            }
        }

        guard let category = matchedCategory else { return nil }

        // Beschreibung extrahieren: Keyword + Datumsteile + Extension entfernen
        var description = nameLower
        if !matchedKeyword.isEmpty {
            description = description.replacingOccurrences(of: matchedKeyword, with: "")
        }
        // Datum-Patterns entfernen
        description = description.replacingOccurrences(
            of: #"\d{4}[-_.]\d{2}[-_.]\d{2}"#, with: "", options: .regularExpression
        )
        description = description.replacingOccurrences(
            of: #"\d{4}[-_.]\d{2}"#, with: "", options: .regularExpression
        )
        description = description.replacingOccurrences(
            of: #"\d{4}"#, with: "", options: .regularExpression
        )
        // Extension entfernen
        description = description.replacingOccurrences(
            of: #"\.[a-zA-Z0-9]+$"#, with: "", options: .regularExpression
        )
        // Trennzeichen normalisieren
        description = description.replacingOccurrences(
            of: #"[-_.\s]+"#, with: "-", options: .regularExpression
        )
        description = description.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        // Konfidenz berechnen
        let (_, confidence) = detectCategory(from: filename, keywords: keywordsMap)

        return MatchResult(category: category, confidence: confidence, description: description)
    }

    // MARK: - Helpers

    private static func countOccurrences(of substring: String, in string: String) -> Int {
        var count = 0
        var searchRange = string.startIndex..<string.endIndex
        while let range = string.range(of: substring, options: .literal, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<string.endIndex
        }
        return count
    }
}
