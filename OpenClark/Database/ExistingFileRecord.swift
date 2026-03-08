import Foundation
import GRDB

/// Ein Eintrag im Snapshot bestehender Dateien.
struct ExistingFileRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    var id: Int64?
    var filepath: String
    var fileSize: Int64?
    var snapshotAt: Date

    static let databaseTableName = "existingFiles"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
