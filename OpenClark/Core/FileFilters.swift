import Foundation

/// Bestimmt welche Dateien übersprungen werden sollen.
enum FileFilters {

    // MARK: - Built-in Ignorierte Dateiendungen

    static let builtInExcludedExtensions: Set<String> = [
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

    // MARK: - Built-in Ignorierte Dateinamen-Präfixe

    static let builtInExcludedPrefixes: [String] = [
        "IMG_", "DSC_", "Bildschirmfoto", "Screenshot", "Screen Shot", ".", "~",
    ]

    // MARK: - Built-in Ignorierte Ordner

    static let builtInExcludedDirectories: Set<String> = [
        ".Trash", "node_modules", ".git", "__pycache__", ".venv",
        ".DS_Store", "Library",
    ]

    // MARK: - Effektive Ausschlüsse (Built-in + Config)

    /// Effektive ausgeschlossene Extensions unter Berücksichtigung der Config.
    static func effectiveExcludedExtensions(config: AppConfiguration? = nil) -> Set<String> {
        let cfg = config ?? AppConfig.shared.config
        let deleted = Set(cfg.deletedBuiltInExtensions ?? [])
        var result = builtInExcludedExtensions.filter { !deleted.contains($0) }

        // Built-in Ausschlüsse entfernen die der User wieder aktiviert hat
        if let enabled = cfg.enabledBuiltInExtensions {
            for ext in enabled {
                result.remove(ext)
            }
        }

        // Benutzerdefinierte Ausschlüsse hinzufügen
        if let custom = cfg.excludedExtensions {
            for ext in custom {
                result.insert(ext)
            }
        }

        return result
    }

    /// Effektive ausgeschlossene Prefixes unter Berücksichtigung der Config.
    static func effectiveExcludedPrefixes(config: AppConfiguration? = nil) -> [String] {
        let cfg = config ?? AppConfig.shared.config
        let disabled = Set(cfg.disabledBuiltInPrefixes ?? [])
        let deleted = Set(cfg.deletedBuiltInPrefixes ?? [])

        var result = builtInExcludedPrefixes.filter { !disabled.contains($0) && !deleted.contains($0) }

        if let custom = cfg.excludedPrefixes {
            result.append(contentsOf: custom)
        }

        return result
    }

    /// Effektive ausgeschlossene Ordner unter Berücksichtigung der Config.
    static func effectiveExcludedDirectories(config: AppConfiguration? = nil) -> Set<String> {
        let cfg = config ?? AppConfig.shared.config
        let disabled = Set(cfg.disabledBuiltInDirectories ?? [])
        let deleted = Set(cfg.deletedBuiltInDirectories ?? [])

        var result = builtInExcludedDirectories.filter { !disabled.contains($0) && !deleted.contains($0) }

        if let custom = cfg.excludedDirectories {
            for dir in custom {
                result.insert(dir)
            }
        }

        return result
    }

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
    static func shouldSkip(filename: String, filePath: String, config: AppConfiguration? = nil) -> Bool {
        // iCloud-Placeholder werden separat behandelt (nicht skippen, sondern Download triggern)
        if isICloudPlaceholder(filename) { return true }

        // Versteckte Dateien
        if filename.hasPrefix(".") { return true }
        // Temporäre Dateien
        if filename.hasPrefix("~") || filename.hasSuffix(".tmp") { return true }

        // Dateierweiterung prüfen (Config-aware)
        let ext = (filename as NSString).pathExtension.lowercased()
        let excludedExts = effectiveExcludedExtensions(config: config)
        if !ext.isEmpty && excludedExts.contains(".\(ext)") {
            return true
        }

        // Präfix prüfen (Config-aware)
        let prefixes = effectiveExcludedPrefixes(config: config)
        for prefix in prefixes {
            if filename.hasPrefix(prefix) { return true }
        }

        // Ordner prüfen (Config-aware)
        let excludedDirs = effectiveExcludedDirectories(config: config)
        let components = filePath.split(separator: "/").map(String.init)
        for component in components {
            if excludedDirs.contains(component) { return true }
        }

        // Bereits im Schema
        if matchesSchema(filename) { return true }

        return false
    }
}
