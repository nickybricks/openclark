import Foundation

/// Bestimmt welche Dateien übersprungen werden sollen.
enum FileFilters {

    // MARK: - Ignorierte Dateiendungen

    static let excludedExtensions: Set<String> = [
        // Bilder
        ".jpg", ".jpeg", ".png", ".gif", ".heic", ".heif", ".raw",
        ".cr2", ".cr3", ".nef", ".arw", ".tiff", ".tif", ".bmp",
        ".webp", ".svg", ".ico",
        // Musik
        ".mp3", ".wav", ".flac", ".aac", ".m4a", ".ogg", ".wma", ".aiff",
        // Video
        ".mp4", ".mov", ".avi", ".mkv", ".wmv", ".m4v",
        // Design
        ".psd", ".ai", ".indd", ".sketch", ".fig", ".xd",
        // System
        ".ds_store", ".tmp", ".crdownload", ".part",
    ]

    // MARK: - Ignorierte Dateinamen-Präfixe

    static let excludedPrefixes: [String] = [
        "IMG_", "DSC_", "Bildschirmfoto", "Screenshot", "Screen Shot", ".", "~",
    ]

    // MARK: - Ignorierte Ordner

    static let excludedDirectories: Set<String> = [
        ".Trash", "node_modules", ".git", "__pycache__", ".venv",
        ".DS_Store", "Library",
    ]

    // MARK: - Schema-Pattern

    /// Regex: YYYY-MM-DD_Kategorie_Beschreibung.ext (oder YYYY-MM oder YYYY)
    private static let schemaPattern = try! NSRegularExpression(
        pattern: #"^\d{4}(-\d{2}(-\d{2})?)?_[A-Z][a-zA-Z]+_.*\.[a-z0-9]+$"#
    )

    /// Prüfe ob der Dateiname bereits dem Namensschema entspricht.
    static func matchesSchema(_ filename: String) -> Bool {
        let range = NSRange(filename.startIndex..., in: filename)
        return schemaPattern.firstMatch(in: filename, range: range) != nil
    }

    // MARK: - iCloud

    /// Prüfe ob eine Datei ein iCloud-Placeholder ist (.filename.ext.icloud).
    static func isICloudPlaceholder(_ filename: String) -> Bool {
        filename.hasPrefix(".") && filename.hasSuffix(".icloud")
    }

    /// Extrahiere den echten Dateinamen aus einem iCloud-Placeholder.
    /// `.document.pdf.icloud` → `document.pdf`
    static func realNameFromICloudPlaceholder(_ filename: String) -> String? {
        guard isICloudPlaceholder(filename) else { return nil }
        // Entferne führenden Punkt und trailing ".icloud"
        var name = String(filename.dropFirst()) // Entferne "."
        if name.hasSuffix(".icloud") {
            name = String(name.dropLast(7)) // Entferne ".icloud"
        }
        return name.isEmpty ? nil : name
    }

    /// Prüfe ob ein Pfad in iCloud Drive liegt.
    static func isICloudPath(_ path: String) -> Bool {
        path.contains("/Library/Mobile Documents/") || path.contains("/iCloud Drive/")
    }

    // MARK: - Hauptfilter

    /// Prüfe ob eine Datei übersprungen werden soll.
    static func shouldSkip(filename: String, filePath: String) -> Bool {
        // iCloud-Placeholder werden separat behandelt (nicht skippen, sondern Download triggern)
        if isICloudPlaceholder(filename) { return true }

        // Versteckte Dateien
        if filename.hasPrefix(".") { return true }
        // Temporäre Dateien
        if filename.hasPrefix("~") || filename.hasSuffix(".tmp") { return true }

        // Dateierweiterung prüfen
        let ext = (filename as NSString).pathExtension.lowercased()
        if !ext.isEmpty && excludedExtensions.contains(".\(ext)") {
            return true
        }

        // Präfix prüfen
        for prefix in excludedPrefixes {
            if filename.hasPrefix(prefix) { return true }
        }

        // Ordner prüfen
        let components = filePath.split(separator: "/").map(String.init)
        for component in components {
            if excludedDirectories.contains(component) { return true }
        }

        // Bereits im Schema
        if matchesSchema(filename) { return true }

        return false
    }
}
