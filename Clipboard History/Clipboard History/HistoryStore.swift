import Foundation
import GRDB

struct ClipItem: Identifiable, Equatable {
    let entry: ClipEntry
    let firstIcon: Data?
    let isStale: Bool

    var id: String { entry.id }
}

final class HistoryStore {
    enum Filter: Equatable, Hashable {
        case all
        case favorites
        case group(String)
    }

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
            WHERE deletedAt IS NULL
              AND isPinned = 0
              AND id NOT IN (SELECT entryId FROM clip_entry_group)
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

    func observeItems(limit: Int = 100, filter: Filter = .all) -> AsyncValueObservation<[ClipItem]> {
        ValueObservation
            .tracking { db -> [ClipItem] in
                let entries: [ClipEntry]
                switch filter {
                case .all:
                    entries = try ClipEntry
                        .filter(Column("deletedAt") == nil)
                        .order(Column("createdAt").desc)
                        .limit(limit)
                        .fetchAll(db)
                case .favorites:
                    entries = try ClipEntry
                        .filter(Column("deletedAt") == nil)
                        .filter(Column("isPinned") == true)
                        .order(Column("createdAt").desc)
                        .limit(limit)
                        .fetchAll(db)
                case .group(let groupId):
                    entries = try ClipEntry.fetchAll(db, sql: """
                        SELECT e.* FROM clip_entry e
                        JOIN clip_entry_group eg ON eg.entryId = e.id
                        WHERE e.deletedAt IS NULL AND eg.groupId = ?
                        ORDER BY e.createdAt DESC
                        LIMIT ?
                        """, arguments: [groupId, limit])
                }

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

    func observeGroups() -> AsyncValueObservation<[ClipGroup]> {
        ValueObservation
            .tracking { db -> [ClipGroup] in
                try ClipGroup
                    .order(Column("sortOrder"))
                    .fetchAll(db)
            }
            .values(in: pool)
    }

    @discardableResult
    func createGroup(name: String) throws -> ClipGroup {
        try pool.write { db in
            let nextOrder = try Int.fetchOne(
                db, sql: "SELECT COALESCE(MAX(sortOrder), -1) + 1 FROM clip_group"
            ) ?? 0
            let group = ClipGroup(
                id: UUID().uuidString,
                name: name,
                sortOrder: nextOrder,
                createdAt: Date()
            )
            try group.insert(db)
            return group
        }
    }

    func renameGroup(id: String, to name: String) throws {
        try pool.write { db in
            try db.execute(
                sql: "UPDATE clip_group SET name = ? WHERE id = ?",
                arguments: [name, id]
            )
        }
    }

    func deleteGroup(id: String) throws {
        try pool.write { db in
            try db.execute(
                sql: "DELETE FROM clip_group WHERE id = ?",
                arguments: [id]
            )
        }
    }

    func setMembership(entryId: String, groupId: String, member: Bool) throws {
        try pool.write { db in
            if member {
                try db.execute(sql: """
                    INSERT OR IGNORE INTO clip_entry_group (entryId, groupId, addedAt)
                    VALUES (?, ?, ?)
                    """, arguments: [entryId, groupId, Date()])
            } else {
                try db.execute(
                    sql: "DELETE FROM clip_entry_group WHERE entryId = ? AND groupId = ?",
                    arguments: [entryId, groupId]
                )
            }
        }
    }

    func groupIds(for entryId: String) throws -> Set<String> {
        try pool.read { db in
            let rows = try String.fetchAll(
                db, sql: "SELECT groupId FROM clip_entry_group WHERE entryId = ?",
                arguments: [entryId]
            )
            return Set(rows)
        }
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
