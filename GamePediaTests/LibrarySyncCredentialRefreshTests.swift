import XCTest
@testable import GamePedia

// H-IOS-1 — same-account credential refresh must not replay active mutations.
//
// A same-account authenticated session event (token refresh) is a
// credential event, not an account replacement: the engine must not advance
// the account-scope generation, must not cancel an in-flight request (it
// may already be on the wire and is not retractable), must not clear
// in-flight ownership, must not replay the retained operation, and must not
// reload the persisted queue. Account replacement, logout, and account
// deletion keep their invalidating semantics unchanged.
//
// Deterministic throughout: transport calls park on continuations, loads
// park on continuations, time is a fake sleeper, and negative assertions
// are ordered behind later deterministic signals — no sleeps.
final class LibrarySyncCredentialRefreshTests: XCTestCase {

    private var center: NotificationCenter!
    private var transport: MockLibrarySyncTransport!
    private var store: InMemorySyncOperationStore!

    override func setUp() {
        super.setUp()
        center = NotificationCenter()
        transport = MockLibrarySyncTransport()
        store = InMemorySyncOperationStore()
    }

    private func makeEngine(
        sleeper: RealtimeSleeping = TestRealtimeSleeper(autoResume: true),
        maxAutomaticAttempts: Int = 3
    ) -> LibrarySyncEngine {
        makeSyncEngine(
            store: store,
            transport: transport,
            notificationCenter: center,
            sleeper: sleeper,
            maxAutomaticAttempts: maxAutomaticAttempts
        )
    }

    private func makeAuthenticatedEngine(
        accountID: String = "user-a",
        sleeper: RealtimeSleeping = TestRealtimeSleeper(autoResume: true),
        maxAutomaticAttempts: Int = 3
    ) async -> LibrarySyncEngine {
        let engine = makeEngine(sleeper: sleeper, maxAutomaticAttempts: maxAutomaticAttempts)
        await engine.sessionDidChange(isAuthenticated: true, userID: accountID)
        return engine
    }

    /// Enqueues one favorite mutation and returns once its transport call is
    /// suspended before any response — the "request already sent" window.
    private func startHeldMutation(
        _ engine: LibrarySyncEngine,
        gameID: String = "42",
        heldIndex: Int = 0
    ) async {
        let inFlight = expectation(description: "call \(heldIndex) in flight")
        transport.onCall = { call in
            if call.index == heldIndex { inFlight.fulfill() }
        }
        _ = await engine.enqueueFavoriteChange(gameID: gameID, isFavorite: true)
        await fulfillment(of: [inFlight], timeout: 10)
        transport.onCall = nil
    }

    // MARK: 1 + 7. Refresh while a request is suspended before its response

    func testSameAccountRefreshWhileRequestSuspendedNeverCancelsOrReplaysIt() async {
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine()
        let recorder = NotificationRecorder(center: center, names: [.favoriteDidChange])
        await startHeldMutation(engine)

        // The transport hold is deliberately non-cooperative: it ignores
        // task cancellation, exactly like a request whose bytes already
        // left the device. The refresh must not rely on cancelling it.
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        // The original request completes; its completion must apply once.
        let applied = notificationExpectation(.favoriteDidChange, center: center)
        transport.resolveHeldWithDefaultSuccess(index: 0)
        await fulfillment(of: [applied], timeout: 10)

        XCTAssertEqual(transport.calls.count, 1, "the refresh must not replay the in-flight operation")
        XCTAssertEqual(recorder.count(of: .favoriteDidChange), 1)
        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 0)
        XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty)
    }

    // MARK: 2. No second network submission

    func testSameAccountRefreshCreatesNoSecondSubmission() async {
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine()
        await startHeldMutation(engine)

        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        // Deterministic ordering signal: a full round-trip on an
        // independent entity proves the engine processed the refresh and
        // any drain it triggered before we assert the negative.
        let probe = notificationExpectation(.favoriteDidChange, center: center) { notification in
            notification.userInfo?[FavoriteChangeUserInfoKey.gameId] as? Int == 77
        }
        transport.behavior = { _, index in index == 0 ? .hold : .success(nil) }
        _ = await engine.enqueueFavoriteChange(gameID: "77", isFavorite: true)
        await fulfillment(of: [probe], timeout: 10)

        let submissionsForHeldEntity = transport.calls.filter {
            if case .setFavorite(let gameID, _) = $0.operation.kind { return gameID == "42" }
            return false
        }
        XCTAssertEqual(submissionsForHeldEntity.count, 1, "exactly one submission may exist for the in-flight entity")
        transport.resolveHeldWithDefaultSuccess(index: 0)
    }

    // MARK: 3. Account-scope generation is not advanced

    func testSameAccountRefreshDoesNotAdvanceAccountScopeGeneration() async {
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine()
        await startHeldMutation(engine)

        let before = await engine.diagnosticsSnapshot()
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")
        let after = await engine.diagnosticsSnapshot()

        XCTAssertEqual(
            after.sessionGeneration,
            before.sessionGeneration,
            "a credential refresh must not advance the account-scope generation"
        )
        transport.resolveHeldWithDefaultSuccess(index: 0)
    }

    // MARK: 4. In-flight ownership survives

    func testSameAccountRefreshPreservesEntityInFlightOwnership() async {
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine()
        await startHeldMutation(engine)

        let ownedBefore = await engine.inFlightOperationIDsSnapshot
        XCTAssertEqual(ownedBefore.count, 1)

        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        let ownedAfter = await engine.inFlightOperationIDsSnapshot
        XCTAssertEqual(ownedAfter, ownedBefore, "in-flight ownership must survive a credential refresh")
        let snapshot = await engine.diagnosticsSnapshot()
        XCTAssertEqual(snapshot.inFlightEntityCount, 1, "the entity task must not be cancelled")
        transport.resolveHeldWithDefaultSuccess(index: 0)
    }

    // MARK: 5 + 6. Newer intent waits, then runs exactly once after the original

    func testNewerIntentWaitsBehindOriginalRequestAndRunsExactlyOnceAfterIt() async {
        transport.behavior = { _, index in index == 0 ? .hold : .success(nil) }
        let engine = await makeAuthenticatedEngine()
        let recorder = NotificationRecorder(center: center, names: [.favoriteDidChange])
        await startHeldMutation(engine, gameID: "42")

        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        // Newer intent for the SAME entity: must queue behind the
        // non-retractable in-flight request, not start concurrently.
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: false)
        let pendingDuring = await engine.pendingOperationCount
        XCTAssertEqual(pendingDuring, 2)
        XCTAssertEqual(transport.calls.count, 1, "the newer intent must wait behind the original request")

        // Original completes → the newer intent executes exactly once.
        let bothApplied = notificationExpectation(.favoriteDidChange, center: center)
        bothApplied.expectedFulfillmentCount = 2
        transport.resolveHeldWithDefaultSuccess(index: 0)
        await fulfillment(of: [bothApplied], timeout: 10)

        XCTAssertEqual(transport.calls.count, 2)
        guard case .setFavorite(_, let first) = transport.calls[0].operation.kind,
              case .setFavorite(_, let second) = transport.calls[1].operation.kind else {
            return XCTFail("unexpected kinds")
        }
        XCTAssertTrue(first, "the original add executes first")
        XCTAssertFalse(second, "the newer remove executes after it, exactly once")
        XCTAssertNotEqual(transport.calls[0].operation.id, transport.calls[1].operation.id)

        // Final locally accepted state is the newer intent (B): the last
        // applied notification carries the remove.
        let applies = recorder.notifications.filter { $0.name == .favoriteDidChange }
        XCTAssertEqual(applies.count, 2)
        XCTAssertEqual(
            applies.last?.userInfo?[FavoriteChangeUserInfoKey.isFavorite] as? Bool,
            false,
            "no stale callback may overwrite the newer intent's state"
        )
    }

    // MARK: 8. Many refreshes during one request

    func testManyRepeatedSameAccountRefreshesDuringOneRequestStayInert() async {
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine()
        let recorder = NotificationRecorder(center: center, names: [.favoriteDidChange])
        await startHeldMutation(engine)
        let generationBefore = await engine.diagnosticsSnapshot().sessionGeneration

        for _ in 0..<25 {
            await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")
        }

        let applied = notificationExpectation(.favoriteDidChange, center: center)
        transport.resolveHeldWithDefaultSuccess(index: 0)
        await fulfillment(of: [applied], timeout: 10)

        XCTAssertEqual(transport.calls.count, 1)
        XCTAssertEqual(recorder.count(of: .favoriteDidChange), 1)
        let generationAfter = await engine.diagnosticsSnapshot().sessionGeneration
        XCTAssertEqual(generationAfter, generationBefore)
    }

    // MARK: 9. Refresh during retry backoff

    func testSameAccountRefreshDuringRetryBackoffDoesNotDuplicateTheAttempt() async {
        // First attempt fails transiently; the entity loop sleeps on the
        // manual sleeper — the deterministic "during backoff" window.
        transport.behavior = { _, index in
            index == 0 ? .failure(FavoriteError.network) : .success(nil)
        }
        let sleeper = TestRealtimeSleeper(autoResume: false)
        let sleeping = expectation(description: "backoff sleep requested")
        sleeper.onSleepRequested = { _ in sleeping.fulfill() }
        let engine = await makeAuthenticatedEngine(sleeper: sleeper)

        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [sleeping], timeout: 10)

        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        // The refresh must not have started a second submission while the
        // original attempt's loop still owns the entity.
        XCTAssertEqual(transport.calls.count, 1)

        let applied = notificationExpectation(.favoriteDidChange, center: center)
        sleeper.releaseAll()
        await fulfillment(of: [applied], timeout: 10)

        XCTAssertEqual(transport.calls.count, 2, "one failed attempt, one retry — never a parallel duplicate")
        XCTAssertEqual(
            transport.calls[0].operation.id,
            transport.calls[1].operation.id,
            "the retry must reuse the same operation, not a replayed copy"
        )
    }

    // MARK: 10. Refresh while cleanup persistence is pending

    func testSameAccountRefreshWhileCleanupPersistencePendingNeverResubmits() async {
        // Persist 0 is the enqueue write (succeeds); persist 1 is the
        // post-success cleanup write (fails) → the confirmed record stays
        // in memory awaiting a later successful write.
        store.persistBehavior = { index, _, _ in index == 1 ? MockStoreWriteError() : nil }
        let engine = await makeAuthenticatedEngine()

        let applied = notificationExpectation(.favoriteDidChange, center: center)
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [applied], timeout: 10)

        let confirmedBefore = await engine.cleanupPendingOperations
        XCTAssertEqual(confirmedBefore.count, 1, "the cleanup write failure must retain the confirmed record")

        var loadsObserved = 0
        store.onLoad = { _ in loadsObserved += 1 }
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        // The refresh neither reloads the queue nor resubmits the
        // confirmed record. Order the negatives behind a full round-trip.
        let probe = notificationExpectation(.favoriteDidChange, center: center) { notification in
            notification.userInfo?[FavoriteChangeUserInfoKey.gameId] as? Int == 77
        }
        _ = await engine.enqueueFavoriteChange(gameID: "77", isFavorite: true)
        await fulfillment(of: [probe], timeout: 10)

        XCTAssertEqual(loadsObserved, 0, "a credential refresh must not reload the persisted queue")
        let submissionsFor42 = transport.calls.filter {
            if case .setFavorite(let gameID, _) = $0.operation.kind { return gameID == "42" }
            return false
        }
        XCTAssertEqual(submissionsFor42.count, 1, "a remotely confirmed operation must never be resubmitted")
    }

    // MARK: 11. Account replacement still invalidates and cancels

    func testAccountReplacementStillInvalidatesOwnershipAndCancelsAccountAWork() async {
        transport.behavior = { _, index in index == 0 ? .hold : .success(nil) }
        let engine = await makeAuthenticatedEngine(accountID: "user-a")
        let recorder = NotificationRecorder(center: center, names: [.favoriteDidChange])
        await startHeldMutation(engine, gameID: "1")
        let generationBefore = await engine.diagnosticsSnapshot().sessionGeneration

        await engine.sessionDidChange(isAuthenticated: true, userID: "user-b")

        let generationAfter = await engine.diagnosticsSnapshot().sessionGeneration
        XCTAssertNotEqual(generationAfter, generationBefore, "a real switch must advance the generation")
        let owned = await engine.inFlightOperationIDsSnapshot
        XCTAssertTrue(owned.isEmpty, "a real switch must clear A's in-flight ownership")

        // A's late completion stays inert; A's queue stays isolated on disk.
        transport.resolveHeldWithDefaultSuccess(index: 0)
        let probe = notificationExpectation(.favoriteDidChange, center: center) { notification in
            notification.userInfo?[FavoriteChangeUserInfoKey.gameId] as? Int == 2
        }
        _ = await engine.enqueueFavoriteChange(gameID: "2", isFavorite: true)
        await fulfillment(of: [probe], timeout: 10)

        XCTAssertEqual(store.storedOperations(accountID: "user-a").count, 1)
        XCTAssertEqual(recorder.count(of: .favoriteDidChange), 1, "only B's operation may apply")
    }

    // MARK: 12. Logout still makes A's completion inert

    func testLogoutStillPreventsAccountACompletionFromMutatingNewState() async {
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine(accountID: "user-a")
        let recorder = NotificationRecorder(center: center, names: [.favoriteDidChange, .librarySyncQueueDidChange])
        await startHeldMutation(engine, gameID: "9")

        await engine.sessionDidChange(isAuthenticated: false, userID: nil)
        transport.resolveHeldWithDefaultSuccess(index: 0)

        // Deterministic ordering: the engine's next queue signal follows a
        // rejected enqueue attempt while unauthenticated.
        let rejected = await engine.enqueueFavoriteChange(gameID: "10", isFavorite: true)
        XCTAssertEqual(rejected, .serviceUnavailable)

        XCTAssertEqual(recorder.count(of: .favoriteDidChange), 0, "A's completion after logout must be inert")
        XCTAssertEqual(store.storedOperations(accountID: "user-a").count, 1, "A's queue stays isolated on disk")
    }

    // MARK: 13. Auth-failure ownership stays with the auth subsystem

    func testAuthFailurePausesWithoutEngineRefreshAndResumesWithoutGenerationChange() async {
        // TOKEN_REVOKED / refresh single-flight belong to the auth layer;
        // the engine only pauses on an auth failure and resumes on the next
        // authenticated session event — without a generation change and
        // without ever initiating auth work itself.
        transport.behavior = { _, index in
            index == 0 ? .failure(FavoriteError.unauthorized) : .success(nil)
        }
        let engine = await makeAuthenticatedEngine(accountID: "user-a")
        let generationBefore = await engine.diagnosticsSnapshot().sessionGeneration

        let paused = notificationExpectation(.librarySyncQueueDidChange, center: center)
        paused.expectedFulfillmentCount = 2
        _ = await engine.enqueueFavoriteChange(gameID: "5", isFavorite: true)
        await fulfillment(of: [paused], timeout: 10)

        let pausedSnapshot = await engine.diagnosticsSnapshot()
        XCTAssertTrue(pausedSnapshot.isBlockedOnAuth)
        XCTAssertEqual(transport.calls.count, 1, "the engine must not run its own refresh/retry loop")

        // The auth layer's successful refresh arrives as a same-account
        // session event: the queue resumes the SAME operation under the
        // SAME account-scope generation.
        let resumed = notificationExpectation(.favoriteDidChange, center: center)
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")
        await fulfillment(of: [resumed], timeout: 10)

        XCTAssertEqual(transport.calls.count, 2)
        XCTAssertEqual(transport.calls[0].operation.id, transport.calls[1].operation.id)
        let generationAfter = await engine.diagnosticsSnapshot().sessionGeneration
        XCTAssertEqual(generationAfter, generationBefore)
    }

    // MARK: 14. The critical interleaving, repeated 50 times

    /// The strongest regression shape, 50 deterministic repetitions:
    /// mutation A starts once → same-account refresh → newer intent B is
    /// accepted → no second A submission → A completes → B runs exactly
    /// once afterwards → the final locally accepted state is B, and no
    /// stale callback overwrites it.
    func testCriticalRefreshInterleavingRepeated50Times() async {
        for iteration in 0..<50 {
            center = NotificationCenter()
            transport = MockLibrarySyncTransport()
            store = InMemorySyncOperationStore()
            transport.behavior = { _, index in index == 0 ? .hold : .success(nil) }
            let engine = await makeAuthenticatedEngine(accountID: "user-a")
            let recorder = NotificationRecorder(center: center, names: [.favoriteDidChange])

            // A starts exactly once and suspends before its response.
            await startHeldMutation(engine, gameID: "42")

            // Same-account credential refresh, racing nothing away.
            await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

            // Newer intent B for the same entity is accepted.
            let acceptedB = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: false)
            XCTAssertEqual(acceptedB, .accepted, "iteration \(iteration)")
            XCTAssertEqual(transport.calls.count, 1, "iteration \(iteration): no second A submission")

            // A completes; B then runs exactly once.
            let bothApplied = notificationExpectation(.favoriteDidChange, center: center)
            bothApplied.expectedFulfillmentCount = 2
            transport.resolveHeldWithDefaultSuccess(index: 0)
            await fulfillment(of: [bothApplied], timeout: 10)

            XCTAssertEqual(transport.calls.count, 2, "iteration \(iteration)")
            XCTAssertEqual(
                transport.calls.filter { $0.operation.id == transport.calls[0].operation.id }.count,
                1,
                "iteration \(iteration): A must never be submitted twice"
            )
            guard case .setFavorite(_, let lastSent) = transport.calls[1].operation.kind else {
                return XCTFail("iteration \(iteration): unexpected kind")
            }
            XCTAssertFalse(lastSent, "iteration \(iteration): B executes after A")

            // Final locally accepted state is B; nothing overwrites it.
            let applies = recorder.notifications.filter { $0.name == .favoriteDidChange }
            XCTAssertEqual(applies.count, 2, "iteration \(iteration)")
            XCTAssertEqual(
                applies.last?.userInfo?[FavoriteChangeUserInfoKey.isFavorite] as? Bool,
                false,
                "iteration \(iteration): the final state must be B's intent"
            )
            let pending = await engine.pendingOperationCount
            XCTAssertEqual(pending, 0, "iteration \(iteration)")
            XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty, "iteration \(iteration)")
        }
    }
}
