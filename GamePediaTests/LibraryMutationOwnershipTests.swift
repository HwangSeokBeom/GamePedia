import XCTest
@testable import GamePedia

// FINDING 1 — UI intent must never cross account boundaries.
//
// Every UI-originated library/favorite mutation captures an immutable
// ownership context (account, scope id, generation, entity, sequence,
// intended state) synchronously at gesture time. The engine validates that
// context — never the account that happens to be active when enqueue runs —
// and a stale scope returns `.staleOwnership`, which must never route to the
// direct (legacy) network path.
//
// Deterministic throughout: transport calls and store loads park on
// continuations, staleness is produced by explicit session events between
// capture and enqueue, and negative assertions run behind deterministic
// yield drains — no sleeps, no wall-clock synchronization.
final class LibraryMutationOwnershipTests: XCTestCase {

    private var center: NotificationCenter!
    private var transport: MockLibrarySyncTransport!
    private var store: InMemorySyncOperationStore!

    override func setUp() {
        super.setUp()
        center = NotificationCenter()
        transport = MockLibrarySyncTransport()
        store = InMemorySyncOperationStore()
    }

    private func makeEngine() -> LibrarySyncEngine {
        makeSyncEngine(store: store, transport: transport, notificationCenter: center)
    }

    private func makeAuthenticatedEngine(accountID: String = "user-a") async -> LibrarySyncEngine {
        let engine = makeEngine()
        await engine.sessionDidChange(isAuthenticated: true, userID: accountID)
        return engine
    }

    /// Cooperatively drains pending unstructured Tasks and main-queue hops so
    /// negative assertions observe a settled world (never wall-clock based).
    private func drainConcurrentWork() async {
        for _ in 0..<200 {
            await Task.yield()
        }
        await MainActor.run {}
        for _ in 0..<200 {
            await Task.yield()
        }
    }

    // MARK: 1. A-gesture, delayed Task, B login, then enqueue

    func testCaptureUnderAThenBLoginRejectsEnqueueAsStaleOwnership() async throws {
        let engine = await makeAuthenticatedEngine(accountID: "user-a")

        // Gesture happens while A owns the session…
        let ownership = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))
        XCTAssertEqual(ownership.accountID, "user-a")

        // …but B becomes active before the submission Task reaches enqueue.
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-b")

        let result = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: ownership)

        XCTAssertEqual(result, .staleOwnership)
        // 3. The stale A intent never enters B's queue, memory or disk.
        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 0)
        XCTAssertTrue(store.storedOperations(accountID: "user-b").isEmpty)
        XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty)
        XCTAssertTrue(transport.calls.isEmpty, "a stale intent must never reach the network")
    }

    // MARK: 2. Enqueue suspended on the account-load gate, B login, resume

    func testEnqueueSuspendedOnAccountLoadGateGoesStaleWhenBLogsIn() async throws {
        store.holdLoads = true
        let engine = makeEngine()

        let loadStarted = expectation(description: "A load started")
        store.onLoad = { index in
            if index == 0 { loadStarted.fulfill() }
        }
        let loginA = Task { await engine.sessionDidChange(isAuthenticated: true, userID: "user-a") }
        await fulfillment(of: [loadStarted], timeout: 10)

        // Gesture during A's (still loading) session: ownership is A's.
        let ownership = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "7", isFavorite: true))
        XCTAssertEqual(ownership.accountID, "user-a")

        // The submission suspends on the account-load gate.
        let enqueueTask = Task {
            await engine.enqueueFavoriteChange(gameID: "7", isFavorite: true, ownership: ownership)
        }
        await waitForLoadWaiters(engine, count: 1)

        // B logs in while the enqueue is suspended; both loads resolve.
        let loadBStarted = expectation(description: "B load started")
        store.onLoad = { index in
            if index == 1 { loadBStarted.fulfill() }
        }
        let loginB = Task { await engine.sessionDidChange(isAuthenticated: true, userID: "user-b") }
        await fulfillment(of: [loadBStarted], timeout: 10)
        store.resolveHeldLoad(index: 0)
        store.resolveHeldLoad(index: 1)
        await loginA.value
        await loginB.value

        let result = await enqueueTask.value
        XCTAssertEqual(result, .staleOwnership)
        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 0)
        XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty)
        XCTAssertTrue(store.storedOperations(accountID: "user-b").isEmpty)
    }

    // MARK: 6. Logout before submission

    func testLogoutBeforeSubmissionRejectsAsStaleOwnership() async throws {
        let engine = await makeAuthenticatedEngine(accountID: "user-a")
        let ownership = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "5", isFavorite: true))

        await engine.sessionDidChange(isAuthenticated: false, userID: nil)

        let result = await engine.enqueueFavoriteChange(gameID: "5", isFavorite: true, ownership: ownership)
        XCTAssertEqual(result, .staleOwnership)
        XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty)
        XCTAssertTrue(transport.calls.isEmpty)
    }

    // MARK: 7. Account deletion before submission

    func testAccountDeletionBeforeSubmissionRejectsAsStaleOwnership() async throws {
        let engine = await makeAuthenticatedEngine(accountID: "user-a")
        let ownership = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "5", isFavorite: true))

        await engine.accountDidDelete(userID: "user-a")

        let result = await engine.enqueueFavoriteChange(gameID: "5", isFavorite: true, ownership: ownership)
        XCTAssertEqual(result, .staleOwnership)
        XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty)
        XCTAssertTrue(transport.calls.isEmpty)
    }

    // MARK: 8. Same-account credential refresh preserves captured ownership

    func testSameAccountCredentialRefreshKeepsCapturedOwnershipValid() async throws {
        let engine = await makeAuthenticatedEngine(accountID: "user-a")
        let generationBefore = await engine.diagnosticsSnapshot().sessionGeneration
        let ownership = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))

        // Token refresh re-issues the session for the SAME account.
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        XCTAssertTrue(engine.ownershipContext.isCurrent(ownership))
        XCTAssertTrue(engine.isNewestOwnedIntent(ownership))
        let result = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: ownership)
        XCTAssertEqual(result, .accepted)
        let generationAfter = await engine.diagnosticsSnapshot().sessionGeneration
        XCTAssertEqual(generationAfter, generationBefore, "a refresh must not advance the account scope")
    }

    // MARK: 9. A → B → A must not revive an old A generation

    func testReloginAfterAccountSwitchDoesNotReviveOldCapture() async throws {
        let engine = await makeAuthenticatedEngine(accountID: "user-a")
        let oldOwnership = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))

        await engine.sessionDidChange(isAuthenticated: true, userID: "user-b")
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        // A owns the session again, but under a NEW scope: the old capture
        // stays permanently stale.
        XCTAssertFalse(engine.ownershipContext.isCurrent(oldOwnership))
        XCTAssertFalse(engine.isNewestOwnedIntent(oldOwnership))
        let staleResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: oldOwnership)
        XCTAssertEqual(staleResult, .staleOwnership)

        // A fresh gesture under the new A scope is accepted normally.
        let newOwnership = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))
        let freshResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: newOwnership)
        XCTAssertEqual(freshResult, .accepted)
    }

    // MARK: 15. Critical interleaving repeated 50 times

    func testStaleOwnershipInterleavingRepeated50Times() async throws {
        for iteration in 0..<50 {
            center = NotificationCenter()
            transport = MockLibrarySyncTransport()
            store = InMemorySyncOperationStore()
            let engine = await makeAuthenticatedEngine(accountID: "user-a")

            let ownership = try XCTUnwrap(
                engine.captureFavoriteIntent(gameID: "42", isFavorite: iteration.isMultiple(of: 2))
            )
            await engine.sessionDidChange(isAuthenticated: true, userID: "user-b")

            let result = await engine.enqueueFavoriteChange(
                gameID: "42",
                isFavorite: iteration.isMultiple(of: 2),
                ownership: ownership
            )
            XCTAssertEqual(result, .staleOwnership, "iteration \(iteration)")
            let pending = await engine.pendingOperationCount
            XCTAssertEqual(pending, 0, "iteration \(iteration): stale intent entered B's queue")
            XCTAssertTrue(
                store.storedOperations(accountID: "user-b").isEmpty,
                "iteration \(iteration): stale intent reached B's file"
            )
            XCTAssertTrue(
                transport.calls.isEmpty,
                "iteration \(iteration): stale intent reached the network"
            )
        }
    }

    // MARK: - View-model coverage (11–14): capture at gesture, non-accepted
    // enqueue results are terminal (no second transport path), stale
    // refusals stay inert

    private final class RecordingFavoriteRepository: FavoriteRepository, @unchecked Sendable {
        private let lock = NSLock()
        private(set) var addedGameIDs: [String] = []
        private(set) var removedGameIDs: [String] = []
        /// Fired inside the mutation call — the deterministic point "the
        /// request is on the wire" for completion-staleness tests.
        var onMutation: (() -> Void)?

        var mutationCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return addedGameIDs.count + removedGameIDs.count
        }

        func addFavorite(gameId: String, authorization: RequestAuthorization) async throws -> FavoriteMutationResult {
            lock.lock()
            addedGameIDs.append(gameId)
            let callback = onMutation
            lock.unlock()
            callback?()
            return FavoriteMutationResult(gameId: Int(gameId) ?? -1, isFavorite: true)
        }

        func removeFavorite(gameId: String, authorization: RequestAuthorization) async throws -> FavoriteMutationResult {
            lock.lock()
            removedGameIDs.append(gameId)
            let callback = onMutation
            lock.unlock()
            callback?()
            return FavoriteMutationResult(gameId: Int(gameId) ?? -1, isFavorite: false)
        }

        func fetchMyFavorites(sort: FavoriteSortOption?) async throws -> [FavoriteItem] { [] }

        func fetchFavoriteStatus(gameId: String) async throws -> FavoriteStatus {
            FavoriteStatus(isFavorite: false)
        }
    }

    // MARK: 11. HomeViewModel

    func testHomeViewModelCapturesOwnershipAtGestureAndThreadsItThroughEnqueue() async {
        let router = MockLibraryMutationRouter()
        let viewModel = HomeViewModel(librarySync: router)

        let enqueued = expectation(description: "enqueue recorded")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.didTapFavorite(gameId: 42))

        // Ownership was captured synchronously inside the gesture handler.
        XCTAssertEqual(router.capturedOwnerships.count, 1)
        XCTAssertEqual(router.capturedOwnerships[0].entityKey, LibrarySyncEntityKey.favorite(gameID: "42"))
        XCTAssertEqual(router.capturedOwnerships[0].intendedState, .favorite(isFavorite: true))

        await fulfillment(of: [enqueued], timeout: 10)
        XCTAssertEqual(router.enqueuedOwnerships, router.capturedOwnerships, "the enqueue must carry the gesture-time capture")
    }

    func testHomeViewModelStaleOwnershipNeverTriggersDirectFallback() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .staleOwnership
        let viewModel = HomeViewModel(
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: repository),
            librarySync: router
        )

        let enqueued = expectation(description: "enqueue recorded")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.didTapFavorite(gameId: 42))
        await fulfillment(of: [enqueued], timeout: 10)
        await drainConcurrentWork()

        XCTAssertEqual(repository.mutationCount, 0, "staleOwnership must never reach the direct path")
        XCTAssertEqual(router.ownershipRevalidationCount, 0, "the stale intent must be dropped before any fallback step")
    }

    func testHomeViewModelRefusedEnqueueWithStaleScopeNeverTouchesNetworkOrUI() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .serviceUnavailable
        router.ownershipIsCurrent = false
        let viewModel = HomeViewModel(
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: repository),
            librarySync: router
        )

        let revalidated = expectation(description: "ownership revalidated")
        router.onOwnershipRevalidation = { revalidated.fulfill() }
        viewModel.send(.didTapFavorite(gameId: 42))
        let optimisticIDs = viewModel.state.wishlistedGameIDs
        await fulfillment(of: [revalidated], timeout: 10)
        await drainConcurrentWork()

        XCTAssertGreaterThanOrEqual(router.ownershipRevalidationCount, 1)
        XCTAssertEqual(repository.mutationCount, 0, "a refused enqueue must never construct a network request")
        XCTAssertEqual(
            viewModel.state.wishlistedGameIDs, optimisticIDs,
            "a stale scope's refusal must not rewrite the current account's UI"
        )
        XCTAssertNil(viewModel.state.errorMessage, "a stale scope's refusal must not surface into the new context")
    }

    // MARK: 12. HomeGameListViewModel

    func testHomeGameListCapturesOwnershipAtGestureAndThreadsItThroughEnqueue() async {
        let router = MockLibraryMutationRouter()
        let viewModel = HomeGameListViewModel(
            section: .popular,
            games: [],
            wishlistedGameIDs: [],
            librarySync: router
        )

        let enqueued = expectation(description: "enqueue recorded")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.didTapFavorite(gameId: 7))

        XCTAssertEqual(router.capturedOwnerships.count, 1)
        XCTAssertEqual(router.capturedOwnerships[0].entityKey, LibrarySyncEntityKey.favorite(gameID: "7"))
        XCTAssertEqual(router.capturedOwnerships[0].sequence, 1)

        await fulfillment(of: [enqueued], timeout: 10)
        XCTAssertEqual(router.enqueuedOwnerships, router.capturedOwnerships)
    }

    func testHomeGameListStaleOwnershipNeverTriggersDirectFallback() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .staleOwnership
        let viewModel = HomeGameListViewModel(
            section: .popular,
            games: [],
            wishlistedGameIDs: [],
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: repository),
            librarySync: router
        )

        let enqueued = expectation(description: "enqueue recorded")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.didTapFavorite(gameId: 7))
        await fulfillment(of: [enqueued], timeout: 10)
        await drainConcurrentWork()

        XCTAssertEqual(repository.mutationCount, 0)
        XCTAssertEqual(router.ownershipRevalidationCount, 0)
    }

    func testHomeGameListRefusedEnqueueReconcilesWithoutAnyNetworkRequest() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .storageBlocked
        let viewModel = HomeGameListViewModel(
            section: .popular,
            games: [],
            wishlistedGameIDs: [],
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: repository),
            librarySync: router
        )
        let recorder = NotificationRecorder(center: .default, names: [.favoriteDidChange])

        // Current ownership: the refusal reconciles the optimistic flip —
        // never a second transport path, never a fabricated success.
        let reconciled = expectation(description: "optimistic state reconciled")
        viewModel.onStateChanged = { state in
            if !state.wishlistedGameIDs.contains(7) {
                reconciled.fulfill()
            }
        }
        viewModel.send(.didTapFavorite(gameId: 7))
        XCTAssertTrue(viewModel.state.wishlistedGameIDs.contains(7))
        await fulfillment(of: [reconciled], timeout: 10)
        await drainConcurrentWork()

        XCTAssertEqual(repository.mutationCount, 0, "storageBlocked must never reach the repository")
        XCTAssertGreaterThanOrEqual(router.ownershipRevalidationCount, 1, "reconciliation must be ownership-guarded")
        XCTAssertEqual(recorder.count(of: .favoriteDidChange), 0, "a refused intent must not fabricate a favorite change")
    }

    // MARK: 10. Refusal delivered after the scope ended cannot change current UI

    func testHomeGameListStaleRefusalLeavesCurrentUIUntouched() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.holdEnqueues = true
        let viewModel = HomeGameListViewModel(
            section: .popular,
            games: [],
            wishlistedGameIDs: [],
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: repository),
            librarySync: router
        )
        let recorder = NotificationRecorder(center: .default, names: [.favoriteDidChange])

        // The enqueue parks; the owning scope ends while it is in flight,
        // then the engine refuses it. The stale refusal must not touch the
        // (new) current UI state.
        let enqueued = expectation(description: "enqueue parked")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.didTapFavorite(gameId: 9))
        let optimisticState = viewModel.state.wishlistedGameIDs
        await fulfillment(of: [enqueued], timeout: 10)

        router.ownershipIsCurrent = false
        router.resolveHeldEnqueue(
            entityKey: LibrarySyncEntityKey.favorite(gameID: "9"),
            sequence: 1,
            with: .storageBlocked
        )
        await drainConcurrentWork()

        XCTAssertEqual(repository.mutationCount, 0, "a stale refusal must never reach the repository")
        XCTAssertEqual(recorder.count(of: .favoriteDidChange), 0, "a stale refusal must not publish a favorite change")
        XCTAssertEqual(viewModel.state.wishlistedGameIDs, optimisticState, "a stale refusal must not rewrite current UI state")
    }

    // MARK: 13. GameDetailViewModel

    private func makeGameDetailViewModel(
        repository: RecordingFavoriteRepository,
        router: MockLibraryMutationRouter
    ) -> GameDetailViewModel {
        GameDetailViewModel(
            fetchFavoriteStatusUseCase: FetchFavoriteStatusUseCase(favoriteRepository: repository),
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: repository),
            fetchAIReviewSummaryUseCase: DefaultFetchAIReviewSummaryUseCase(
                repository: MockAIReviewSummaryRepository()
            ),
            librarySync: router
        )
    }

    func testGameDetailCapturesOwnershipAtGestureAndThreadsItThroughEnqueue() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        let viewModel = makeGameDetailViewModel(repository: repository, router: router)

        // viewDidLoad pins currentGameID synchronously; the background loads
        // are irrelevant to the gesture path under test.
        viewModel.send(.viewDidLoad(gameId: 900_042))

        let enqueued = expectation(description: "enqueue recorded")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.didTapHaveIt)

        XCTAssertEqual(router.capturedOwnerships.count, 1)
        XCTAssertEqual(
            router.capturedOwnerships[0].entityKey,
            LibrarySyncEntityKey.favorite(gameID: "900042")
        )

        await fulfillment(of: [enqueued], timeout: 10)
        XCTAssertEqual(router.enqueuedOwnerships, router.capturedOwnerships)
    }

    func testGameDetailStaleOwnershipNeverTriggersDirectFallback() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .staleOwnership
        let viewModel = makeGameDetailViewModel(repository: repository, router: router)
        viewModel.send(.viewDidLoad(gameId: 900_042))

        let enqueued = expectation(description: "enqueue recorded")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.didTapHaveIt)
        await fulfillment(of: [enqueued], timeout: 10)
        await drainConcurrentWork()

        XCTAssertEqual(repository.mutationCount, 0, "staleOwnership must never reach the direct path")
        XCTAssertEqual(router.ownershipRevalidationCount, 0)
    }

    func testGameDetailRefusedEnqueueWithStaleScopeNeverTouchesNetworkOrUI() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .serviceUnavailable
        router.ownershipIsCurrent = false
        let viewModel = makeGameDetailViewModel(repository: repository, router: router)
        viewModel.send(.viewDidLoad(gameId: 900_042))

        let revalidated = expectation(description: "ownership revalidated")
        router.onOwnershipRevalidation = { revalidated.fulfill() }
        viewModel.send(.didTapHaveIt)
        await fulfillment(of: [revalidated], timeout: 10)
        await drainConcurrentWork()

        XCTAssertEqual(repository.mutationCount, 0, "a refused enqueue must never construct a network request")
        // The favorite value itself is owned by the screen's background
        // status load here; the stale refusal's obligation is to publish
        // nothing — no error banner and no fabricated outcome.
        XCTAssertNil(
            viewModel.state.errorMessage,
            "a stale scope's refusal must not surface into the new context"
        )
    }

    // MARK: 14. LibraryViewModel

    func testLibraryViewModelCapturesOwnershipAtGestureForRemoveFavorite() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        let viewModel = LibraryViewModel(
            removeFavoriteUseCase: RemoveFavoriteUseCase(favoriteRepository: repository),
            librarySync: router
        )

        let enqueued = expectation(description: "enqueue recorded")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(
            .didConfirmRemoveFavorite(
                LibraryGameIdentifier(source: .igdb, sourceID: "77", canonicalGameID: 77)
            )
        )

        XCTAssertEqual(router.capturedOwnerships.count, 1)
        XCTAssertEqual(router.capturedOwnerships[0].entityKey, LibrarySyncEntityKey.favorite(gameID: "77"))
        XCTAssertEqual(router.capturedOwnerships[0].intendedState, .favorite(isFavorite: false))

        await fulfillment(of: [enqueued], timeout: 10)
        XCTAssertEqual(router.enqueuedOwnerships, router.capturedOwnerships)
    }

    func testLibraryViewModelStaleOwnershipNeverTriggersDirectFallback() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .staleOwnership
        let viewModel = LibraryViewModel(
            removeFavoriteUseCase: RemoveFavoriteUseCase(favoriteRepository: repository),
            librarySync: router
        )

        let enqueued = expectation(description: "enqueue recorded")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(
            .didConfirmRemoveFavorite(
                LibraryGameIdentifier(source: .igdb, sourceID: "77", canonicalGameID: 77)
            )
        )
        await fulfillment(of: [enqueued], timeout: 10)
        await drainConcurrentWork()

        XCTAssertEqual(repository.mutationCount, 0)
        XCTAssertEqual(router.ownershipRevalidationCount, 0)
    }

    func testLibraryViewModelRefusedEnqueueWithStaleScopeNeverTouchesNetwork() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .storageBlocked
        router.ownershipIsCurrent = false
        let viewModel = LibraryViewModel(
            removeFavoriteUseCase: RemoveFavoriteUseCase(favoriteRepository: repository),
            librarySync: router
        )

        let revalidated = expectation(description: "ownership revalidated")
        router.onOwnershipRevalidation = { revalidated.fulfill() }
        viewModel.send(
            .didConfirmRemoveFavorite(
                LibraryGameIdentifier(source: .igdb, sourceID: "77", canonicalGameID: 77)
            )
        )
        await fulfillment(of: [revalidated], timeout: 10)
        await drainConcurrentWork()

        XCTAssertEqual(repository.mutationCount, 0, "a refused enqueue must never construct a network request")
    }

    // MARK: - Guest capture keeps the pre-2.2 direct path

    func testGuestGestureWithoutOwnershipUsesDirectPathUnchanged() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.accountID = nil // guest: capture fails
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
            notification.userInfo?[FavoriteChangeUserInfoKey.gameId] as? Int == 3
        }
        viewModel.send(.didTapFavorite(gameId: 3))
        await fulfillment(of: [posted], timeout: 10)

        XCTAssertEqual(repository.addedGameIDs, ["3"])
        XCTAssertTrue(router.favoriteChanges.isEmpty, "guest gestures never enter the queue")
    }

    /// Deterministically waits (by yielding, never by wall clock) until the
    /// engine reports at least `count` suspended account-load waiters.
    private func waitForLoadWaiters(_ engine: LibrarySyncEngine, count: Int) async {
        for _ in 0..<10_000 {
            let waiters = await engine.accountLoadWaiterCount
            if waiters >= count { return }
            await Task.yield()
        }
        XCTFail("account-load waiters never reached \(count)")
    }
}
