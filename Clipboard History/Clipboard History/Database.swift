import Foundation
import GRDB

enum AppDatabase {
    static func openPool(at url: URL) throws -> DatabasePool {
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        let pool = try DatabasePool(path: url.path, configuration: config)
        try migrator.migrate(pool)
        return pool
    }

    private static let migrator: DatabaseMigrator = {
        var m = DatabaseMigrator()

        m.registerMigration("v1") { db in
            try db.create(table: "clip_entry") { t in
                t.column("id", .text).primaryKey()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("deviceId", .text).notNull()
                t.column("kind", .integer).notNull()
                t.column("displayTitle", .text).notNull()
                t.column("displaySubtitle", .text)
                t.column("byteSize", .integer).notNull()
                t.column("contentHash", .text).notNull()
                t.column("sourceApp", .text)
                t.column("sourceAppName", .text)
                t.column("isPinned", .boolean).notNull().defaults(to: false)
                t.column("pinnedAt", .datetime)
                t.column("deletedAt", .datetime)
                t.column("searchableText", .text).notNull()
            }
            try db.create(
                index: "idx_clip_entry_recent",
                on: "clip_entry",
                columns: ["deletedAt", "isPinned", "createdAt"]
            )
            try db.create(index: "idx_clip_entry_hash", on: "clip_entry", columns: ["contentHash"])
            try db.create(index: "idx_clip_entry_deleted", on: "clip_entry", columns: ["deletedAt"])

            try db.create(table: "clip_payload") { t in
                t.column("id", .text).primaryKey()
                t.column("entryId", .text).notNull()
                    .references("clip_entry", onDelete: .cascade)
                t.column("position", .integer).notNull()
                t.column("payloadKind", .integer).notNull()
                t.column("inlineText", .text)
                t.column("filename", .text)
                t.column("fileURLString", .text)
                t.column("bookmarkData", .blob)
                t.column("uti", .text)
                t.column("byteSize", .integer).notNull()
            }
            try db.create(index: "idx_clip_payload_entry", on: "clip_payload", columns: ["entryId"])

            try db.create(virtualTable: "clip_fts", using: FTS5()) { t in
                t.column("entryId").notIndexed()
                t.column("title")
                t.column("body")
                t.column("filenames")
                t.column("sourceApp")
                t.tokenizer = .unicode61(diacritics: .removeLegacy)
            }
        }

        return m
    }()
}
