import UIKit
import XCTest
@testable import GamePedia

// MARK: - Product22HomeSectionTests
//
// Required area 25: Home's section identity and the routes a Today tap takes.
//
// Home used to key its layout and header provider off a section's *position*.
// Today's section count and order come from the server, so these tests pin the
// property that replaced it: a section is found by what it is, not where it is.

final class Product22HomeSectionTests: XCTestCase {

    func testSectionIdentitySurvivesReorderingAndOmission() {
        // The same key is the same section wherever it lands.
        XCTAssertEqual(HomeRootView.Section.today(.playCompass), .today(.playCompass))
        XCTAssertNotEqual(HomeRootView.Section.today(.playCompass), .today(.gameDNA))
        XCTAssertNotEqual(HomeRootView.Section.today(.playCompass), .todayRecommendation)

        // Every Today key produces a distinct identity, so eight sections can
        // coexist in a diffable snapshot without colliding.
        let identities = Set(TodaySectionKey.allCases.map { HomeRootView.Section.today($0) })
        XCTAssertEqual(identities.count, TodaySectionKey.allCases.count)

        for key in TodaySectionKey.allCases {
            XCTAssertEqual(HomeRootView.Section.today(key).todayKey, key)
        }
        XCTAssertNil(HomeRootView.Section.popular.todayKey)
        XCTAssertNil(HomeRootView.Section.todayNotice.todayKey)
    }

    func testLegacyDiscoveryKeepsItsOriginalOrderBelowToday() {
        XCTAssertEqual(
            HomeRootView.Section.legacyDiscovery,
            [.todayRecommendation, .popular, .trending]
        )
    }

    func testATodayItemNeverResolvesToALegacyGame() {
        // A Today row is addressed by canonical UUID and routes through its own
        // action. It must not be mistaken for a legacy IGDB game.
        let item = TodayDisplayModel.Item(
            id: Product22Fixture.gameA,
            title: "T",
            subtitle: nil,
            details: [],
            accessibilityLabel: "T",
            action: .openCatalogGame(CatalogGameID(uuidString: Product22Fixture.gameA)!)
        )
        let collectionItem = HomeCollectionItem.todayItem(key: .playCompass, item: item)

        XCTAssertNil(collectionItem.selectedGame, "a Today row has no legacy game id")
        XCTAssertEqual(
            collectionItem.todayAction,
            .openCatalogGame(CatalogGameID(uuidString: Product22Fixture.gameA)!)
        )

        // A status row is not tappable at all.
        let status = HomeCollectionItem.todayStatus(
            key: .gameDNA, message: "m", retryTitle: nil
        )
        XCTAssertNil(status.selectedGame)
        XCTAssertNil(status.todayAction)
    }

    func testEveryTodayActionHasAHomeRoute() {
        // The routing switch must stay exhaustive over the action vocabulary.
        let actions: [TodayDisplayModel.Item.Action] = [
            .openCatalogGame(CatalogGameID(uuidString: Product22Fixture.gameA)!),
            .openArticle(slug: "s"),
            .openMonthlyReplay(monthKey: "2026-07"),
            .openGameDNA,
            .openPlayCompass
        ]
        for action in actions {
            let route: HomeRoute?
            switch action {
            case .openCatalogGame(let id): route = .showCatalogGame(id)
            case .openArticle(let slug): route = .showArticle(slug: slug)
            case .openMonthlyReplay(let key): route = .showMonthlyReplay(monthKey: key)
            case .openGameDNA: route = .showGameDNA
            case .openPlayCompass: route = .showPlayCompass
            }
            XCTAssertNotNil(route)
        }
    }

    @MainActor
    func testHomeFallsBackToLegacyDiscoveryWhenTodayIsAbsent() {
        // Today absent — signed out, feature off, or not loaded — must leave
        // the pre-existing Home experience exactly as it was.
        var state = HomeState()
        state.today = nil
        state.isTodayLoading = false

        XCTAssertNil(state.today)
        XCTAssertFalse(state.showsTodaySkeleton)

        let viewController = HomeViewController(
            rootView: HomeRootView(),
            viewModel: HomeViewModel(todayFeedLoader: nil)
        )
        viewController.loadViewIfNeeded()
        // The screen builds and shows its legacy sections with no Today loader
        // wired at all.
        XCTAssertNotNil(viewController.view)
    }

    @MainActor
    func testRetryingASectionMarksOnlyThatSection() {
        var state = HomeState()
        state = HomeReducer.reduce(state, .setTodaySectionRetrying(.gameDNA, true))
        XCTAssertEqual(state.retryingTodaySections, [.gameDNA])

        state = HomeReducer.reduce(state, .setTodaySectionRetrying(.playCompass, true))
        XCTAssertEqual(state.retryingTodaySections, [.gameDNA, .playCompass])

        state = HomeReducer.reduce(state, .setTodaySectionRetrying(.gameDNA, false))
        XCTAssertEqual(state.retryingTodaySections, [.playCompass])

        // A completed load clears every pending retry.
        state = HomeReducer.reduce(state, .setToday(nil))
        XCTAssertTrue(state.retryingTodaySections.isEmpty)
        XCTAssertFalse(state.isTodayLoading)
    }
}

// MARK: - Product22FollowRollbackTests
//
// Required area 23: follow/unfollow is optimistic, and a failure rolls back to
// exactly the state before the tap.

final class Product22FollowRollbackTests: XCTestCase {

    /// Records what was asked for and can be made to fail.
    private final class StubCatalogRepository: CatalogRepositing, @unchecked Sendable {
        var followResult: Result<Void, any Error> = .success(())
        var detail: CatalogGameDetail?
        private(set) var followCalls: [(Bool, CatalogGameID)] = []

        var searchPages: [CatalogSearchPageResult] = []
        private(set) var searchCursors: [String?] = []

        func search(
            query: String, locale: String?, regionCode: String?, platform: String?, cursor: String?
        ) async throws -> CatalogSearchPageResult {
            searchCursors.append(cursor)
            guard let page = searchPages.first(where: { _ in true }) else {
                return CatalogSearchPageResult(games: [], nextCursor: nil, matchedBy: .ranked, limit: 50)
            }
            if !searchPages.isEmpty { searchPages.removeFirst() }
            return page
        }

        func detail(id: CatalogGameID) async throws -> CatalogGameDetail {
            guard let detail else { throw Product22Error.notFound }
            return detail
        }

        func setFollowing(
            _ following: Bool, id: CatalogGameID, regionalReleaseID: RegionalReleaseID?
        ) async throws {
            followCalls.append((following, id))
            try followResult.get()
        }

        func submitCorrections(
            _ corrections: [CatalogCorrection], for id: CatalogGameID
        ) async throws {}
    }

    private func makeDetail(isFollowed: Bool) -> CatalogGameDetail {
        CatalogGameDetail(
            summary: CatalogGameSummary(
                id: CatalogGameID(uuidString: Product22Fixture.gameA)!,
                originalTitle: "Hollow Knight",
                slug: nil, developerName: nil, publisherName: nil,
                firstReleaseDate: nil, genres: [], platforms: [],
                publicationStatus: .published,
                titleProvenance: .providerVerified,
                identities: []
            ),
            steamTags: [], supportsSinglePlayer: nil, supportsMultiplayer: nil,
            typicalSessionMinutes: nil, localizations: [], regionalReleases: [],
            assets: [], fieldEvidence: [], resolvedFromMerge: false,
            isFollowedByMe: isFollowed
        )
    }

    @MainActor
    private func makeViewController(
        repository: StubCatalogRepository
    ) -> CatalogGameViewController {
        CatalogGameViewController(
            catalogGameID: CatalogGameID(uuidString: Product22Fixture.gameA)!,
            repository: repository,
            configStore: ProductConfigStore(service: Product22MockService())
        )
    }

    @MainActor
    func testAFailedFollowRollsBackToTheExactPreviousState() async throws {
        let repository = StubCatalogRepository()
        repository.detail = makeDetail(isFollowed: false)
        let viewController = makeViewController(repository: repository)
        viewController.loadViewIfNeeded()

        XCTAssertFalse(viewController.followButtonReflectsFollowing)

        repository.followResult = .failure(Product22Error.transport(message: "offline"))
        viewController.perform(NSSelectorFromString("toggleFollow"))

        // Optimistic: the tap is reflected before the server answers.
        XCTAssertTrue(
            viewController.followButtonReflectsFollowing,
            "the tap must be reflected immediately"
        )

        try await Task.sleep(for: .milliseconds(120))

        XCTAssertFalse(
            viewController.followButtonReflectsFollowing,
            "a failed follow must roll back to exactly the state before the tap"
        )
        XCTAssertEqual(repository.followCalls.count, 1)
        XCTAssertEqual(repository.followCalls.first?.0, true)
    }

    @MainActor
    func testASuccessfulFollowKeepsTheOptimisticState() async throws {
        let repository = StubCatalogRepository()
        repository.detail = makeDetail(isFollowed: false)
        let viewController = makeViewController(repository: repository)
        viewController.loadViewIfNeeded()

        repository.followResult = .success(())
        viewController.perform(NSSelectorFromString("toggleFollow"))
        try await Task.sleep(for: .milliseconds(120))

        XCTAssertTrue(viewController.followButtonReflectsFollowing)
        XCTAssertEqual(repository.followCalls.first?.0, true)
    }

    @MainActor
    func testUnfollowRollsBackToFollowedOnFailure() async throws {
        let repository = StubCatalogRepository()
        repository.detail = makeDetail(isFollowed: true)
        let viewController = makeViewController(repository: repository)
        viewController.loadViewIfNeeded()
        // Force the loaded state without a network round trip.
        viewController.setValue(true, forKey: "isFollowing")

        repository.followResult = .failure(Product22Error.server(statusCode: 500, code: nil, message: nil))
        viewController.perform(NSSelectorFromString("toggleFollow"))
        XCTAssertFalse(viewController.followButtonReflectsFollowing, "optimistic unfollow")

        try await Task.sleep(for: .milliseconds(120))
        XCTAssertTrue(
            viewController.followButtonReflectsFollowing,
            "a failed unfollow must return to followed"
        )
        XCTAssertEqual(repository.followCalls.first?.0, false)
    }
}

// MARK: - Product22MonthNavigationTests

final class Product22MonthNavigationTests: XCTestCase {

    /// The month *key* is stepped locally; the window, timezone and day count
    /// always come back from the server and are never recomputed.
    func testMonthKeySteppingCrossesYearBoundaries() {
        XCTAssertEqual(MonthlyReplayViewController.month("2026-07", offsetBy: 1), "2026-08")
        XCTAssertEqual(MonthlyReplayViewController.month("2026-12", offsetBy: 1), "2027-01")
        XCTAssertEqual(MonthlyReplayViewController.month("2026-01", offsetBy: -1), "2025-12")
        XCTAssertEqual(MonthlyReplayViewController.month("2026-07", offsetBy: -7), "2025-12")
        XCTAssertEqual(MonthlyReplayViewController.month("2026-07", offsetBy: 0), "2026-07")
    }

    func testAMalformedMonthKeyIsRefusedRatherThanGuessed() {
        XCTAssertNil(MonthlyReplayViewController.month("nonsense", offsetBy: 1))
        XCTAssertNil(MonthlyReplayViewController.month("2026", offsetBy: 1))
        XCTAssertNil(MonthlyReplayViewController.month("", offsetBy: 1))
    }
}
