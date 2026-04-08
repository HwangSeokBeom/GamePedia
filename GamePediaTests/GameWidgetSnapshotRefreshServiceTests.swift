import XCTest
@testable import GamePedia

final class GameWidgetSnapshotRefreshServiceTests: XCTestCase {

    func testRefreshNow_savesTrendingSnapshotWithTopThreeItems() async {
        let store = SpySnapshotStore()
        let reloader = SpyWidgetTimelineReloader()
        let service = GameWidgetSnapshotRefreshService(
            snapshotStore: store,
            widgetReloader: reloader,
            authTokenProvider: { nil },
            trendingGamesProvider: {
                [
                    Self.makeGame(id: 1, title: "One"),
                    Self.makeGame(id: 2, title: "Two"),
                    Self.makeGame(id: 3, title: "Three"),
                    Self.makeGame(id: 4, title: "Four")
                ]
            },
            favoriteEntriesProvider: { [] },
            reviewedGamesProvider: { [] }
        )

        await service.refreshNow(reason: "test")

        XCTAssertEqual(store.trendingSnapshot?.items.map(\.gameID), [1, 2, 3])
        XCTAssertEqual(store.trendingSnapshot?.items.map(\.rank), [1, 2, 3])
        XCTAssertEqual(reloader.reloadedKinds.contains(GameWidgetKind.trendingGames), true)
    }

    func testRefreshNow_savesLoggedOutReviewPromptWhenAuthTokenMissing() async {
        let store = SpySnapshotStore()
        let reloader = SpyWidgetTimelineReloader()
        let service = GameWidgetSnapshotRefreshService(
            snapshotStore: store,
            widgetReloader: reloader,
            authTokenProvider: { nil },
            trendingGamesProvider: { [] },
            favoriteEntriesProvider: { XCTFail("favorites should not be fetched for logged-out state"); return [] },
            reviewedGamesProvider: { XCTFail("reviews should not be fetched for logged-out state"); return [] }
        )

        await service.refreshNow(reason: "loggedOut")

        XCTAssertEqual(store.reviewPromptSnapshot?.state, .loggedOut)
        XCTAssertEqual(store.reviewPromptSnapshot?.targetURL, WidgetDeepLink.login.url)
        XCTAssertEqual(reloader.reloadedKinds.contains(GameWidgetKind.reviewPrompt), true)
    }

    func testRefreshNow_savesEmptyReviewPromptWhenNoEligibleFavoriteExists() async {
        let store = SpySnapshotStore()
        let reloader = SpyWidgetTimelineReloader()
        let service = GameWidgetSnapshotRefreshService(
            snapshotStore: store,
            widgetReloader: reloader,
            authTokenProvider: { "token" },
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
            }
        )

        await service.refreshNow(reason: "empty")

        XCTAssertEqual(store.reviewPromptSnapshot?.state, .empty)
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
            }
        )

        await service.refreshNow(reason: "ready")

        XCTAssertEqual(store.reviewPromptSnapshot?.state, .ready)
        XCTAssertEqual(store.reviewPromptSnapshot?.item?.gameID, 21)
        XCTAssertEqual(store.reviewPromptSnapshot?.headlineText, "Need Review")
        XCTAssertEqual(store.reviewPromptSnapshot?.targetURL, WidgetDeepLink.reviewNew(21).url)
        XCTAssertEqual(reloader.reloadedKinds.contains(GameWidgetKind.reviewPrompt), true)
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
}

private final class SpySnapshotStore: GameWidgetSnapshotStoring {
    var trendingSnapshot: TrendingGamesWidgetSnapshot?
    var reviewPromptSnapshot: ReviewPromptWidgetSnapshot?

    func saveTrendingGames(_ snapshot: TrendingGamesWidgetSnapshot) {
        trendingSnapshot = snapshot
    }

    func loadTrendingGames() -> TrendingGamesWidgetSnapshot? {
        trendingSnapshot
    }

    func saveReviewPrompt(_ snapshot: ReviewPromptWidgetSnapshot) {
        reviewPromptSnapshot = snapshot
    }

    func loadReviewPrompt() -> ReviewPromptWidgetSnapshot? {
        reviewPromptSnapshot
    }
}

private final class SpyWidgetTimelineReloader: WidgetTimelineReloading {
    private(set) var reloadedKinds: [String] = []

    func reloadTimelines(ofKind kind: String) {
        reloadedKinds.append(kind)
    }
}
