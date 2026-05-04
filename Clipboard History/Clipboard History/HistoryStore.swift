import Foundation
import GRDB

struct ClipItem: Identifiable, Equatable {
    let entry: ClipEntry
    let firstIcon: Data?
    let isStale: Bool

    var id: String { entry.id }
}

final class HistoryStore {
    private let pool: DatabasePool

    init(databaseURL: URL) throws {
        self.pool = try AppDatabase.openPool(at: databaseURL)
    }

    private static let dedupWindowSeconds: TimeInterval = 30

    func append(_ entry: ClipEntry, payloads: [ClipPayload]) throws {
        try pool.write { db in
            // 30-second dedup: bump createdAt of existing same-hash entry instead of inserting.
            let recentSame = try ClipEntry
                .filter(Column("contentHash") == entry.contentHash)
                .filter(Column("deletedAt") == nil)
                .filter(Column("createdAt") > entry.createdAt.addingTimeInterval(-Self.dedupWindowSeconds))
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

            try Self.pruneInTransaction(db: db, cap: AppSettings.shared.retentionCap)
        }
    }

    func clearAll() throws {
        try pool.write { db in
            try db.execute(sql: "DELETE FROM clip_payload")
            try db.execute(sql: "DELETE FROM clip_entry")
            try db.execute(sql: "DELETE FROM clip_fts")
            print("[Storage] cleared all history")
        }
    }

    private static func pruneInTransaction(db: GRDB.Database, cap: Int) throws {
        let toDeleteIds = try String.fetchAll(db, sql: """
            SELECT id FROM clip_entry
            WHERE deletedAt IS NULL AND isPinned = 0
            ORDER BY createdAt DESC
            LIMIT -1 OFFSET ?
            """, arguments: [cap])

        guard !toDeleteIds.isEmpty else { return }

        let now = Date()
        for id in toDeleteIds {
            try db.execute(
                sql: "UPDATE clip_entry SET deletedAt = ?, updatedAt = ? WHERE id = ?",
                arguments: [now, now, id]
            )
            try db.execute(
                sql: "DELETE FROM clip_fts WHERE entryId = ?",
                arguments: [id]
            )
        }
        print("[Retention] soft-deleted \(toDeleteIds.count) entries past cap=\(cap)")
    }

    func recent(limit: Int = 50) throws -> [ClipEntry] {
        try pool.read { db in
            try ClipEntry
                .filter(Column("deletedAt") == nil)
                .order(Column("createdAt").desc)
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

    func toggleFavorite(id: String) throws {
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

    func observeItems(limit: Int = 100) -> AsyncValueObservation<[ClipItem]> {
        ValueObservation
            .tracking { db -> [ClipItem] in
                let entries = try ClipEntry
                    .filter(Column("deletedAt") == nil)
                    .order(Column("createdAt").desc)
                    .limit(limit)
                    .fetchAll(db)

                return try entries.map { entry in
                    let firstIcon: Data?
                    var isStale = false
                    if entry.kind == .file || entry.kind == .multiFile {
                        let firstPayload = try ClipPayload
                            .filter(Column("entryId") == entry.id)
                            .order(Column("position"))
                            .limit(1)
                            .fetchOne(db)
                        firstIcon = firstPayload?.iconPNG
                        if let bookmark = firstPayload?.bookmarkData {
                            isStale = !Self.bookmarkResolvesToReachable(bookmark)
                        }
                    } else {
                        firstIcon = nil
                    }
                    return ClipItem(entry: entry, firstIcon: firstIcon, isStale: isStale)
                }
            }
            .values(in: pool)
    }

    private static func bookmarkResolvesToReachable(_ bookmark: Data) -> Bool {
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return false }
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }
        return (try? url.checkResourceIsReachable()) == true
    }
}
