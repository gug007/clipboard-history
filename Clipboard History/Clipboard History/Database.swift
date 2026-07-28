import Foundation
import GRDB

enum AppDatabase {
    static func openPool(at url: URL) throws -> DatabasePool {
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            // Physical deletion should remove clipboard bytes from live
            // database pages immediately, even before a later VACUUM.
            try db.execute(sql: "PRAGMA secure_delete = ON")
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

        m.registerMigration("v2_iconPNG") { db in
            try db.alter(table: "clip_payload") { t in
                t.add(column: "iconPNG", .blob)
            }
        }

        m.registerMigration("v3_groups") { db in
            try db.create(table: "clip_group") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("sortOrder", .integer).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(
                index: "idx_clip_group_sort",
                on: "clip_group",
                columns: ["sortOrder"]
            )

            try db.create(table: "clip_entry_group") { t in
                t.column("entryId", .text).notNull()
                    .references("clip_entry", onDelete: .cascade)
                t.column("groupId", .text).notNull()
                    .references("clip_group", onDelete: .cascade)
                t.column("addedAt", .datetime).notNull()
                t.primaryKey(["entryId", "groupId"])
            }
            try db.create(
                index: "idx_clip_entry_group_entry",
                on: "clip_entry_group",
                columns: ["entryId"]
            )
            try db.create(
                index: "idx_clip_entry_group_group",
                on: "clip_entry_group",
                columns: ["groupId"]
            )
        }

        m.registerMigration("v4_inline_payload_data") { db in
            try db.alter(table: "clip_payload") { t in
                t.add(column: "inlineData", .blob)
                t.add(column: "dataFormat", .text)
            }
        }

        m.registerMigration("v5_purge_legacy_soft_deletes") { db in
            // Purge children explicitly before their legacy tombstones.
            // This is robust even for databases whose older foreign-key
            // definitions or migration state do not apply cascades here.
            try db.execute(sql: """
                DELETE FROM clip_fts
                WHERE entryId IN (
                    SELECT id FROM clip_entry WHERE deletedAt IS NOT NULL
                )
                """)
            try db.execute(sql: """
                DELETE FROM clip_entry_group
                WHERE entryId IN (
                    SELECT id FROM clip_entry WHERE deletedAt IS NOT NULL
                )
                """)
            try db.execute(sql: """
                DELETE FROM clip_payload
                WHERE entryId IN (
                    SELECT id FROM clip_entry WHERE deletedAt IS NOT NULL
                )
                """)
            try db.execute(sql: "DELETE FROM clip_entry WHERE deletedAt IS NOT NULL")
        }

        return m
    }()
}
