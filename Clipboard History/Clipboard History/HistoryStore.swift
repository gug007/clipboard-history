import Foundation
import GRDB

struct ClipItem: Identifiable, Equatable {
    let entry: ClipEntry
    let firstIcon: Data?
    let isStale: Bool
    let groupNames: [String]

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
            try db.execute(sql: "DELETE FROM clip_fts")
            try db.execute(sql: "DELETE FROM clip_entry_group")
            try db.execute(sql: "DELETE FROM clip_payload")
            try db.execute(sql: "DELETE FROM clip_entry")
            print("[Storage] cleared all history")
        }

        // Rebuild the database and truncate its WAL so removed clipboard content
        // is not left behind in unused database pages after an explicit clear.
        do {
            try pool.writeWithoutTransaction { db in
                try db.execute(sql: "VACUUM")
                try db.checkpoint(.truncate)
            }
        } catch {
            // The rows are already gone. Maintenance can fail transiently if a
            // reader is holding a snapshot, so don't report a failed clear.
            NSLog("Post-clear database maintenance failed: %@", String(describing: error))
        }
    }

    func enforceRetentionCap() throws {
        try pool.write { db in
            try Self.pruneInTransaction(db: db, cap: AppSettings.shared.retentionCap)
        }
    }

    private static func pruneInTransaction(db: GRDB.Database, cap: Int) throws {
        let legacyDeletedIds = try String.fetchAll(
            db,
            sql: "SELECT id FROM clip_entry WHERE deletedAt IS NOT NULL"
        )
        let overflowIds = try String.fetchAll(db, sql: """
            SELECT id FROM clip_entry
            WHERE deletedAt IS NULL
              AND isPinned = 0
              AND id NOT IN (SELECT entryId FROM clip_entry_group)
            ORDER BY createdAt DESC
            LIMIT -1 OFFSET ?
            """, arguments: [max(0, cap)])

        let toDeleteIds = legacyDeletedIds + overflowIds
        guard !toDeleteIds.isEmpty else { return }

        try deleteEntries(db: db, ids: toDeleteIds)
        print("[Retention] permanently deleted \(toDeleteIds.count) entries past cap=\(cap)")
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
            try Self.deleteEntries(db: db, ids: [id])
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

    func observeItems(
        limit: Int = 100,
        filter: Filter = .all,
        query: String = ""
    ) -> AsyncValueObservation<[ClipItem]> {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let ftsQuery = Self.makeFTSQuery(from: trimmedQuery)

        return ValueObservation
            .tracking { db -> [ClipItem] in
                let entries: [ClipEntry]
                if trimmedQuery.isEmpty {
                    entries = try Self.fetchBrowsingEntries(
                        db: db,
                        limit: limit,
                        filter: filter
                    )
                } else if let ftsQuery {
                    entries = try Self.fetchSearchEntries(
                        db: db,
                        limit: limit,
                        filter: filter,
                        ftsQuery: ftsQuery
                    )
                } else {
                    entries = []
                }

                let groupsByEntry = try Self.fetchGroupNames(
                    db: db,
                    entryIds: entries.map(\.id)
                )
                let payloadMetadata = try Self.fetchPayloadMetadata(
                    db: db,
                    entryIds: entries
                        .filter {
                            $0.kind == .file
                                || $0.kind == .multiFile
                                || $0.kind == .image
                        }
                        .map(\.id)
                )

                return entries.map { entry in
                    let firstIcon: Data?
                    var isStale = false
                    if entry.kind == .file || entry.kind == .multiFile {
                        let metadata = payloadMetadata[entry.id]
                        firstIcon = metadata?.firstIconPNG
                        let bookmarks = metadata?.bookmarks ?? []
                        isStale = bookmarks.isEmpty || bookmarks.contains { bookmark in
                            guard let bookmark else { return true }
                            return !Self.bookmarkResolvesToReachable(bookmark)
                        }
                    } else if entry.kind == .image {
                        firstIcon = payloadMetadata[entry.id]?.firstIconPNG
                    } else {
                        firstIcon = nil
                    }
                    return ClipItem(
                        entry: entry,
                        firstIcon: firstIcon,
                        isStale: isStale,
                        groupNames: groupsByEntry[entry.id] ?? []
                    )
                }
            }
            .values(in: pool)
    }

    private static func fetchBrowsingEntries(
        db: GRDB.Database,
        limit: Int,
        filter: Filter
    ) throws -> [ClipEntry] {
        switch filter {
        case .all:
            return try ClipEntry
                .filter(Column("deletedAt") == nil)
                .order(Column("createdAt").desc)
                .limit(limit)
                .fetchAll(db)
        case .favorites:
            return try ClipEntry
                .filter(Column("deletedAt") == nil)
                .filter(Column("isPinned") == true)
                .order(Column("createdAt").desc)
                .limit(limit)
                .fetchAll(db)
        case .group(let groupId):
            return try ClipEntry.fetchAll(db, sql: """
                SELECT e.* FROM clip_entry e
                JOIN clip_entry_group eg ON eg.entryId = e.id
                WHERE e.deletedAt IS NULL AND eg.groupId = ?
                ORDER BY e.createdAt DESC
                LIMIT ?
                """, arguments: [groupId, max(0, limit)])
        }
    }

    private static func fetchSearchEntries(
        db: GRDB.Database,
        limit: Int,
        filter: Filter,
        ftsQuery: String
    ) throws -> [ClipEntry] {
        let filterJoin: String
        let filterPredicate: String
        var arguments: StatementArguments = [ftsQuery]

        switch filter {
        case .all:
            filterJoin = ""
            filterPredicate = ""
        case .favorites:
            filterJoin = ""
            filterPredicate = " AND e.isPinned = 1"
        case .group(let groupId):
            filterJoin = " JOIN clip_entry_group eg ON eg.entryId = e.id"
            filterPredicate = " AND eg.groupId = ?"
            arguments += [groupId]
        }
        arguments += [max(0, limit)]

        return try ClipEntry.fetchAll(db, sql: """
            SELECT e.*
            FROM clip_fts
            JOIN clip_entry e ON e.id = clip_fts.entryId
            \(filterJoin)
            WHERE clip_fts MATCH ?
              AND e.deletedAt IS NULL\(filterPredicate)
            ORDER BY bm25(clip_fts), e.createdAt DESC
            LIMIT ?
            """, arguments: arguments)
    }

    /// Converts arbitrary user text into a literal, prefix-matching FTS5 query.
    /// Keeping only letter/number runs prevents FTS operators, quotes, and
    /// punctuation from changing query structure or causing syntax errors.
    private static func makeFTSQuery(from query: String) -> String? {
        let tokens = query
            .split { !$0.isLetter && !$0.isNumber }
            .prefix(16)
            .map { String($0.prefix(80)) }
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else { return nil }
        return tokens
            .map { "\"\($0)\"*" }
            .joined(separator: " AND ")
    }

    private struct EntryPayloadMetadata {
        var firstIconPNG: Data?
        var bookmarks: [Data?]
    }

    private static func fetchPayloadMetadata(
        db: GRDB.Database,
        entryIds: [String]
    ) throws -> [String: EntryPayloadMetadata] {
        guard !entryIds.isEmpty else { return [:] }

        let placeholders = entryIds.map { _ in "?" }.joined(separator: ",")
        let rows = try Row.fetchAll(db, sql: """
            SELECT entryId, iconPNG, bookmarkData
            FROM clip_payload
            WHERE entryId IN (\(placeholders))
            ORDER BY entryId, position, id
            """, arguments: StatementArguments(entryIds))

        var result: [String: EntryPayloadMetadata] = [:]
        result.reserveCapacity(entryIds.count)
        for row in rows {
            let entryId: String = row["entryId"]
            let iconPNG: Data? = row["iconPNG"]
            let bookmarkData: Data? = row["bookmarkData"]
            if result[entryId] == nil {
                result[entryId] = EntryPayloadMetadata(
                    firstIconPNG: iconPNG,
                    bookmarks: [bookmarkData]
                )
            } else {
                result[entryId]?.bookmarks.append(bookmarkData)
            }
        }
        return result
    }

    private static func deleteEntries(db: GRDB.Database, ids: [String]) throws {
        guard !ids.isEmpty else { return }

        // Stay well below SQLite's bound-variable limit when a lowered
        // retention cap removes a large existing history.
        let batchSize = 500
        for start in stride(from: 0, to: ids.count, by: batchSize) {
            let end = min(start + batchSize, ids.count)
            let batch = Array(ids[start..<end])
            let placeholders = batch.map { _ in "?" }.joined(separator: ",")
            let arguments = StatementArguments(batch)

            try db.execute(
                sql: "DELETE FROM clip_fts WHERE entryId IN (\(placeholders))",
                arguments: arguments
            )
            try db.execute(
                sql: "DELETE FROM clip_entry_group WHERE entryId IN (\(placeholders))",
                arguments: arguments
            )
            try db.execute(
                sql: "DELETE FROM clip_payload WHERE entryId IN (\(placeholders))",
                arguments: arguments
            )
            try db.execute(
                sql: "DELETE FROM clip_entry WHERE id IN (\(placeholders))",
                arguments: arguments
            )
        }
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

    private static func fetchGroupNames(
        db: GRDB.Database,
        entryIds: [String]
    ) throws -> [String: [String]] {
        guard !entryIds.isEmpty else { return [:] }
        let placeholders = entryIds.map { _ in "?" }.joined(separator: ",")
        let rows = try Row.fetchAll(db, sql: """
            SELECT eg.entryId, g.name
            FROM clip_entry_group eg
            JOIN clip_group g ON g.id = eg.groupId
            WHERE eg.entryId IN (\(placeholders))
            ORDER BY g.sortOrder
            """, arguments: StatementArguments(entryIds))
        var result: [String: [String]] = [:]
        for row in rows {
            let entryId: String = row[0]
            let name: String = row[1]
            result[entryId, default: []].append(name)
        }
        return result
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
