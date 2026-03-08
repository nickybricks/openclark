import Foundation
import GRDB

/// Ein Eintrag in der Rename-History.
struct RenameRecord: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Sendable {
    var id: Int64?
    var originalPath: String
    var newPath: String
    var originalName: String
    var newName: String
    var category: String
    var source: String // "filename", "pdf_keywords", "llm"
    var renamedAt: Date
    var undone: Bool
    var dryRun: Bool

    static let databaseTableName = "renames"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
