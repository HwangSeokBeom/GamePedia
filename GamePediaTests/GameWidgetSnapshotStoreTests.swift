import XCTest
@testable import GamePedia

final class GameWidgetSnapshotStoreTests: XCTestCase {
    private enum Key {
        static let recentViewedRecords = "gamepedia.widget.recent_viewed.records.v1"
    }

    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var cacheDirectoryURL: URL!

    override func setUp() {
        super.setUp()
        suiteName = "GameWidgetSnapshotStoreTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        cacheDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GameWidgetSnapshotStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: cacheDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        if let cacheDirectoryURL {
            try? FileManager.default.removeItem(at: cacheDirectoryURL)
        }
        cacheDirectoryURL = nil
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRecordRecentViewed_dedupesByGameIDAndKeepsLatestFirst() {
        let store = makeStore()
        let olderDate = Date(timeIntervalSince1970: 100)
        let newerDate = Date(timeIntervalSince1970: 200)

        store.recordRecentViewed(makeRecord(gameID: 1, title: "First", viewedAt: olderDate))
        store.recordRecentViewed(makeRecord(gameID: 2, title: "Second", viewedAt: newerDate))
        store.recordRecentViewed(makeRecord(gameID: 1, title: "First Updated", viewedAt: newerDate))

        let records = store.loadRecentViewedRecords()

        XCTAssertEqual(records.map(\.gameID), [1, 2])
        XCTAssertEqual(records.first?.title, "First Updated")
        XCTAssertEqual(records.first?.viewedAt, newerDate)
    }

    func testRecordRecentViewed_capsAtTwelveItems() {
        let store = makeStore()

        (1...15).forEach { gameID in
            store.recordRecentViewed(
                makeRecord(
                    gameID: gameID,
                    title: "Game \(gameID)",
                    viewedAt: Date(timeIntervalSince1970: TimeInterval(gameID))
                )
            )
        }

        let records = store.loadRecentViewedRecords()

        XCTAssertEqual(records.count, 12)
        XCTAssertEqual(records.map(\.gameID), [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4])
    }

    func testLoadRecentViewedRecords_returnsEmptyAndClearsCorruptedData() {
        let store = makeStore()
        userDefaults.set(Data("not-json".utf8), forKey: Key.recentViewedRecords)

        let records = store.loadRecentViewedRecords()

        XCTAssertEqual(records, [])
        XCTAssertNil(userDefaults.data(forKey: Key.recentViewedRecords))
    }

    func testSaveAndLoadMyActivity_preservesWrittenReviewCount() {
        let store = makeStore()
        let snapshot = MyActivityWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1),
            state: .ready,
            headerTitle: "내 활동",
            headlineText: "",
            bodyText: "",
            targetURL: WidgetDeepLink.profile.url,
            stats: [
                .init(kind: .reviews, valueText: "6", labelText: "작성 리뷰"),
                .init(kind: .wishlist, valueText: "3", labelText: "찜"),
                .init(kind: .likes, valueText: "1", labelText: "좋아요")
            ],
            recentReviews: [],
            loggedOutContent: nil
        )

        store.saveMyActivity(snapshot)

        let loadedSnapshot = store.loadMyActivity()

        XCTAssertEqual(loadedSnapshot?.stats.first?.valueText, "6")
        XCTAssertEqual(loadedSnapshot?.stats.first?.labelText, "작성 리뷰")
    }

    func testImageKey_sameURLReusesSameKey() {
        let store = makeStore()
        let url = URL(string: "https://example.com/covers/123.jpg")

        let firstKey = store.imageKey(for: url)
        let secondKey = store.imageKey(for: url)

        XCTAssertEqual(firstKey, secondKey)
    }

    func testSaveAndLoadImageData_preservesCachedFile() throws {
        let store = makeStore()
        let remoteURL = URL(string: "https://example.com/covers/123.jpg")
        let key = try XCTUnwrap(store.imageKey(for: remoteURL))
        let data = Data([0x01, 0x02, 0x03, 0x04])

        try store.saveImageData(data, forKey: key)

        XCTAssertEqual(store.loadImageData(forKey: key), data)
        XCTAssertEqual(store.hasCachedImage(forKey: key), true)
    }

    func testLoadImageData_returnsNilForMissingCache() {
        let store = makeStore()

        XCTAssertNil(store.loadImageData(forKey: "missing"))
        XCTAssertEqual(store.hasCachedImage(forKey: "missing"), false)
    }

    private func makeStore() -> GameWidgetSnapshotStore {
        GameWidgetSnapshotStore(
            appGroupIdentifier: nil,
            userDefaults: userDefaults,
            cacheDirectoryURL: cacheDirectoryURL
        )
    }

    private func makeRecord(gameID: Int, title: String, viewedAt: Date) -> RecentViewedGameRecord {
        RecentViewedGameRecord(
            gameID: gameID,
            title: title,
            genreText: "RPG",
            ratingText: "4.8",
            coverImageURL: nil,
            viewedAt: viewedAt
        )
    }
}
