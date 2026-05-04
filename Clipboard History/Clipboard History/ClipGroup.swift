import Foundation
import GRDB

struct ClipGroup: Codable, Identifiable, Equatable, Hashable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "clip_group"

    var id: String
    var name: String
    var sortOrder: Int
    var createdAt: Date
}

struct ClipEntryGroup: Codable, Equatable, Hashable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "clip_entry_group"

    var entryId: String
    var groupId: String
    var addedAt: Date
}
