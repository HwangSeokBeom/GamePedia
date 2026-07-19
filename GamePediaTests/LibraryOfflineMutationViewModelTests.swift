import XCTest
@testable import GamePedia

// MARK: - View-model integration with the offline-first mutation router
//
// These tests exercise the feature-side contract: optimistic state applies
// immediately on accept, permanent-failure notifications revert it, the
// pending banner reflects queue signals, and a nil router (kill-switch off)
// preserves the pre-2.2 direct REST path.

final class LibraryOfflineMutationViewModelTests: XCTestCase {

    private final class MockFavoriteRepository: FavoriteRepository, @unchecked Sendable {
        private let lock = NSLock()
        private(set) var addedGameIDs: [String] = []
        private(set) var removedGameIDs: [String] = []

        func addFavorite(gameId: String) async throws -> FavoriteMutationResult {
            lock.lock()
            addedGameIDs.append(gameId)
            lock.unlock()
            return FavoriteMutationResult(gameId: Int(gameId) ?? -1, isFavorite: true)
        }

        func removeFavorite(gameId: String) async throws -> FavoriteMutationResult {
            lock.lock()
            removedGameIDs.append(gameId)
            lock.unlock()
            return FavoriteMutationResult(gameId: Int(gameId) ?? -1, isFavorite: false)
        }

        func fetchMyFavorites(sort: FavoriteSortOption?) async throws -> [FavoriteItem] { [] }

        func fetchFavoriteStatus(gameId: String) async throws -> FavoriteStatus {
            FavoriteStatus(isFavorite: false)
        }
    }

    // MARK: HomeGameListViewModel — optimistic accept through the router

    func testHomeGameListAppliesOptimisticStateAndRoutesThroughSyncRouter() {
        let router = MockLibraryMutationRouter()
        let viewModel = HomeGameListViewModel(
            section: .popular,
            games: [],
            wishlistedGameIDs: [1],
            librarySync: router
        )

        let enqueued = expectation(description: "router received the favorite change")
        router.onEnqueue = { enqueued.fulfill() }

        viewModel.send(.didTapFavorite(gameId: 1))

        // Optimistic: the wishlist entry flips synchronously on accept.
        XCTAssertFalse(viewModel.state.wishlistedGameIDs.contains(1))

        wait(for: [enqueued], timeout: 10)
        XCTAssertEqual(router.favoriteChanges.count, 1)
        XCTAssertEqual(router.favoriteChanges[0].gameID, "1")
        XCTAssertFalse(router.favoriteChanges[0].isFavorite)
    }

    func testHomeGameListRevertsOptimisticStateOnPermanentSyncFailure() {
        let router = MockLibraryMutationRouter()
        let viewModel = HomeGameListViewModel(
            section: .popular,
            games: [],
            wishlistedGameIDs: [],
            librarySync: router
        )

        let enqueued = expectation(description: "router received the favorite change")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.didTapFavorite(gameId: 55))
        XCTAssertTrue(viewModel.state.wishlistedGameIDs.contains(55))
        wait(for: [enqueued], timeout: 10)

        let reverted = expectation(description: "optimistic state reverted")
        viewModel.onStateChanged = { state in
            if !state.wishlistedGameIDs.contains(55) {
                reverted.fulfill()
            }
        }
        NotificationCenter.default.post(
            name: .librarySyncOperationDidFail,
            object: nil,
            userInfo: [
                LibrarySyncFailureUserInfoKey.entityKind: LibrarySyncEntityKind.favorite.rawValue,
                LibrarySyncFailureUserInfoKey.gameID: "55",
                LibrarySyncFailureUserInfoKey.errorCode: "INVALID_GAME_ID",
                LibrarySyncFailureUserInfoKey.operationID: UUID().uuidString,
                LibrarySyncFailureUserInfoKey.intendedIsFavorite: true,
                LibrarySyncFailureUserInfoKey.supersededByNewerIntent: false
            ]
        )
        wait(for: [reverted], timeout: 10)
    }

    // MARK: Kill-switch off — direct REST path preserved

    func testHomeGameListWithNilRouterUsesTheDirectUseCasePath() {
        let repository = MockFavoriteRepository()
        let viewModel = HomeGameListViewModel(
            section: .popular,
            games: [],
            wishlistedGameIDs: [],
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: repository),
            librarySync: nil
        )

        let posted = XCTNSNotificationExpectation(
            name: .favoriteDidChange,
            object: nil,
            notificationCenter: .default
        )
        posted.handler = { notification in
            notification.userInfo?[FavoriteChangeUserInfoKey.gameId] as? Int == 77
        }
        viewModel.send(.didTapFavorite(gameId: 77))
        wait(for: [posted], timeout: 10)

        XCTAssertEqual(repository.addedGameIDs, ["77"])
    }

    func testHomeGameListFallsBackToDirectPathWhenEnqueueIsRejected() {
        let repository = MockFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .serviceUnavailable
        let viewModel = HomeGameListViewModel(
            section: .popular,
            games: [],
            wishlistedGameIDs: [],
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: repository),
            librarySync: router
        )

        let posted = XCTNSNotificationExpectation(
            name: .favoriteDidChange,
            object: nil,
            notificationCenter: .default
        )
        posted.handler = { notification in
            notification.userInfo?[FavoriteChangeUserInfoKey.gameId] as? Int == 88
        }
        viewModel.send(.didTapFavorite(gameId: 88))
        wait(for: [posted], timeout: 10)

        XCTAssertEqual(router.favoriteChanges.count, 1)
        XCTAssertEqual(repository.addedGameIDs, ["88"], "a rejected enqueue must fall back to the direct call")
    }

    // MARK: HomeViewModel — optimistic accept and failure revert

    func testHomeViewModelAppliesOptimisticWishlistChangeAndRevertsOnFailure() {
        let router = MockLibraryMutationRouter()
        let viewModel = HomeViewModel(librarySync: router)

        let enqueued = expectation(description: "router received the favorite change")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.didTapFavorite(gameId: 900_001))
        XCTAssertTrue(viewModel.state.wishlistedGameIDs.contains(900_001))
        wait(for: [enqueued], timeout: 10)
        XCTAssertEqual(router.favoriteChanges.count, 1)
        XCTAssertEqual(router.favoriteChanges[0].gameID, "900001")
        XCTAssertTrue(router.favoriteChanges[0].isFavorite)

        let reverted = expectation(description: "wishlist reverted and error surfaced")
        viewModel.onStateChanged = { state in
            if !state.wishlistedGameIDs.contains(900_001), state.errorMessage != nil {
                reverted.fulfill()
            }
        }
        NotificationCenter.default.post(
            name: .librarySyncOperationDidFail,
            object: nil,
            userInfo: [
                LibrarySyncFailureUserInfoKey.entityKind: LibrarySyncEntityKind.favorite.rawValue,
                LibrarySyncFailureUserInfoKey.gameID: "900001",
                LibrarySyncFailureUserInfoKey.errorCode: "INVALID_GAME_ID",
                LibrarySyncFailureUserInfoKey.operationID: UUID().uuidString,
                LibrarySyncFailureUserInfoKey.intendedIsFavorite: true,
                LibrarySyncFailureUserInfoKey.supersededByNewerIntent: false
            ]
        )
        wait(for: [reverted], timeout: 10)
    }

    // MARK: LibraryViewModel — pending banner and manual retry

    func testLibraryViewModelReflectsQueueSignalsInPendingBannerState() {
        let router = MockLibraryMutationRouter()
        let viewModel = LibraryViewModel(librarySync: router)

        let updated = expectation(description: "banner state updated")
        viewModel.onStateChanged = { state in
            if state.pendingSyncCount == 3, state.parkedSyncCount == 1 {
                updated.fulfill()
            }
        }
        NotificationCenter.default.post(
            name: .librarySyncQueueDidChange,
            object: nil,
            userInfo: [
                LibrarySyncQueueUserInfoKey.pendingCount: 3,
                LibrarySyncQueueUserInfoKey.parkedCount: 1
            ]
        )
        wait(for: [updated], timeout: 10)
    }

    func testLibraryViewModelRetryIntentInvokesTheRouter() {
        let router = MockLibraryMutationRouter()
        let viewModel = LibraryViewModel(librarySync: router)

        let retried = expectation(description: "router retryNow invoked")
        router.onRetryNow = { retried.fulfill() }
        viewModel.send(.retryLibrarySyncTapped)
        wait(for: [retried], timeout: 10)
        XCTAssertEqual(router.retryNowCallCount, 1)
    }
}
