import Foundation
import CryptoKit
import GRDB

struct ClipEntry: Codable, Identifiable, Equatable, Hashable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "clip_entry"

    enum Kind: Int, Codable {
        case text = 0
        case file = 1
        case image = 2
        case multiFile = 3
        case richText = 4
        case url = 5
    }

    var id: String
    var createdAt: Date
    var updatedAt: Date
    var deviceId: String
    var kind: Kind
    var displayTitle: String
    var displaySubtitle: String?
    var byteSize: Int64
    var contentHash: String
    var sourceApp: String?
    var sourceAppName: String?
    var isPinned: Bool
    var pinnedAt: Date?
    var deletedAt: Date?
    var searchableText: String
}

extension ClipEntry {
    static func fromText(
        _ text: String,
        sourceApp: String?,
        sourceAppName: String?,
        deviceId: String
    ) -> (ClipEntry, ClipPayload) {
        let id = UUID().uuidString
        let now = Date()
        let firstLine = text
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            .first.map(String.init) ?? text
        let title = String(firstLine.prefix(120))

        let entry = ClipEntry(
            id: id,
            createdAt: now,
            updatedAt: now,
            deviceId: deviceId,
            kind: .text,
            displayTitle: title,
            displaySubtitle: sourceAppName.map { "from \($0)" },
            byteSize: Int64(text.utf8.count),
            contentHash: sha256(text.data(using: .utf8) ?? Data()),
            sourceApp: sourceApp,
            sourceAppName: sourceAppName,
            isPinned: false,
            pinnedAt: nil,
            deletedAt: nil,
            searchableText: text
        )

        let payload = ClipPayload(
            id: UUID().uuidString,
            entryId: id,
            position: 0,
            payloadKind: .text,
            inlineText: text,
            filename: nil,
            fileURLString: nil,
            bookmarkData: nil,
            uti: "public.utf8-plain-text",
            byteSize: Int64(text.utf8.count)
        )
        return (entry, payload)
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
