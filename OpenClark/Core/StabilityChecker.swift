import Foundation

/// Prüft ob eine Datei stabil ist (Größe ändert sich nicht mehr).
enum StabilityChecker {

    /// Warte bis die Dateigröße sich 2x hintereinander nicht ändert.
    /// - Parameters:
    ///   - path: Dateipfad
    ///   - checkInterval: Sekunden zwischen Prüfungen
    ///   - timeout: Maximale Wartezeit in Sekunden
    /// - Returns: true wenn stabil, false wenn Timeout oder Datei nicht existiert
    static func waitForStable(
        path: String,
        checkInterval: TimeInterval = 1.0,
        timeout: TimeInterval = 30.0
    ) async -> Bool {
        let fm = FileManager.default
        var previousSize: Int64 = -1
        var stableCount = 0
        var elapsed: TimeInterval = 0

        while elapsed < timeout {
            guard fm.fileExists(atPath: path) else { return false }

            let currentSize: Int64
            do {
                let attrs = try fm.attributesOfItem(atPath: path)
                currentSize = (attrs[.size] as? Int64) ?? 0
            } catch {
                return false
            }

            if currentSize == previousSize && currentSize > 0 {
                stableCount += 1
                if stableCount >= 2 {
                    return true
                }
            } else {
                stableCount = 0
            }

            previousSize = currentSize
            try? await Task.sleep(for: .seconds(checkInterval))
            elapsed += checkInterval
        }

        return false
    }

    /// Schnelle Prüfung: Ist die Datei gerade stabil? (ohne Warten)
    static func isStable(path: String) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path),
              let attrs = try? fm.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64,
              size > 0 else {
            return false
        }
        return true
    }
}
