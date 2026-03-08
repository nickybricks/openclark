import Foundation
import GRDB

/// Verwaltet die SQLite-Datenbank via GRDB.
final class DatabaseManager: Sendable {

    let dbQueue: DatabaseQueue

    init() throws {
        let dbPath = DatabaseManager.databasePath()
        let directory = (dbPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: directory, withIntermediateDirectories: true
        )
        dbQueue = try DatabaseQueue(path: dbPath)
        try migrate()
    }

    // MARK: - Pfad

    static func databasePath() -> String {
        let base = NSHomeDirectory()
        return "\(base)/.local/share/openclark/history.db"
    }

    // MARK: - Migration

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            // Renames-Tabelle
            try db.create(table: "renames", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("originalPath", .text).notNull()
                t.column("newPath", .text).notNull()
                t.column("originalName", .text).notNull()
                t.column("newName", .text).notNull()
                t.column("category", .text).notNull()
                t.column("source", .text).notNull() // "filename", "pdf_keywords", "llm"
                t.column("renamedAt", .datetime).notNull()
                t.column("undone", .boolean).notNull().defaults(to: false)
            }

            // Bestehende Dateien (Snapshot)
            try db.create(table: "existingFiles", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("filepath", .text).notNull().unique()
                t.column("fileSize", .integer)
                t.column("snapshotAt", .datetime).notNull()
            }

            // Verarbeitete Dateien
            try db.create(table: "processedFiles", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("filepath", .text).notNull().unique()
                t.column("originalName", .text).notNull()
                t.column("newName", .text).notNull()
                t.column("category", .text).notNull()
                t.column("processedAt", .datetime).notNull()
            }
        }

        // v2: Dry-Run Spalte hinzufügen
        migrator.registerMigration("v2_dryRun") { db in
            try db.alter(table: "renames") { t in
                t.add(column: "dryRun", .boolean).notNull().defaults(to: false)
            }
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Renames

    func recordRename(_ record: RenameRecord) throws {
        try dbQueue.write { db in
            var rec = record
            try rec.insert(db)
        }
    }

    func recentRenames(limit: Int = 5) throws -> [RenameRecord] {
        try dbQueue.read { db in
            try RenameRecord
                .filter(Column("undone") == false)
                .order(Column("renamedAt").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func todayRenameCount() throws -> Int {
        try dbQueue.read { db in
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            return try RenameRecord
                .filter(Column("undone") == false)
                .filter(Column("renamedAt") >= startOfDay)
                .fetchCount(db)
        }
    }

    func undoRename(id: Int64) throws -> RenameRecord? {
        try dbQueue.write { db in
            guard var record = try RenameRecord.fetchOne(db, key: id) else {
                return nil
            }
            record.undone = true
            try record.update(db)
            return record
        }
    }

    func allRenames() throws -> [RenameRecord] {
        try dbQueue.read { db in
            try RenameRecord
                .order(Column("renamedAt").desc)
                .fetchAll(db)
        }
    }

    func clearHistory() throws {
        try dbQueue.write { db in
            _ = try RenameRecord.deleteAll(db)
        }
    }

    // MARK: - Existing Files (Snapshot)

    func hasSnapshot() throws -> Bool {
        try dbQueue.read { db in
            try ExistingFileRecord.fetchCount(db) > 0
        }
    }

    func snapshotFile(path: String, size: Int64?) throws {
        try dbQueue.write { db in
            var record = ExistingFileRecord(
                filepath: path,
                fileSize: size,
                snapshotAt: Date()
            )
            try record.insert(db, onConflict: .ignore)
        }
    }

    func isExistingFile(_ path: String) throws -> Bool {
        try dbQueue.read { db in
            try ExistingFileRecord
                .filter(Column("filepath") == path)
                .fetchCount(db) > 0
        }
    }

    // MARK: - Processed Files

    func markProcessed(path: String, originalName: String, newName: String, category: String) throws {
        try dbQueue.write { db in
            var record = ProcessedFileRecord(
                filepath: path,
                originalName: originalName,
                newName: newName,
                category: category,
                processedAt: Date()
            )
            try record.insert(db, onConflict: .replace)
        }
    }

    func isProcessed(_ path: String) throws -> Bool {
        try dbQueue.read { db in
            try ProcessedFileRecord
                .filter(Column("filepath") == path)
                .fetchCount(db) > 0
        }
    }
}
