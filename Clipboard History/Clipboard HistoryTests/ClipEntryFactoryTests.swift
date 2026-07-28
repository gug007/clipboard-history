import Foundation
import GRDB
import XCTest
@testable import Clipboard_History

@MainActor
final class ClipEntryFactoryTests: XCTestCase {
    func testFromTextClassifiesOnlyAFullStringURLAndPreservesTimestamp() {
        let timestamp = Date(timeIntervalSince1970: 1_725_000_123)

        let (urlEntry, urlPayload) = ClipEntry.fromText(
            "  https://example.com/path?q=clipboard  ",
            sourceApp: "com.example.browser",
            sourceAppName: "Browser",
            deviceId: "test-device",
            timestamp: timestamp
        )
        XCTAssertEqual(urlEntry.kind, .url)
        XCTAssertEqual(urlPayload.payloadKind, .url)
        XCTAssertEqual(urlEntry.createdAt, timestamp)
        XCTAssertEqual(urlEntry.updatedAt, timestamp)
        XCTAssertEqual(urlPayload.inlineText, "  https://example.com/path?q=clipboard  ")

        let (sentenceEntry, sentencePayload) = ClipEntry.fromText(
            "Read https://example.com later",
            sourceApp: nil,
            sourceAppName: nil,
            deviceId: "test-device",
            timestamp: timestamp
        )
        XCTAssertEqual(sentenceEntry.kind, .text)
        XCTAssertEqual(sentencePayload.payloadKind, .text)

        let (plainEntry, _) = ClipEntry.fromText(
            "notes for tomorrow",
            sourceApp: nil,
            sourceAppName: nil,
            deviceId: "test-device",
            timestamp: timestamp
        )
        XCTAssertEqual(plainEntry.kind, .text)
    }

    func testRichTextAndImageFactoriesRetainRawPayloadsAndCaptureMetadata() {
        let timestamp = Date(timeIntervalSince1970: 1_725_100_456)
        let rtf = Data(#"{\rtf1 Clipboard}"#.utf8)
        let richEvent = CapturedRichTextEvent(
            data: rtf,
            pasteboardType: "public.rtf",
            uti: "public.rtf",
            plainText: "Clipboard",
            sourceApp: "com.example.editor",
            sourceAppName: "Editor",
            timestamp: timestamp
        )

        let (richEntry, richPayload) = ClipEntry.fromRichText(
            richEvent,
            deviceId: "test-device"
        )
        XCTAssertEqual(richEntry.kind, .richText)
        XCTAssertEqual(richEntry.createdAt, timestamp)
        XCTAssertEqual(richEntry.updatedAt, timestamp)
        XCTAssertEqual(richEntry.searchableText, "Clipboard")
        XCTAssertEqual(richPayload.payloadKind, .richText)
        XCTAssertEqual(richPayload.inlineText, "Clipboard")
        XCTAssertEqual(richPayload.inlineData, rtf)
        XCTAssertEqual(richPayload.dataFormat, "public.rtf")
        XCTAssertEqual(richPayload.uti, "public.rtf")

        let imageBytes = Data([0x89, 0x50, 0x4E, 0x47])
        let previewBytes = Data([0x01, 0x02, 0x03])
        let imageEvent = CapturedImageEvent(
            data: imageBytes,
            pasteboardType: "public.png",
            uti: "public.png",
            iconPNG: previewBytes,
            sourceApp: "com.example.graphics",
            sourceAppName: "Graphics",
            timestamp: timestamp
        )

        let (imageEntry, imagePayload) = ClipEntry.fromImage(
            imageEvent,
            deviceId: "test-device"
        )
        XCTAssertEqual(imageEntry.kind, .image)
        XCTAssertEqual(imageEntry.createdAt, timestamp)
        XCTAssertEqual(imageEntry.updatedAt, timestamp)
        XCTAssertEqual(imageEntry.byteSize, Int64(imageBytes.count))
        XCTAssertEqual(imagePayload.payloadKind, .image)
        XCTAssertEqual(imagePayload.inlineData, imageBytes)
        XCTAssertEqual(imagePayload.dataFormat, "public.png")
        XCTAssertEqual(imagePayload.uti, "public.png")
        XCTAssertEqual(imagePayload.iconPNG, previewBytes)
    }

    func testV3DatabaseAddsNullablePayloadColumnsAndPurgesSoftDeletedContent() throws {
        let fixture = try TemporaryDatabaseFixture()
        defer { fixture.remove() }

        var legacyQueue: DatabaseQueue? = try DatabaseQueue(path: fixture.databaseURL.path)
        try legacyQueue?.write { db in
            try db.execute(sql: """
                CREATE TABLE grdb_migrations (
                    identifier TEXT NOT NULL PRIMARY KEY
                );
                INSERT INTO grdb_migrations (identifier)
                VALUES ('v1'), ('v2_iconPNG'), ('v3_groups');

                CREATE TABLE clip_entry (
                    id TEXT PRIMARY KEY NOT NULL,
                    createdAt DATETIME NOT NULL,
                    updatedAt DATETIME NOT NULL,
                    deviceId TEXT NOT NULL,
                    kind INTEGER NOT NULL,
                    displayTitle TEXT NOT NULL,
                    displaySubtitle TEXT,
                    byteSize INTEGER NOT NULL,
                    contentHash TEXT NOT NULL,
                    sourceApp TEXT,
                    sourceAppName TEXT,
                    isPinned BOOLEAN NOT NULL DEFAULT 0,
                    pinnedAt DATETIME,
                    deletedAt DATETIME,
                    searchableText TEXT NOT NULL
                );
                CREATE TABLE clip_payload (
                    id TEXT PRIMARY KEY NOT NULL,
                    entryId TEXT NOT NULL
                        REFERENCES clip_entry(id) ON DELETE CASCADE,
                    position INTEGER NOT NULL,
                    payloadKind INTEGER NOT NULL,
                    inlineText TEXT,
                    filename TEXT,
                    fileURLString TEXT,
                    bookmarkData BLOB,
                    uti TEXT,
                    byteSize INTEGER NOT NULL,
                    iconPNG BLOB
                );
                CREATE VIRTUAL TABLE clip_fts USING fts5(
                    entryId UNINDEXED,
                    title,
                    body,
                    filenames,
                    sourceApp
                );
                CREATE TABLE clip_group (
                    id TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL,
                    sortOrder INTEGER NOT NULL,
                    createdAt DATETIME NOT NULL
                );
                CREATE TABLE clip_entry_group (
                    entryId TEXT NOT NULL
                        REFERENCES clip_entry(id) ON DELETE CASCADE,
                    groupId TEXT NOT NULL
                        REFERENCES clip_group(id) ON DELETE CASCADE,
                    addedAt DATETIME NOT NULL,
                    PRIMARY KEY (entryId, groupId)
                );
                """)

            let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
            try db.execute(
                sql: """
                    INSERT INTO clip_entry (
                        id, createdAt, updatedAt, deviceId, kind, displayTitle,
                        byteSize, contentHash, isPinned, searchableText
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "legacy-entry", timestamp, timestamp, "legacy-device",
                    ClipEntry.Kind.text.rawValue, "Legacy text", 11,
                    "legacy-hash", false, "Legacy text"
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO clip_payload (
                        id, entryId, position, payloadKind, inlineText, uti, byteSize
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "legacy-payload", "legacy-entry", 0,
                    ClipPayload.Kind.text.rawValue, "Legacy text",
                    "public.utf8-plain-text", 11
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO clip_fts (entryId, title, body, filenames, sourceApp)
                    VALUES (?, ?, ?, '', '')
                    """,
                arguments: ["legacy-entry", "Legacy text", "Legacy text"]
            )

            try db.execute(
                sql: """
                    INSERT INTO clip_entry (
                        id, createdAt, updatedAt, deviceId, kind, displayTitle,
                        byteSize, contentHash, isPinned, deletedAt, searchableText
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "deleted-entry", timestamp, timestamp, "legacy-device",
                    ClipEntry.Kind.text.rawValue, "Deleted secret", 14,
                    "deleted-hash", false, timestamp, "Deleted secret"
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO clip_payload (
                        id, entryId, position, payloadKind, inlineText, uti, byteSize
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "deleted-payload", "deleted-entry", 0,
                    ClipPayload.Kind.text.rawValue, "Deleted secret",
                    "public.utf8-plain-text", 14
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO clip_fts (entryId, title, body, filenames, sourceApp)
                    VALUES (?, ?, ?, '', '')
                    """,
                arguments: ["deleted-entry", "Deleted secret", "Deleted secret"]
            )
        }
        legacyQueue = nil

        var store: HistoryStore? = try HistoryStore(databaseURL: fixture.databaseURL)
        let payload = try XCTUnwrap(store?.payloads(for: "legacy-entry").first)
        XCTAssertEqual(payload.inlineText, "Legacy text")
        XCTAssertNil(payload.inlineData)
        XCTAssertNil(payload.dataFormat)
        XCTAssertTrue(try XCTUnwrap(store).payloads(for: "deleted-entry").isEmpty)
        XCTAssertFalse(try XCTUnwrap(store).recent().contains { $0.id == "deleted-entry" })
        store = nil

        let verificationQueue = try DatabaseQueue(path: fixture.databaseURL.path)
        try verificationQueue.read { db in
            let entryCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM clip_entry WHERE id = 'deleted-entry'"
            )
            let payloadCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM clip_payload WHERE entryId = 'deleted-entry'"
            )
            let ftsCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM clip_fts WHERE entryId = 'deleted-entry'"
            )
            XCTAssertEqual(entryCount, 0)
            XCTAssertEqual(payloadCount, 0)
            XCTAssertEqual(ftsCount, 0)
        }
    }
}

private final class TemporaryDatabaseFixture {
    let directoryURL: URL
    let databaseURL: URL

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardHistoryTests-\(UUID().uuidString)", isDirectory: true)
        databaseURL = directoryURL.appendingPathComponent("history.sqlite")
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
