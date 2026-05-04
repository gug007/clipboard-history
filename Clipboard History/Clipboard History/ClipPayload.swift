import Foundation
import GRDB

struct ClipPayload: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "clip_payload"

    enum Kind: Int, Codable {
        case text = 0
        case file = 1
        case image = 2
        case richText = 4
        case url = 5
    }

    var id: String
    var entryId: String
    var position: Int
    var payloadKind: Kind
    var inlineText: String?
    var filename: String?
    var fileURLString: String?
    var bookmarkData: Data?
    var uti: String?
    var byteSize: Int64
}
