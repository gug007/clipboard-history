import Foundation
import GRDB

final class HistoryStore {
    private let pool: DatabasePool

    init(databaseURL: URL) throws {
        self.pool = try AppDatabase.openPool(at: databaseURL)
    }

    func append(_ entry: ClipEntry, payloads: [ClipPayload]) throws {
        try pool.write { db in
            // 5-second dedup: bump createdAt of existing same-hash entry instead of inserting.
            let recentSame = try ClipEntry
                .filter(Column("contentHash") == entry.contentHash)
                .filter(Column("deletedAt") == nil)
                .filter(Column("createdAt") > entry.createdAt.addingTimeInterval(-5))
                .fetchOne(db)
            if var existing = recentSame {
                existing.createdAt = entry.createdAt
                existing.updatedAt = entry.createdAt
                try existing.update(db)
                return
            }

            try entry.insert(db)
            for p in payloads { try p.insert(db) }

            try db.execute(
                sql: """
                INSERT INTO clip_fts (entryId, title, body, filenames, sourceApp)
                VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [
                    entry.id,
                    entry.displayTitle,
                    entry.searchableText,
                    payloads.compactMap(\.filename).joined(separator: " "),
                    entry.sourceAppName ?? entry.sourceApp ?? ""
                ]
            )
        }
    }

    func recent(limit: Int = 50) throws -> [ClipEntry] {
        try pool.read { db in
            try ClipEntry
                .filter(Column("deletedAt") == nil)
                .order(Column("isPinned").desc, Column("createdAt").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func payloads(for entryId: String) throws -> [ClipPayload] {
        try pool.read { db in
            try ClipPayload
                .filter(Column("entryId") == entryId)
                .order(Column("position"))
                .fetchAll(db)
        }
    }

    func delete(id: String) throws {
        try pool.write { db in
            let now = Date()
            try db.execute(
                sql: "UPDATE clip_entry SET deletedAt = ?, updatedAt = ? WHERE id = ?",
                arguments: [now, now, id]
            )
            try db.execute(sql: "DELETE FROM clip_fts WHERE entryId = ?", arguments: [id])
        }
    }

    func togglePin(id: String) throws {
        try pool.write { db in
            let now = Date()
            try db.execute(
                sql: """
                UPDATE clip_entry
                SET isPinned = NOT isPinned,
                    pinnedAt = CASE WHEN NOT isPinned THEN ? ELSE NULL END,
                    updatedAt = ?
                WHERE id = ?
                """,
                arguments: [now, now, id]
            )
        }
    }

    func observeEntries(limit: Int = 100) -> AsyncValueObservation<[ClipEntry]> {
        ValueObservation
            .tracking { db in
                try ClipEntry
                    .filter(Column("deletedAt") == nil)
                    .order(Column("isPinned").desc, Column("createdAt").desc)
                    .limit(limit)
                    .fetchAll(db)
            }
            .values(in: pool)
    }
}
