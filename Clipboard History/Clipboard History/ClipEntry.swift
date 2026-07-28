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
        deviceId: String,
        timestamp: Date = Date()
    ) -> (ClipEntry, ClipPayload) {
        let id = UUID().uuidString
        let kind: Kind = isURL(text) ? .url : .text
        let title = displayTitle(for: text)

        let entry = ClipEntry(
            id: id,
            createdAt: timestamp,
            updatedAt: timestamp,
            deviceId: deviceId,
            kind: kind,
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
            payloadKind: kind == .url ? .url : .text,
            inlineText: text,
            filename: nil,
            fileURLString: nil,
            bookmarkData: nil,
            uti: kind == .url ? "public.url" : "public.utf8-plain-text",
            byteSize: Int64(text.utf8.count),
            iconPNG: nil,
            inlineData: nil,
            dataFormat: nil
        )
        return (entry, payload)
    }

    static func fromRichText(
        _ event: CapturedRichTextEvent,
        deviceId: String
    ) -> (ClipEntry, ClipPayload) {
        let id = UUID().uuidString
        let byteSize = event.data.count + event.plainText.utf8.count
        let entry = ClipEntry(
            id: id,
            createdAt: event.timestamp,
            updatedAt: event.timestamp,
            deviceId: deviceId,
            kind: .richText,
            displayTitle: displayTitle(for: event.plainText),
            displaySubtitle: event.sourceAppName.map { "from \($0)" },
            byteSize: Int64(byteSize),
            contentHash: sha256(event.data),
            sourceApp: event.sourceApp,
            sourceAppName: event.sourceAppName,
            isPinned: false,
            pinnedAt: nil,
            deletedAt: nil,
            searchableText: event.plainText
        )
        let payload = ClipPayload(
            id: UUID().uuidString,
            entryId: id,
            position: 0,
            payloadKind: .richText,
            inlineText: event.plainText,
            filename: nil,
            fileURLString: nil,
            bookmarkData: nil,
            uti: event.uti,
            byteSize: Int64(byteSize),
            iconPNG: nil,
            inlineData: event.data,
            dataFormat: event.pasteboardType
        )
        return (entry, payload)
    }

    static func fromImage(
        _ event: CapturedImageEvent,
        deviceId: String
    ) -> (ClipEntry, ClipPayload) {
        let id = UUID().uuidString
        let formatName: String
        switch event.pasteboardType {
        case "public.png": formatName = "PNG"
        case "public.tiff": formatName = "TIFF"
        default: formatName = "Clipboard"
        }
        let title = "\(formatName) Image"
        let entry = ClipEntry(
            id: id,
            createdAt: event.timestamp,
            updatedAt: event.timestamp,
            deviceId: deviceId,
            kind: .image,
            displayTitle: title,
            displaySubtitle: event.sourceAppName.map { "from \($0)" },
            byteSize: Int64(event.data.count),
            contentHash: sha256(event.data),
            sourceApp: event.sourceApp,
            sourceAppName: event.sourceAppName,
            isPinned: false,
            pinnedAt: nil,
            deletedAt: nil,
            searchableText: "\(formatName) image"
        )
        let payload = ClipPayload(
            id: UUID().uuidString,
            entryId: id,
            position: 0,
            payloadKind: .image,
            inlineText: nil,
            filename: nil,
            fileURLString: nil,
            bookmarkData: nil,
            uti: event.uti,
            byteSize: Int64(event.data.count),
            iconPNG: event.iconPNG,
            inlineData: event.data,
            dataFormat: event.pasteboardType
        )
        return (entry, payload)
    }

    static func fromFiles(_ event: CapturedFileEvent, deviceId: String) -> (ClipEntry, [ClipPayload]) {
        let id = UUID().uuidString
        let kind: Kind = event.files.count > 1 ? .multiFile : .file

        let title: String
        if event.files.count == 1 {
            title = event.files[0].displayName
        } else {
            let names = event.files.prefix(3).map(\.displayName).joined(separator: ", ")
            let extra = event.files.count - 3
            title = extra > 0 ? "\(names) +\(extra) more" : names
        }

        let totalBytes = event.files.reduce(Int64(0)) { $0 + $1.byteSize }

        // Dedup key: stable across re-copies of the same set of paths/sizes/mtimes.
        let dedupSeed = event.files
            .map { "\($0.url.path):\($0.byteSize):\(Int($0.mtime.timeIntervalSince1970))" }
            .joined(separator: "|")
        let contentHash = sha256(dedupSeed.data(using: .utf8) ?? Data())

        let searchable = (
            event.files.map(\.displayName)
            + event.files.map { $0.url.deletingLastPathComponent().path }
        ).joined(separator: " ")

        let entry = ClipEntry(
            id: id,
            createdAt: event.timestamp,
            updatedAt: event.timestamp,
            deviceId: deviceId,
            kind: kind,
            displayTitle: title,
            displaySubtitle: event.sourceAppName.map { "from \($0)" },
            byteSize: totalBytes,
            contentHash: contentHash,
            sourceApp: event.sourceApp,
            sourceAppName: event.sourceAppName,
            isPinned: false,
            pinnedAt: nil,
            deletedAt: nil,
            searchableText: searchable
        )

        let payloads = event.files.enumerated().map { idx, info in
            ClipPayload(
                id: UUID().uuidString,
                entryId: id,
                position: idx,
                payloadKind: .file,
                inlineText: nil,
                filename: info.displayName,
                fileURLString: info.url.absoluteString,
                bookmarkData: info.bookmarkData,
                uti: info.uti,
                byteSize: info.byteSize,
                iconPNG: info.iconPNG,
                inlineData: nil,
                dataFormat: nil
            )
        }
        return (entry, payloads)
    }

    private static func displayTitle(for text: String) -> String {
        let firstLine = text
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            .first.map(String.init) ?? text
        return String(firstLine.prefix(120))
    }

    private static func isURL(_ text: String) -> Bool {
        let candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return false }
        let fullRange = NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)
        guard
            let detector = try? NSDataDetector(
                types: NSTextCheckingResult.CheckingType.link.rawValue
            ),
            let match = detector.firstMatch(
                in: candidate,
                options: [],
                range: fullRange
            )
        else { return false }
        return match.range == fullRange && match.url != nil
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
