import XCTest
@testable import GamePedia

final class GameWidgetSnapshotRefreshServiceTests: XCTestCase {

    func testRefreshNow_savesTrendingSnapshotWithTopFourItems() async {
        let store = SpySnapshotStore()
        let reloader = SpyWidgetTimelineReloader()
        let service = GameWidgetSnapshotRefreshService(
            snapshotStore: store,
            widgetReloader: reloader,
            authTokenProvider: { nil },
            recentViewedRecordsProvider: { [] },
            trendingGamesProvider: {
                [
                    Self.makeGame(id: 1, title: "One"),
                    Self.makeGame(id: 2, title: "Two"),
                    Self.makeGame(id: 3, title: "Three"),
                    Self.makeGame(id: 4, title: "Four")
                ]
            },
            favoriteEntriesProvider: { [] },
            reviewedGamesProvider: { [] },
            profileSummaryProvider: { Self.makeUserProfile() },
            writtenReviewCountProvider: { Self.makeUserProfile().writtenReviewCount }
        )

        await service.refreshNow(reason: "test")

        XCTAssertEqual(store.trendingSnapshot?.items.map(\.gameID), [1, 2, 3, 4])
        XCTAssertEqual(store.trendingSnapshot?.items.map(\.rank), [1, 2, 3, 4])
        XCTAssertEqual(reloader.reloadedKinds.contains(GameWidgetKind.trendingGames), true)
    }

    func testRefreshNow_recentViewedReason_savesRecentViewedSnapshot() async {
        let store = SpySnapshotStore()
        let reloader = SpyWidgetTimelineReloader()
        let now = Date()
        let service = GameWidgetSnapshotRefreshService(
            snapshotStore: store,
            widgetReloader: reloader,
            authTokenProvider: { nil },
            recentViewedRecordsProvider: {
                [
                    RecentViewedGameRecord(
                        gameID: 77,
                        title: "Viewed Title",
                        genreText: "Action",
                        ratingText: "4.8",
                        coverImageURL: URL(string: "https://example.com/77.jpg"),
                        viewedAt: now
                    )
                ]
            },
            trendingGamesProvider: { [] },
            favoriteEntriesProvider: { [] },
            reviewedGamesProvider: { [] },
            profileSummaryProvider: { Self.makeUserProfile() },
            writtenReviewCountProvider: { Self.makeUserProfile().writtenReviewCount }
        )

        await service.refreshNow(reason: "recentViewedDidChange")

        XCTAssertEqual(store.recentViewedSnapshot?.state, .ready)
        XCTAssertEqual(store.recentViewedSnapshot?.items.first?.gameID, 77)
        XCTAssertEqual(reloader.reloadedKinds, [GameWidgetKind.recentViewed])
    }

    func testRefreshNow_savesLoggedOutReviewPromptWhenAuthTokenMissing() async {
        let store = SpySnapshotStore()
        let reloader = SpyWidgetTimelineReloader()
        let service = GameWidgetSnapshotRefreshService(
            snapshotStore: store,
            widgetReloader: reloader,
            authTokenProvider: { nil },
            recentViewedRecordsProvider: { [] },
            trendingGamesProvider: { [] },
            favoriteEntriesProvider: { XCTFail("favorites should not be fetched for logged-out state"); return [] },
            reviewedGamesProvider: { XCTFail("reviews should not be fetched for logged-out state"); return [] },
            profileSummaryProvider: { XCTFail("profile should not be fetched for logged-out state"); return Self.makeUserProfile() },
            writtenReviewCountProvider: { XCTFail("review count should not be fetched for logged-out state"); return 0 }
        )

        await service.refreshNow(reason: "loggedOut")

        XCTAssertEqual(store.reviewPromptSnapshot?.state, .loggedOut)
        XCTAssertEqual(store.reviewPromptSnapshot?.targetURL, WidgetDeepLink.login.url)
        XCTAssertEqual(store.myActivitySnapshot?.state, .loggedOut)
        XCTAssertEqual(reloader.reloadedKinds.contains(GameWidgetKind.reviewPrompt), true)
        XCTAssertEqual(reloader.reloadedKinds.contains(GameWidgetKind.myActivity), true)
    }

    func testRefreshNow_savesEmptyReviewPromptWhenNoEligibleFavoriteExists() async {
        let store = SpySnapshotStore()
        let reloader = SpyWidgetTimelineReloader()
        let service = GameWidgetSnapshotRefreshService(
            snapshotStore: store,
            widgetReloader: reloader,
            authTokenProvider: { "token" },
            recentViewedRecordsProvider: { [] },
            trendingGamesProvider: { [] },
            favoriteEntriesProvider: {
                [
                    Self.makeFavoriteGameEntry(id: 10, title: "Reviewed Favorite", createdAt: Date())
                ]
            },
            reviewedGamesProvider: {
                [
                    Self.makeReviewedGame(id: 10, title: "Reviewed Favorite")
                ]
            },
            profileSummaryProvider: { Self.makeUserProfile() },
            writtenReviewCountProvider: { Self.makeUserProfile().writtenReviewCount }
        )

        await service.refreshNow(reason: "empty")

        XCTAssertEqual(store.reviewPromptSnapshot?.state, .empty)
        XCTAssertEqual(store.reviewPromptSnapshot?.headlineText, "리뷰할 찜 게임이 없어요")
        XCTAssertEqual(store.reviewPromptSnapshot?.targetURL, WidgetDeepLink.trending.url)
        XCTAssertNil(store.reviewPromptSnapshot?.item)
    }

    func testRefreshNow_savesReadyReviewPromptForFirstNonReviewedFavorite() async {
        let store = SpySnapshotStore()
        let reloader = SpyWidgetTimelineReloader()
        let service = GameWidgetSnapshotRefreshService(
            snapshotStore: store,
            widgetReloader: reloader,
            authTokenProvider: { "token" },
            recentViewedRecordsProvider: { [] },
            trendingGamesProvider: { [] },
            favoriteEntriesProvider: {
                [
                    Self.makeFavoriteGameEntry(id: 20, title: "Already Reviewed", createdAt: Date()),
                    Self.makeFavoriteGameEntry(id: 21, title: "Need Review", createdAt: Date())
                ]
            },
            reviewedGamesProvider: {
                [
                    Self.makeReviewedGame(id: 20, title: "Already Reviewed")
                ]
            },
            profileSummaryProvider: { Self.makeUserProfile() },
            writtenReviewCountProvider: { Self.makeUserProfile().writtenReviewCount }
        )

        await service.refreshNow(reason: "ready")

        XCTAssertEqual(store.reviewPromptSnapshot?.state, .ready)
        XCTAssertEqual(store.reviewPromptSnapshot?.item?.gameID, 21)
        XCTAssertEqual(store.reviewPromptSnapshot?.headlineText, "Need Review")
        XCTAssertEqual(store.reviewPromptSnapshot?.targetURL, WidgetDeepLink.reviewNew(21).url)
        XCTAssertEqual(reloader.reloadedKinds.contains(GameWidgetKind.reviewPrompt), true)
    }

    func testRefreshNow_reviewPromptReadySnapshotCapsItemsAtFourAndBuildsTargets() async {
        let store = SpySnapshotStore()
        let reloader = SpyWidgetTimelineReloader()
        let service = GameWidgetSnapshotRefreshService(
            snapshotStore: store,
            widgetReloader: reloader,
            authTokenProvider: { "token" },
            recentViewedRecordsProvider: { [] },
            trendingGamesProvider: { [] },
            favoriteEntriesProvider: {
                (1...5).map {
                    Self.makeFavoriteGameEntry(
                        id: 200 + $0,
                        title: "Favorite \($0)",
                        createdAt: Date()
                    )
                }
            },
            reviewedGamesProvider: { [] },
            profileSummaryProvider: { Self.makeUserProfile() },
            writtenReviewCountProvider: { Self.makeUserProfile().writtenReviewCount }
        )

        await service.refreshNow(reason: "ready")

        XCTAssertEqual(store.reviewPromptSnapshot?.state, .ready)
        XCTAssertEqual(store.reviewPromptSnapshot?.items.count, 4)
        XCTAssertEqual(store.reviewPromptSnapshot?.items.map(\.gameID), [201, 202, 203, 204])
        XCTAssertEqual(store.reviewPromptSnapshot?.items.first?.gameTargetURL, WidgetDeepLink.game(201).url)
        XCTAssertEqual(store.reviewPromptSnapshot?.items.first?.reviewTargetURL, WidgetDeepLink.reviewNew(201).url)
    }

    func testRefreshNow_savesMyActivityReadySnapshotWhenStatsOrReviewsExist() async {
        let store = SpySnapshotStore()
        let reloader = SpyWidgetTimelineReloader()
        let service = GameWidgetSnapshotRefreshService(
            snapshotStore: store,
            widgetReloader: reloader,
            authTokenProvider: { "token" },
            recentViewedRecordsProvider: { [] },
            trendingGamesProvider: { [] },
            favoriteEntriesProvider: { [] },
            reviewedGamesProvider: {
                [Self.makeReviewedGame(id: 21, title: "Need Review")]
            },
            profileSummaryProvider: {
                Self.makeUserProfile(reviewCount: 12, wishlistCount: 8, likeCount: 34)
            },
            writtenReviewCountProvider: { 12 }
        )

        await service.refreshNow(reason: "reviewDidChange")

        XCTAssertEqual(store.myActivitySnapshot?.state, .ready)
        XCTAssertEqual(store.myActivitySnapshot?.stats.map(\.valueText), ["12", "8", "34"])
        XCTAssertEqual(store.myActivitySnapshot?.stats.first?.labelText, "작성 리뷰")
        XCTAssertEqual(store.myActivitySnapshot?.recentReviews.first?.reviewID, "review-21")
        XCTAssertEqual(store.myActivitySnapshot?.recentReviews.first?.targetURL, WidgetDeepLink.review("review-21").url)
        XCTAssertEqual(reloader.reloadedKinds.contains(GameWidgetKind.myActivity), true)
    }

    func testRefreshNow_myActivityPrimaryStatUsesWrittenReviewCountSemantics() async {
        let store = SpySnapshotStore()
        let reloader = SpyWidgetTimelineReloader()
        let service = GameWidgetSnapshotRefreshService(
            snapshotStore: store,
            widgetReloader: reloader,
            authTokenProvider: { "token" },
            recentViewedRecordsProvider: { [] },
            trendingGamesProvider: { [] },
            favoriteEntriesProvider: { [] },
            reviewedGamesProvider: { [] },
            profileSummaryProvider: {
                Self.makeUserProfile(reviewCount: 0, wishlistCount: 3, likeCount: 1)
            },
            writtenReviewCountProvider: { 6 }
        )

        await service.refreshNow(reason: "favoriteDidChange")

        XCTAssertEqual(store.myActivitySnapshot?.state, .ready)
        XCTAssertEqual(store.myActivitySnapshot?.stats.first?.valueText, "6")
        XCTAssertEqual(store.myActivitySnapshot?.stats.first?.labelText, "작성 리뷰")
        XCTAssertEqual(reloader.reloadedKinds.contains(GameWidgetKind.myActivity), true)
    }

    func testRefreshNow_myActivityUsesSameReviewCountSourceAsProfileEvenWhenSummaryIsZero() async {
        let store = SpySnapshotStore()
        let reloader = SpyWidgetTimelineReloader()
        let service = GameWidgetSnapshotRefreshService(
            snapshotStore: store,
            widgetReloader: reloader,
            authTokenProvider: { "token" },
            recentViewedRecordsProvider: { [] },
            trendingGamesProvider: { [] },
            favoriteEntriesProvider: { [] },
            reviewedGamesProvider: {
                [Self.makeReviewedGame(id: 21, title: "Need Review")]
            },
            profileSummaryProvider: {
                Self.makeUserProfile(reviewCount: 0, wishlistCount: 3, likeCount: 1)
            },
            writtenReviewCountProvider: { 6 }
        )

        await service.refreshNow(reason: "showMainInterface")

        XCTAssertEqual(store.myActivitySnapshot?.stats.first?.valueText, "6")
        XCTAssertEqual(store.myActivitySnapshot?.stats.first?.labelText, "작성 리뷰")
        XCTAssertEqual(reloader.reloadedKinds.contains(GameWidgetKind.myActivity), true)
    }

    func testRefreshNow_savesMyActivityEmptySnapshotWhenNoStatsOrReviewsExist() async {
        let store = SpySnapshotStore()
        let reloader = SpyWidgetTimelineReloader()
        let service = GameWidgetSnapshotRefreshService(
            snapshotStore: store,
            widgetReloader: reloader,
            authTokenProvider: { "token" },
            recentViewedRecordsProvider: { [] },
            trendingGamesProvider: { [] },
            favoriteEntriesProvider: { [] },
            reviewedGamesProvider: { [] },
            profileSummaryProvider: {
                Self.makeUserProfile(reviewCount: 0, wishlistCount: 0, likeCount: 0)
            },
            writtenReviewCountProvider: { 0 }
        )

        await service.refreshNow(reason: "favoriteDidChange")

        XCTAssertEqual(store.myActivitySnapshot?.state, .empty)
        XCTAssertEqual(store.myActivitySnapshot?.headlineText, "아직 활동이 없어요")
    }

    func testRefreshNow_storesPreparedImageReferencesAcrossWidgetSnapshots() async {
        let store = SpySnapshotStore()
        let reloader = SpyWidgetTimelineReloader()
        let imagePrefetcher = StubImagePrefetcher(
            referencesByURL: [
                "https://example.com/77.jpg": "recent-key",
                "https://example.com/1.jpg": "trending-key",
                "https://example.com/21.jpg": "review-prompt-key",
                "https://example.com/31.jpg": "my-activity-key"
            ]
        )
        let now = Date()
        let service = GameWidgetSnapshotRefreshService(
            snapshotStore: store,
            widgetReloader: reloader,
            authTokenProvider: { "token" },
            recentViewedRecordsProvider: {
                [
                    RecentViewedGameRecord(
                        gameID: 77,
                        title: "Viewed Title",
                        genreText: "Action",
                        ratingText: "4.8",
                        coverImageURL: URL(string: "https://example.com/77.jpg"),
                        viewedAt: now
                    )
                ]
            },
            trendingGamesProvider: {
                [Self.makeGame(id: 1, title: "One")]
            },
            favoriteEntriesProvider: {
                [Self.makeFavoriteGameEntry(id: 21, title: "Need Review", createdAt: Date())]
            },
            reviewedGamesProvider: {
                [Self.makeReviewedGame(id: 31, title: "Reviewed Game")]
            },
            profileSummaryProvider: { Self.makeUserProfile() },
            writtenReviewCountProvider: { 6 },
            imagePrefetcher: imagePrefetcher
        )

        await service.refreshNow(reason: "showMainInterface")

        XCTAssertEqual(store.recentViewedSnapshot?.items.first?.coverImageKey, "recent-key")
        XCTAssertEqual(store.trendingSnapshot?.items.first?.coverImageKey, "trending-key")
        XCTAssertEqual(store.reviewPromptSnapshot?.items.first?.coverImageKey, "review-prompt-key")
        XCTAssertEqual(store.myActivitySnapshot?.recentReviews.first?.coverImageKey, "my-activity-key")
    }

    func testRefreshNow_savesSnapshotWhenImagePreparationFails() async {
        let store = SpySnapshotStore()
        let reloader = SpyWidgetTimelineReloader()
        let imagePrefetcher = StubImagePrefetcher(referencesByURL: [:])
        let service = GameWidgetSnapshotRefreshService(
            snapshotStore: store,
            widgetReloader: reloader,
            authTokenProvider: { "token" },
            recentViewedRecordsProvider: { [] },
            trendingGamesProvider: {
                [Self.makeGame(id: 1, title: "One")]
            },
            favoriteEntriesProvider: {
                [Self.makeFavoriteGameEntry(id: 21, title: "Need Review", createdAt: Date())]
            },
            reviewedGamesProvider: { [] },
            profileSummaryProvider: { Self.makeUserProfile() },
            writtenReviewCountProvider: { 6 },
            imagePrefetcher: imagePrefetcher
        )

        await service.refreshNow(reason: "showMainInterface")

        XCTAssertEqual(store.trendingSnapshot?.items.first?.coverImageKey, nil)
        XCTAssertEqual(store.reviewPromptSnapshot?.items.first?.coverImageKey, nil)
        XCTAssertEqual(store.reviewPromptSnapshot?.state, .ready)
        XCTAssertEqual(store.trendingSnapshot?.items.first?.gameID, 1)
    }

    private static func makeFavoriteGameEntry(id: Int, title: String, createdAt: Date?) -> FavoriteGameEntry {
        FavoriteGameEntry(
            favorite: FavoriteItem(gameId: id, createdAt: createdAt),
            game: makeGame(id: id, title: title)
        )
    }

    private static func makeReviewedGame(id: Int, title: String) -> ReviewedGame {
        ReviewedGame(
            reviewId: "review-\(id)",
            gameId: id,
            rating: 4.5,
            content: "content",
            createdAt: "2026-04-08T00:00:00Z",
            game: makeGame(id: id, title: title)
        )
    }

    private static func makeGame(id: Int, title: String) -> Game {
        Game(
            id: id,
            title: title,
            translatedTitle: nil,
            summary: "summary",
            translatedSummary: nil,
            genre: "RPG",
            category: "RPG",
            developer: "Studio",
            platform: "iOS",
            releaseDate: nil,
            releaseYear: 2026,
            coverImageURL: URL(string: "https://example.com/\(id).jpg"),
            rating: 4.7,
            reviewCount: 42,
            popularity: 99,
            isTrending: true,
            formattedRating: "4.7",
            formattedReviewCount: "42"
        )
    }

    private static func makeUserProfile(
        reviewCount: Int = 12,
        wishlistCount: Int = 8,
        likeCount: Int = 34
    ) -> UserProfile {
        UserProfile(
            id: 1,
            email: "user@example.com",
            name: "Tester",
            handle: "@tester",
            avatarURL: nil,
            badgeTitle: nil,
            translatedBadgeTitle: nil,
            selectedTitle: nil,
            selectedTitles: [],
            explicitSelected: nil,
            availableTitles: [],
            profileTags: [],
            friendCount: 0,
            likeCount: likeCount,
            playedGameCount: 0,
            writtenReviewCount: reviewCount,
            wishlistCount: wishlistCount,
            recentPlayedPreview: [],
            hasMoreRecentPlayed: false,
            recentPlayedCount: 0,
            recentPlayedSource: nil
        )
    }
}

private final class SpySnapshotStore: GameWidgetSnapshotStoring {
    var recentViewedSnapshot: RecentViewedWidgetSnapshot?
    var trendingSnapshot: TrendingGamesWidgetSnapshot?
    var myActivitySnapshot: MyActivityWidgetSnapshot?
    var reviewPromptSnapshot: ReviewPromptWidgetSnapshot?
    var recentViewedRecords: [RecentViewedGameRecord] = []

    func saveRecentViewed(_ snapshot: RecentViewedWidgetSnapshot) {
        recentViewedSnapshot = snapshot
    }

    func loadRecentViewed() -> RecentViewedWidgetSnapshot? {
        recentViewedSnapshot
    }

    func saveTrendingGames(_ snapshot: TrendingGamesWidgetSnapshot) {
        trendingSnapshot = snapshot
    }

    func loadTrendingGames() -> TrendingGamesWidgetSnapshot? {
        trendingSnapshot
    }

    func saveMyActivity(_ snapshot: MyActivityWidgetSnapshot) {
        myActivitySnapshot = snapshot
    }

    func loadMyActivity() -> MyActivityWidgetSnapshot? {
        myActivitySnapshot
    }

    func saveReviewPrompt(_ snapshot: ReviewPromptWidgetSnapshot) {
        reviewPromptSnapshot = snapshot
    }

    func loadReviewPrompt() -> ReviewPromptWidgetSnapshot? {
        reviewPromptSnapshot
    }

    func saveRecentViewedRecords(_ records: [RecentViewedGameRecord]) {
        recentViewedRecords = records
    }

    func loadRecentViewedRecords() -> [RecentViewedGameRecord] {
        recentViewedRecords
    }
}

private final class SpyWidgetTimelineReloader: WidgetTimelineReloading {
    private(set) var reloadedKinds: [String] = []

    func reloadTimelines(ofKind kind: String) {
        reloadedKinds.append(kind)
    }
}

private final class StubImagePrefetcher: GameWidgetImagePreparing {
    private let referencesByURL: [String: String]
    private(set) var pruneCalls: [Set<String>] = []

    init(referencesByURL: [String: String]) {
        self.referencesByURL = referencesByURL
    }

    func prepareImageReference(for remoteURL: URL?) async -> String? {
        guard let remoteURL else { return nil }
        return referencesByURL[remoteURL.absoluteString]
    }

    func pruneUnusedImages(keeping keys: Set<String>) {
        pruneCalls.append(keys)
    }
}
