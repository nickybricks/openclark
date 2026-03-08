import Foundation

/// Generiert Dateinamen nach dem Schema YYYY-MM-DD_Kategorie_Beschreibung.ext
enum NameGenerator {

    struct RenameResult: Sendable {
        let newName: String
        let category: String
        let source: String // "filename", "pdf_keywords", "llm"
    }

    /// Generiere neuen Dateinamen nach Schema.
    static func generate(
        originalPath: String,
        category: String?,
        description: String,
        dateString: String? = nil
    ) -> String? {
        let url = URL(fileURLWithPath: originalPath)
        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()

        // Bereits im Schema? → Überspringen
        if FileFilters.matchesSchema(filename) {
            return nil
        }

        // Datum
        let date: DateExtractor.ExtractedDate
        if let ds = dateString {
            date = DateExtractor.ExtractedDate(dateString: ds, precision: .full)
        } else {
            date = DateExtractor.extractBest(filename: filename, filePath: originalPath)
        }

        // Kategorie
        let cat = category ?? CategoryDefinitions.fallbackCategory

        // Beschreibung bereinigen
        var desc = description
        if !desc.isEmpty {
            desc = TextSanitizer.sanitize(desc)
            desc = TextSanitizer.capitalizeWords(desc)
        }

        // Fallback Beschreibung
        if desc.isEmpty || desc == cat {
            let stem = url.deletingPathExtension().lastPathComponent
            desc = TextSanitizer.sanitize(stem)
            desc = TextSanitizer.capitalizeWords(desc)
        }
        if desc.isEmpty {
            desc = "Unbenannt"
        }

        let extSuffix = ext.isEmpty ? "" : ".\(ext)"
        let newName = "\(date.dateString)_\(cat)_\(desc)\(extSuffix)"

        // Gleicher Name? → Kein Rename nötig
        if newName == filename {
            return nil
        }

        return newName
    }

    /// Löse Namenskollisionen auf: _2, _3, ...
    static func resolveConflict(directory: String, proposedName: String) -> String {
        let dirURL = URL(fileURLWithPath: directory)
        let target = dirURL.appendingPathComponent(proposedName)

        if !FileManager.default.fileExists(atPath: target.path) {
            return proposedName
        }

        let stem = (proposedName as NSString).deletingPathExtension
        let ext = (proposedName as NSString).pathExtension
        let extSuffix = ext.isEmpty ? "" : ".\(ext)"

        var counter = 2
        while true {
            let candidate = "\(stem)_\(counter)\(extSuffix)"
            let candidatePath = dirURL.appendingPathComponent(candidate)
            if !FileManager.default.fileExists(atPath: candidatePath.path) {
                return candidate
            }
            counter += 1
        }
    }
}
