import Foundation
import GRDB

/// Tracking: welche Dateien bereits verarbeitet wurden.
struct ProcessedFileRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    var id: Int64?
    var filepath: String
    var originalName: String
    var newName: String
    var category: String
    var processedAt: Date

    static let databaseTableName = "processedFiles"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
