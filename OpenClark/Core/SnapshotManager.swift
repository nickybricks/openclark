import Foundation
import os.log

/// Erfasst bestehende Dateien beim ersten Start (Snapshot).
enum SnapshotManager {

    private static let logger = Logger(subsystem: "com.openclark", category: "snapshot")

    /// Erstelle Snapshot aller bestehenden Dateien in überwachten Ordnern.
    static func createSnapshot(directories: [String], database: DatabaseManager, recursive: Bool) {
        let fm = FileManager.default
        let excludedDirs = FileFilters.effectiveExcludedDirectories()

        for dir in directories {
            let expandedDir = (dir as NSString).expandingTildeInPath
            guard fm.fileExists(atPath: expandedDir) else {
                logger.warning("Ordner existiert nicht: \(expandedDir)")
                continue
            }

            var count = 0
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: expandedDir),
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: recursive ? [] : [.skipsSubdirectoryDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                // Ordner-Ausschlüsse
                if let isDir = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir {
                    if excludedDirs.contains(fileURL.lastPathComponent) || fileURL.lastPathComponent.hasPrefix(".") {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
                try? database.snapshotFile(path: fileURL.path, size: size)
                count += 1
            }

            logger.info("Snapshot: \(count) Dateien in \(expandedDir)")
        }
    }
}
