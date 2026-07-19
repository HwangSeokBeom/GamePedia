import XCTest
@testable import GamePedia

// MARK: - Engine-only mutation route (iOS 2.4 review follow-up)
//
// Authenticated favorite/library mutations have exactly one transport: the
// durable LibrarySyncEngine. When durable acceptance fails (storageBlocked /
// serviceUnavailable) the intent receives a retryable LOCAL failure — it is
// never submitted through a second path. These tests pin the mixed-path
// elimination:
//
//   1. sequence 1 is durably accepted
//   2. sequence 2 fails persistence
//   3. sequence 2 performs NO network request
//   4. optimistic UI reconciles to sequence 1's acknowledged state
//   5. sequence 1 later replays deterministically (it remains the last
//      accepted durable intent), including across restart
//
// Deterministic throughout: persistence failures are scripted per write
// index, transport calls park on continuations, and negative assertions run
// behind deterministic signals — no sleeps.
final class LibraryEngineOnlyMutationTests: XCTestCase {

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

    private func drainConcurrentWork() async {
        for _ in 0..<200 {
            await Task.yield()
        }
        await MainActor.run {}
        for _ in 0..<200 {
            await Task.yield()
        }
    }

    // MARK: 11–16, 22. In-flight sequence 1, storageBlocked sequence 2

    func testStorageBlockedSequence2PerformsNoRequestWhileSequence1IsInFlight() async throws {
        transport.behavior = { _, index in index == 0 ? .hold : .success(nil) }
        let requestOnWire = expectation(description: "sequence 1 on the wire")
        transport.onCall = { call in
            if call.index == 0 { requestOnWire.fulfill() }
        }
        let engine = await makeAuthenticatedEngine()

        // Sequence 1: durably accepted, request held in flight.
        let ownership1 = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))
        let result1 = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: ownership1)
        XCTAssertEqual(result1, .accepted)
        await fulfillment(of: [requestOnWire], timeout: 10)

        // Sequence 2: the durable write fails.
        store.persistBehavior = { index, _, _ in index >= 1 ? MockStoreWriteError() : nil }
        let ownership2 = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: false))
        let result2 = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: false, ownership: ownership2)
        XCTAssertEqual(result2, .storageBlocked, "sequence 2 must receive a retryable local failure")

        await drainConcurrentWork()
        // No mixed path: sequence 2 never reached the network.
        XCTAssertEqual(transport.calls.count, 1, "only sequence 1 may ever transmit")

        // Sequence 1 remains the last accepted durable intent and settles
        // deterministically with ITS OWN intent value.
        store.persistBehavior = { _, _, _ in nil }
        let settled = notificationExpectation(.favoriteDidChange, center: center) { notification in
            notification.userInfo?[FavoriteChangeUserInfoKey.isFavorite] as? Bool == true
        }
        transport.resolveHeldWithDefaultSuccess(index: 0)
        await fulfillment(of: [settled], timeout: 10)

        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 0)
        XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty)
        XCTAssertEqual(transport.calls.count, 1)
    }

    // MARK: 17. Restart after the refused sequence 2 stays deterministic

    func testRestartAfterStorageBlockedReplaysOnlySequence1() async throws {
        transport.behavior = { _, index in index == 0 ? .hold : .success(nil) }
        let requestOnWire = expectation(description: "sequence 1 on the wire")
        transport.onCall = { call in
            if call.index == 0 { requestOnWire.fulfill() }
        }
        let engine = await makeAuthenticatedEngine()

        let ownership1 = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: ownership1)
        await fulfillment(of: [requestOnWire], timeout: 10)

        store.persistBehavior = { index, _, _ in index == 1 ? MockStoreWriteError() : nil }
        let ownership2 = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: false))
        let result2 = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: false, ownership: ownership2)
        XCTAssertEqual(result2, .storageBlocked)

        // The durable file holds exactly sequence 1 — what a restart loads.
        let persisted = store.storedOperations(accountID: "user-a")
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted[0].kind, .setFavorite(gameID: "42", isFavorite: true))

        // "Restart": a fresh engine over the same store replays sequence 1
        // only, with sequence 1's intent value.
        let transport2 = MockLibrarySyncTransport()
        let replayed = expectation(description: "sequence 1 replayed after restart")
        transport2.onCall = { call in
            if call.index == 0 { replayed.fulfill() }
        }
        let engine2 = makeSyncEngine(store: store, transport: transport2, notificationCenter: NotificationCenter())
        await engine2.sessionDidChange(isAuthenticated: true, userID: "user-a")
        await fulfillment(of: [replayed], timeout: 10)
        await drainConcurrentWork()

        XCTAssertEqual(transport2.calls.count, 1)
        XCTAssertEqual(
            transport2.calls[0].operation.kind,
            .setFavorite(gameID: "42", isFavorite: true),
            "restart must replay the last accepted durable intent, never the refused one"
        )
        // Unblock the first engine's held call so nothing leaks.
        transport.resolveHeldWithDefaultSuccess(index: 0)
        _ = engine
    }

    // MARK: 21. Parked sequence 1 survives a refused sequence 2

    func testParkedSequence1SurvivesStorageBlockedSequence2AndReplaysOnRetry() async throws {
        // Sequence 1 exhausts its automatic attempts (3) and parks.
        transport.behavior = { _, index in
            index < 3 ? .failure(FavoriteError.network) : .success(nil)
        }
        let parked = notificationExpectation(.librarySyncQueueDidChange, center: center) { notification in
            notification.userInfo?[LibrarySyncQueueUserInfoKey.parkedCount] as? Int == 1
        }
        let engine = await makeAuthenticatedEngine()
        let ownership1 = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))
        let result1 = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: ownership1)
        XCTAssertEqual(result1, .accepted)
        await fulfillment(of: [parked], timeout: 10)
        XCTAssertEqual(transport.calls.count, 3)

        // Sequence 2 is refused durably; sequence 1's record must survive
        // in memory AND on disk.
        store.persistBehavior = { _, _, _ in MockStoreWriteError() }
        let ownership2 = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: false))
        let result2 = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: false, ownership: ownership2)
        XCTAssertEqual(result2, .storageBlocked)
        await drainConcurrentWork()
        XCTAssertEqual(transport.calls.count, 3, "the refused sequence 2 must not transmit")
        let persisted = store.storedOperations(accountID: "user-a")
        XCTAssertEqual(persisted.map(\.kind), [.setFavorite(gameID: "42", isFavorite: true)])

        // Manual retry replays sequence 1 — the last accepted intent.
        store.persistBehavior = { _, _, _ in nil }
        let settled = notificationExpectation(.favoriteDidChange, center: center) { notification in
            notification.userInfo?[FavoriteChangeUserInfoKey.isFavorite] as? Bool == true
        }
        await engine.retryNow()
        await fulfillment(of: [settled], timeout: 10)
        XCTAssertEqual(transport.calls.count, 4)
        XCTAssertEqual(transport.calls[3].operation.kind, .setFavorite(gameID: "42", isFavorite: true))
    }

    // MARK: 18. serviceUnavailable performs no networking either

    func testServiceUnavailableBeforeEngineAdoptionPerformsNoRequest() async throws {
        let engine = makeEngine()
        // The gesture-scope is current (the runtime adopted it
        // synchronously) but the engine has not adopted the account yet.
        engine.ownershipContext.adoptSession(isAuthenticated: true, userID: "user-a")
        let ownership = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))

        let result = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: ownership)
        XCTAssertEqual(result, .serviceUnavailable)
        await drainConcurrentWork()

        XCTAssertTrue(transport.calls.isEmpty, "a locally refused intent must never transmit")
        XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty)
        XCTAssertTrue(engine.isNewestOwnedIntent(ownership), "the refusal callback may reconcile: scope and sequence are still current")
    }

    // MARK: 20. Library-status mutations follow the same contract

    func testStorageBlockedLibraryStatusSequence2PerformsNoRequestAndSequence1Replays() async throws {
        transport.behavior = { _, index in index == 0 ? .hold : .success(nil) }
        let requestOnWire = expectation(description: "sequence 1 on the wire")
        transport.onCall = { call in
            if call.index == 0 { requestOnWire.fulfill() }
        }
        let engine = await makeAuthenticatedEngine()

        let request1 = makeStatusRequest(status: .playing)
        let ownership1 = try XCTUnwrap(engine.captureLibraryStatusIntent(request1))
        let result1 = await engine.enqueueLibraryStatusUpdate(request1, ownership: ownership1)
        XCTAssertEqual(result1, .accepted)
        await fulfillment(of: [requestOnWire], timeout: 10)

        store.persistBehavior = { index, _, _ in index == 1 ? MockStoreWriteError() : nil }
        let request2 = makeStatusRequest(status: .completed)
        let ownership2 = try XCTUnwrap(engine.captureLibraryStatusIntent(request2))
        let result2 = await engine.enqueueLibraryStatusUpdate(request2, ownership: ownership2)
        XCTAssertEqual(result2, .storageBlocked)

        await drainConcurrentWork()
        XCTAssertEqual(transport.calls.count, 1, "the refused status update must not transmit")

        let settled = notificationExpectation(.libraryDidChange, center: center)
        transport.resolveHeldWithDefaultSuccess(index: 0)
        await fulfillment(of: [settled], timeout: 10)
        XCTAssertEqual(transport.calls.count, 1)
        XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty)
    }

    // MARK: 12–15, 19. ViewModel semantics: reconcile to the acknowledged state

    private final class RecordingFavoriteRepository: FavoriteRepository, @unchecked Sendable {
        private let lock = NSLock()
        private(set) var mutationCount = 0

        func addFavorite(gameId: String, authorization: RequestAuthorization) async throws -> FavoriteMutationResult {
            lock.lock()
            mutationCount += 1
            lock.unlock()
            return FavoriteMutationResult(gameId: Int(gameId) ?? -1, isFavorite: true)
        }

        func removeFavorite(gameId: String, authorization: RequestAuthorization) async throws -> FavoriteMutationResult {
            lock.lock()
            mutationCount += 1
            lock.unlock()
            return FavoriteMutationResult(gameId: Int(gameId) ?? -1, isFavorite: false)
        }

        func fetchMyFavorites(sort: FavoriteSortOption?) async throws -> [FavoriteItem] { [] }

        func fetchFavoriteStatus(gameId: String) async throws -> FavoriteStatus {
            FavoriteStatus(isFavorite: false)
        }
    }

    func testHomeViewModelReconcilesRefusedSequence2ToSequence1AcknowledgedState() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        let viewModel = HomeViewModel(
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: repository),
            librarySync: router
        )

        // Sequence 1 (favorite ON) is accepted: its optimistic state IS the
        // acknowledged baseline for the next gesture.
        let firstEnqueued = expectation(description: "sequence 1 enqueued")
        router.onEnqueue = { firstEnqueued.fulfill() }
        viewModel.send(.didTapFavorite(gameId: 42))
        await fulfillment(of: [firstEnqueued], timeout: 10)
        router.onEnqueue = nil
        XCTAssertTrue(viewModel.state.wishlistedGameIDs.contains(42))

        // Sequence 2 (favorite OFF) is refused durably: the UI must return
        // to sequence 1's acknowledged state and surface a retryable error,
        // without any direct repository call.
        router.enqueueResult = .storageBlocked
        let reconciled = expectation(description: "UI reconciled to sequence 1's state")
        viewModel.onStateChanged = { state in
            if state.wishlistedGameIDs.contains(42), state.errorMessage != nil {
                reconciled.fulfill()
            }
        }
        viewModel.send(.didTapFavorite(gameId: 42))
        await fulfillment(of: [reconciled], timeout: 10)

        XCTAssertEqual(repository.mutationCount, 0, "no authenticated intent may reach the repository")
        XCTAssertTrue(viewModel.state.wishlistedGameIDs.contains(42))
        XCTAssertNotNil(viewModel.state.errorMessage, "the failure must be visible and retryable")
    }

    func testRefusalOfOlderGestureDoesNotOverwriteNewerOptimisticIntent() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.holdEnqueues = true
        let viewModel = HomeViewModel(
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: repository),
            librarySync: router
        )

        // Two rapid gestures: seq1 (ON) and seq2 (OFF) park in the engine.
        let bothEnqueued = expectation(description: "both gestures enqueued")
        bothEnqueued.expectedFulfillmentCount = 2
        router.onEnqueue = { bothEnqueued.fulfill() }
        viewModel.send(.didTapFavorite(gameId: 42)) // seq1: ON
        viewModel.send(.didTapFavorite(gameId: 42)) // seq2: OFF (newest)
        await fulfillment(of: [bothEnqueued], timeout: 10)
        XCTAssertFalse(viewModel.state.wishlistedGameIDs.contains(42), "seq2's optimistic state governs")

        // The engine settles seq2 first (accepted), then refuses seq1.
        let key = LibrarySyncEntityKey.favorite(gameID: "42")
        router.resolveHeldEnqueue(entityKey: key, sequence: 2, with: .accepted)
        router.resolveHeldEnqueue(entityKey: key, sequence: 1, with: .storageBlocked)
        for _ in 0..<200 { await Task.yield() }
        await MainActor.run {}
        for _ in 0..<200 { await Task.yield() }

        XCTAssertFalse(
            viewModel.state.wishlistedGameIDs.contains(42),
            "the stale refusal of seq1 must not overwrite seq2's newer optimistic intent"
        )
        XCTAssertNil(viewModel.state.errorMessage, "an outdated gesture's refusal must stay silent")
        XCTAssertEqual(repository.mutationCount, 0)
    }
}
