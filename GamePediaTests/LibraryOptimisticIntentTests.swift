import XCTest
import Combine
@testable import GamePedia

// M2 — optimistic failure intent generation.
//
// A permanent failure notification carries the failed operation's id, its
// intended state, and whether a newer queued intent supersedes it. Failure
// observers reconcile against the intended state (never by inverting
// whatever is currently on screen) and ignore superseded failures entirely.
// Late failures from a superseded session post nothing.
final class LibraryOptimisticIntentTests: XCTestCase {

    private var store: InMemorySyncOperationStore!
    private var transport: MockLibrarySyncTransport!
    private var center: NotificationCenter!

    override func setUp() {
        super.setUp()
        store = InMemorySyncOperationStore()
        transport = MockLibrarySyncTransport()
        center = NotificationCenter()
    }

    // MARK: - Engine notification payload

    func testPermanentFailureCarriesIntentAndOperationIdentity() async {
        transport.behavior = { _, _ in .failure(FavoriteError.validationFailed(message: "invalid")) }
        let engine = makeSyncEngine(store: store, transport: transport, notificationCenter: center)
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        var received: Notification?
        let failed = notificationExpectation(.librarySyncOperationDidFail, center: center) { notification in
            received = notification
            return true
        }
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [failed], timeout: 10)

        let userInfo = received?.userInfo
        XCTAssertEqual(userInfo?[LibrarySyncFailureUserInfoKey.intendedIsFavorite] as? Bool, true)
        XCTAssertEqual(userInfo?[LibrarySyncFailureUserInfoKey.supersededByNewerIntent] as? Bool, false)
        XCTAssertNotNil(
            UUID(uuidString: userInfo?[LibrarySyncFailureUserInfoKey.operationID] as? String ?? "")
        )
    }

    func testFailureBehindANewerQueuedIntentIsMarkedSuperseded() async {
        // Op 1 (favorite=true) is held in flight; a newer intent
        // (favorite=false) queues behind it; then op 1 fails permanently.
        transport.behavior = { _, index in index == 0 ? .hold : .success(nil) }
        let engine = makeSyncEngine(store: store, transport: transport, notificationCenter: center)
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        let firstCall = expectation(description: "first transport call")
        transport.onCall = { call in
            if call.index == 0 { firstCall.fulfill() }
        }
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [firstCall], timeout: 10)
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: false)

        var received: Notification?
        let failed = notificationExpectation(.librarySyncOperationDidFail, center: center) { notification in
            received = notification
            return true
        }
        transport.resolveHeld(index: 0, with: .failure(FavoriteError.validationFailed(message: "invalid")))
        await fulfillment(of: [failed], timeout: 10)

        XCTAssertEqual(
            received?.userInfo?[LibrarySyncFailureUserInfoKey.supersededByNewerIntent] as? Bool, true,
            "the newest intent still governs; observers must ignore this failure"
        )
    }

    func testFailureAfterAccountSwitchPostsNothing() async {
        transport.behavior = { _, index in index == 0 ? .hold : .success(nil) }
        let engine = makeSyncEngine(store: store, transport: transport, notificationCenter: center)
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        let firstCall = expectation(description: "first transport call")
        transport.onCall = { call in
            if call.index == 0 { firstCall.fulfill() }
        }
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [firstCall], timeout: 10)

        let recorder = NotificationRecorder(center: center, names: [.librarySyncOperationDidFail])
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-b")
        transport.resolveHeld(index: 0, with: .failure(FavoriteError.validationFailed(message: "invalid")))

        // Deterministic settle: another operation for B completes fully.
        let settled = notificationExpectation(.favoriteDidChange, center: center)
        _ = await engine.enqueueFavoriteChange(gameID: "9", isFavorite: true)
        await fulfillment(of: [settled], timeout: 10)

        XCTAssertEqual(
            recorder.count(of: .librarySyncOperationDidFail), 0,
            "a failure from a superseded session must be inert"
        )
    }

    func testRestartReconstructsPendingIntentFromDurableQueue() async {
        transport.behavior = { _, _ in .hold }
        let engine = makeSyncEngine(store: store, transport: transport, notificationCenter: center)
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)

        // "Restart": a fresh engine over the same durable store.
        let restarted = makeSyncEngine(store: store, transport: transport, notificationCenter: center)
        await restarted.sessionDidChange(isAuthenticated: true, userID: "user-a")
        let intent = await restarted.pendingFavoriteIntent(gameID: "42")
        XCTAssertEqual(intent, true, "the durable queue reconstructs the optimistic intent")
    }

    // MARK: - View-model reconciliation

    @MainActor
    private func makeHomeGameListViewModel(wishlisted: Set<Int>) -> HomeGameListViewModel {
        HomeGameListViewModel(
            section: .popular,
            games: [],
            wishlistedGameIDs: wishlisted,
            librarySync: MockLibraryMutationRouter()
        )
    }

    private func postFavoriteFailure(
        gameID: String,
        intended: Bool?,
        superseded: Bool,
        center: NotificationCenter = .default
    ) {
        var userInfo: [String: Any] = [
            LibrarySyncFailureUserInfoKey.entityKind: LibrarySyncEntityKind.favorite.rawValue,
            LibrarySyncFailureUserInfoKey.gameID: gameID,
            LibrarySyncFailureUserInfoKey.errorCode: "VALIDATION_ERROR",
            LibrarySyncFailureUserInfoKey.operationID: UUID().uuidString,
            LibrarySyncFailureUserInfoKey.supersededByNewerIntent: superseded
        ]
        if let intended {
            userInfo[LibrarySyncFailureUserInfoKey.intendedIsFavorite] = intended
        }
        center.post(name: .librarySyncOperationDidFail, object: nil, userInfo: userInfo)
    }

    @MainActor
    private func waitForMainQueueTurn() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    @MainActor
    func testHomeGameListRevertsToPreIntentStateInsteadOfInvertingCurrent() async {
        // The add intent failed, but the game is NOT currently marked (the
        // reverted-state race the old blind inversion got wrong: it would
        // have ADDED the game). Reconciling against the intent leaves it
        // removed.
        let viewModel = makeHomeGameListViewModel(wishlisted: [])
        postFavoriteFailure(gameID: "42", intended: true, superseded: false)
        await waitForMainQueueTurn()
        XCTAssertFalse(viewModel.state.wishlistedGameIDs.contains(42))

        // And a failed add over a currently-marked state clears it.
        let marked = makeHomeGameListViewModel(wishlisted: [42])
        postFavoriteFailure(gameID: "42", intended: true, superseded: false)
        await waitForMainQueueTurn()
        XCTAssertFalse(marked.state.wishlistedGameIDs.contains(42))

        // A failed remove restores the mark regardless of current state.
        let unmarked = makeHomeGameListViewModel(wishlisted: [])
        postFavoriteFailure(gameID: "42", intended: false, superseded: false)
        await waitForMainQueueTurn()
        XCTAssertTrue(unmarked.state.wishlistedGameIDs.contains(42))
    }

    @MainActor
    func testSupersededFailuresLeaveOptimisticStateUntouched() async {
        let viewModel = makeHomeGameListViewModel(wishlisted: [42])
        postFavoriteFailure(gameID: "42", intended: true, superseded: true)
        await waitForMainQueueTurn()
        XCTAssertTrue(
            viewModel.state.wishlistedGameIDs.contains(42),
            "a superseded failure must not touch the newest optimistic state"
        )
    }

    @MainActor
    func testOutOfOrderFailuresAfterThreeRapidTogglesConvergeOnIntent() async {
        // Toggles: add (op1), remove (op2), add (op3). Failures arrive out
        // of order: op1 (superseded), op3 (newest, not superseded, intended
        // add). The final state must be the pre-op3 state (removed) — never
        // an inversion of whatever happened to be on screen.
        let viewModel = makeHomeGameListViewModel(wishlisted: [42])
        postFavoriteFailure(gameID: "42", intended: true, superseded: true)
        await waitForMainQueueTurn()
        XCTAssertTrue(viewModel.state.wishlistedGameIDs.contains(42))

        postFavoriteFailure(gameID: "42", intended: true, superseded: false)
        await waitForMainQueueTurn()
        XCTAssertFalse(viewModel.state.wishlistedGameIDs.contains(42))

        // A late duplicate-style failure for the already-reverted add keeps
        // the state stable instead of flip-flopping.
        postFavoriteFailure(gameID: "42", intended: true, superseded: false)
        await waitForMainQueueTurn()
        XCTAssertFalse(viewModel.state.wishlistedGameIDs.contains(42))
    }

    @MainActor
    func testHomeViewModelIgnoresSupersededAndReconcilesAgainstIntent() async {
        let router = MockLibraryMutationRouter()
        let viewModel = HomeViewModel(librarySync: router)
        // Optimistic add through the normal intent path.
        let enqueued = expectation(description: "router received the change")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.didTapFavorite(gameId: 7))
        await fulfillment(of: [enqueued], timeout: 10)
        XCTAssertTrue(viewModel.state.wishlistedGameIDs.contains(7))

        postFavoriteFailure(gameID: "7", intended: true, superseded: true)
        await waitForMainQueueTurn()
        XCTAssertTrue(
            viewModel.state.wishlistedGameIDs.contains(7),
            "a superseded failure must not touch the newest optimistic state"
        )

        postFavoriteFailure(gameID: "7", intended: true, superseded: false)
        await waitForMainQueueTurn()
        XCTAssertFalse(viewModel.state.wishlistedGameIDs.contains(7))

        // A payload without an intent never mutates the wishlist.
        postFavoriteFailure(gameID: "7", intended: nil, superseded: false)
        await waitForMainQueueTurn()
        XCTAssertFalse(viewModel.state.wishlistedGameIDs.contains(7))
    }
}
