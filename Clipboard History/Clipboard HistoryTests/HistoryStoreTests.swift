import Foundation
import XCTest
@testable import Clipboard_History

@MainActor
final class HistoryStoreTests: XCTestCase {
    private static var defaultsDomainName = ""
    private static var savedPersistentDomain: [String: Any]?

    override class func setUp() {
        super.setUp()
        let domainName = Bundle.main.bundleIdentifier ?? "app.clipboard-history"
        defaultsDomainName = domainName
        savedPersistentDomain = UserDefaults.standard.persistentDomain(forName: domainName)
        UserDefaults.standard.removePersistentDomain(forName: domainName)
    }

    override class func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: defaultsDomainName)
        if let savedPersistentDomain {
            UserDefaults.standard.setPersistentDomain(
                savedPersistentDomain,
                forName: defaultsDomainName
            )
        }
        super.tearDown()
    }

    func testSearchFindsAnEntryOutsideTheBrowseWindow() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let defaults = RetentionDefaultsSnapshot(overridingWith: 1_000)
        defer { defaults.restore() }

        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        var oldestID = ""
        for index in 0..<121 {
            let text = index == 0
                ? "deepneedle archived clipboard item"
                : "ordinary clipboard item \(index)"
            let (entry, payload) = ClipEntry.fromText(
                text,
                sourceApp: "com.example.source",
                sourceAppName: "Source",
                deviceId: "test-device",
                timestamp: baseDate.addingTimeInterval(TimeInterval(index * 60))
            )
            if index == 0 { oldestID = entry.id }
            try fixture.store.append(entry, payloads: [payload])
        }

        let browsingItems = try await firstItems(
            from: fixture.store,
            limit: 100,
            filter: .all
        )
        XCTAssertEqual(browsingItems.count, 100)
        XCTAssertFalse(browsingItems.map(\.id).contains(oldestID))

        let searchItems = try await firstItems(
            from: fixture.store,
            limit: 100,
            filter: .all,
            query: "deepneedle"
        )
        XCTAssertEqual(searchItems.map(\.id), [oldestID])
    }

    func testSearchAppliesFavoritesAndGroupFilters() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let defaults = RetentionDefaultsSnapshot(overridingWith: 1_000)
        defer { defaults.restore() }

        let favorite = try appendText(
            "filterterm favorite",
            timestamp: Date(timeIntervalSince1970: 1_700_001_000),
            to: fixture.store
        )
        let grouped = try appendText(
            "filterterm grouped",
            timestamp: Date(timeIntervalSince1970: 1_700_001_060),
            to: fixture.store
        )
        _ = try appendText(
            "filterterm ordinary",
            timestamp: Date(timeIntervalSince1970: 1_700_001_120),
            to: fixture.store
        )

        try fixture.store.toggleFavorite(id: favorite.id)
        let group = try fixture.store.createGroup(name: "Research")
        try fixture.store.setMembership(
            entryId: grouped.id,
            groupId: group.id,
            member: true
        )

        let favorites = try await firstItems(
            from: fixture.store,
            filter: .favorites,
            query: "filterterm"
        )
        XCTAssertEqual(favorites.map(\.id), [favorite.id])

        let groupItems = try await firstItems(
            from: fixture.store,
            filter: .group(group.id),
            query: "filterterm"
        )
        XCTAssertEqual(groupItems.map(\.id), [grouped.id])
        XCTAssertEqual(groupItems.first?.groupNames, ["Research"])
    }

    func testDeleteAndClearPermanentlyRemovePayloadRows() throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let defaults = RetentionDefaultsSnapshot(overridingWith: 1_000)
        defer { defaults.restore() }

        let first = try appendText(
            "delete me",
            timestamp: Date(timeIntervalSince1970: 1_700_002_000),
            to: fixture.store
        )
        let second = try appendText(
            "clear me",
            timestamp: Date(timeIntervalSince1970: 1_700_002_060),
            to: fixture.store
        )
        XCTAssertEqual(try fixture.store.payloads(for: first.id).count, 1)
        XCTAssertEqual(try fixture.store.payloads(for: second.id).count, 1)

        try fixture.store.delete(id: first.id)
        XCTAssertFalse(try fixture.store.recent().map(\.id).contains(first.id))
        XCTAssertTrue(try fixture.store.payloads(for: first.id).isEmpty)
        XCTAssertEqual(try fixture.store.payloads(for: second.id).count, 1)

        try fixture.store.clearAll()
        XCTAssertTrue(try fixture.store.recent().isEmpty)
        XCTAssertTrue(try fixture.store.payloads(for: second.id).isEmpty)
    }

    func testRetentionCapRemovesOnlyOverflowOrdinaryEntriesAndTheirPayloads() throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let defaults = RetentionDefaultsSnapshot(overridingWith: 1_000)
        defer { defaults.restore() }

        let baseDate = Date(timeIntervalSince1970: 1_700_003_000)
        let oldest = try appendText(
            "ordinary oldest",
            timestamp: baseDate,
            to: fixture.store
        )
        let middle = try appendText(
            "ordinary middle",
            timestamp: baseDate.addingTimeInterval(60),
            to: fixture.store
        )
        let newest = try appendText(
            "ordinary newest",
            timestamp: baseDate.addingTimeInterval(120),
            to: fixture.store
        )
        let pinned = try appendText(
            "pinned entry",
            timestamp: baseDate.addingTimeInterval(180),
            to: fixture.store
        )
        let grouped = try appendText(
            "grouped entry",
            timestamp: baseDate.addingTimeInterval(240),
            to: fixture.store
        )

        try fixture.store.toggleFavorite(id: pinned.id)
        let group = try fixture.store.createGroup(name: "Keep")
        try fixture.store.setMembership(
            entryId: grouped.id,
            groupId: group.id,
            member: true
        )

        AppSettings.shared.retentionCap = 1
        try fixture.store.enforceRetentionCap()

        let remainingIDs = Set(try fixture.store.recent(limit: 20).map(\.id))
        XCTAssertEqual(remainingIDs, Set([newest.id, pinned.id, grouped.id]))
        XCTAssertTrue(try fixture.store.payloads(for: oldest.id).isEmpty)
        XCTAssertTrue(try fixture.store.payloads(for: middle.id).isEmpty)
        XCTAssertEqual(try fixture.store.payloads(for: newest.id).count, 1)
        XCTAssertEqual(try fixture.store.payloads(for: pinned.id).count, 1)
        XCTAssertEqual(try fixture.store.payloads(for: grouped.id).count, 1)
    }

    private func appendText(
        _ text: String,
        timestamp: Date,
        to store: HistoryStore
    ) throws -> ClipEntry {
        let (entry, payload) = ClipEntry.fromText(
            text,
            sourceApp: nil,
            sourceAppName: nil,
            deviceId: "test-device",
            timestamp: timestamp
        )
        try store.append(entry, payloads: [payload])
        return entry
    }

    private func firstItems(
        from store: HistoryStore,
        limit: Int = 100,
        filter: HistoryStore.Filter,
        query: String = ""
    ) async throws -> [ClipItem] {
        for try await items in store.observeItems(
            limit: limit,
            filter: filter,
            query: query
        ) {
            return items
        }
        XCTFail("History observation finished without an initial value")
        return []
    }
}

private struct RetentionDefaultsSnapshot {
    private static let key = "settings.retentionCap"

    private let runtimeValue: Int
    private let storedValue: Int?

    init(overridingWith value: Int) {
        runtimeValue = AppSettings.shared.retentionCap
        storedValue = UserDefaults.standard.object(forKey: Self.key) as? Int
        AppSettings.shared.retentionCap = value
    }

    func restore() {
        AppSettings.shared.retentionCap = runtimeValue
        if let storedValue {
            UserDefaults.standard.set(storedValue, forKey: Self.key)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.key)
        }
    }
}

private final class StoreFixture {
    let directoryURL: URL
    let store: HistoryStore

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardHistoryStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        store = try HistoryStore(
            databaseURL: directoryURL.appendingPathComponent("history.sqlite")
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
