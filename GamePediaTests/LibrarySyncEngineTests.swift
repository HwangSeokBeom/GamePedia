import XCTest
@testable import GamePedia

// MARK: - LibrarySyncEngine behavior
//
// Deterministic throughout: transport calls are scripted or parked on
// continuations, time is a fake sleeper, jitter is fixed, and every
// negative assertion is ordered behind a later deterministic signal via
// NotificationRecorder — no sleeps, no inverted expectations.

final class LibrarySyncEngineTests: XCTestCase {

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

    // MARK: 1. Optimistic add

    func testOptimisticAddIsQueuedDurablyBeforeTransportCompletes() async {
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine()

        let transportCalled = expectation(description: "transport called")
        transport.onCall = { _ in transportCalled.fulfill() }

        let accepted = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        XCTAssertEqual(accepted, .accepted)

        // Accepted, in the queue, and durable before the server has answered.
        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 1)
        XCTAssertEqual(store.storedOperations(accountID: "user-a").count, 1)

        await fulfillment(of: [transportCalled], timeout: 10)

        let success = notificationExpectation(.favoriteDidChange, center: center) { notification in
            notification.userInfo?[FavoriteChangeUserInfoKey.gameId] as? Int == 42
                && notification.userInfo?[FavoriteChangeUserInfoKey.isFavorite] as? Bool == true
                && notification.userInfo?[FavoriteChangeUserInfoKey.action] as? String
                    == FavoriteChangeAction.added.rawValue
        }
        transport.resolveHeldWithDefaultSuccess(index: 0)
        await fulfillment(of: [success], timeout: 10)

        let drained = await engine.pendingOperationCount
        XCTAssertEqual(drained, 0)
        XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty)
    }

    // MARK: 2. Optimistic remove

    func testOptimisticRemoveIsQueuedAndPostsRemovedAction() async {
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine()

        let transportCalled = expectation(description: "transport called")
        transport.onCall = { _ in transportCalled.fulfill() }

        let accepted = await engine.enqueueFavoriteChange(gameID: "7", isFavorite: false)
        XCTAssertEqual(accepted, .accepted)
        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 1)

        await fulfillment(of: [transportCalled], timeout: 10)

        let success = notificationExpectation(.favoriteDidChange, center: center) { notification in
            notification.userInfo?[FavoriteChangeUserInfoKey.action] as? String
                == FavoriteChangeAction.removed.rawValue
        }
        transport.resolveHeldWithDefaultSuccess(index: 0)
        await fulfillment(of: [success], timeout: 10)
    }

    // MARK: 3+4. Transient retry with backoff, idempotency key reuse

    func testTransientFailureRetriesWithBackoffReusingTheSameOperation() async {
        transport.behavior = { _, index in
            index < 2 ? .failure(FavoriteError.network) : .success(nil)
        }
        let sleeper = TestRealtimeSleeper(autoResume: true)
        let engine = await makeAuthenticatedEngine(sleeper: sleeper)

        let success = notificationExpectation(.favoriteDidChange, center: center)
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [success], timeout: 10)

        XCTAssertEqual(transport.calls.count, 3)
        let ids = Set(transport.calls.map { $0.operation.id })
        XCTAssertEqual(ids.count, 1, "every retry must reuse the same idempotency key")
        // baseDelay 2, multiplier 2, fixed jitter 0 → exact deterministic backoff.
        XCTAssertEqual(sleeper.requestedDelays, [2, 4])
    }

    // MARK: 5. Process-restart recovery (persistent storage)

    func testProcessRestartRecoversPersistedQueueAndReplaysSameOperation() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-restart-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        // Process 1: transport always fails; a single automatic attempt then
        // the entity parks, leaving the operation durable on disk.
        let store1 = FileSyncOperationStore(directoryURL: directory)
        let transport1 = MockLibrarySyncTransport()
        transport1.behavior = { _, _ in .failure(FavoriteError.network) }
        let center1 = NotificationCenter()
        let engine1 = makeSyncEngine(
            store: store1,
            transport: transport1,
            notificationCenter: center1,
            maxAutomaticAttempts: 1
        )
        await engine1.sessionDidChange(isAuthenticated: true, userID: "user-a")

        let parked = notificationExpectation(.librarySyncQueueDidChange, center: center1) { notification in
            notification.userInfo?[LibrarySyncQueueUserInfoKey.parkedCount] as? Int == 1
        }
        _ = await engine1.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [parked], timeout: 10)

        let originalOperations = await engine1.pendingOperations
        XCTAssertEqual(originalOperations.count, 1)
        let originalID = originalOperations[0].id

        // Process 2: fresh store/engine over the same directory.
        let store2 = FileSyncOperationStore(directoryURL: directory)
        let transport2 = MockLibrarySyncTransport()
        let center2 = NotificationCenter()
        let engine2 = makeSyncEngine(store: store2, transport: transport2, notificationCenter: center2)

        let replayed = notificationExpectation(.favoriteDidChange, center: center2)
        await engine2.sessionDidChange(isAuthenticated: true, userID: "user-a")
        await fulfillment(of: [replayed], timeout: 10)

        XCTAssertEqual(transport2.calls.count, 1)
        XCTAssertEqual(
            transport2.calls[0].operation.id,
            originalID,
            "restart must replay the persisted operation with its original idempotency key"
        )
    }

    // MARK: 6. Account switching isolation

    func testAccountSwitchNeverSubmitsThePreviousAccountsQueue() async {
        transport.behavior = { _, index in index == 0 ? .hold : .success(nil) }
        let engine = await makeAuthenticatedEngine(accountID: "user-a")
        let recorder = NotificationRecorder(center: center, names: [.favoriteDidChange])

        let firstCall = expectation(description: "account A operation in flight")
        transport.onCall = { call in
            if call.index == 0 { firstCall.fulfill() }
        }
        _ = await engine.enqueueFavoriteChange(gameID: "1", isFavorite: true)
        await fulfillment(of: [firstCall], timeout: 10)

        // Switch to account B while A's operation is in flight.
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-b")

        // A's late completion must be inert (stale session generation).
        transport.resolveHeldWithDefaultSuccess(index: 0)

        // Deterministic ordering signal: run one full B operation to completion.
        let successB = notificationExpectation(.favoriteDidChange, center: center) { notification in
            notification.userInfo?[FavoriteChangeUserInfoKey.gameId] as? Int == 2
        }
        transport.onCall = nil
        _ = await engine.enqueueFavoriteChange(gameID: "2", isFavorite: true)
        await fulfillment(of: [successB], timeout: 10)

        // A's queue is isolated on disk, was never applied, never submitted as B.
        XCTAssertEqual(store.storedOperations(accountID: "user-a").count, 1)
        XCTAssertEqual(recorder.count(of: .favoriteDidChange), 1)
        for call in transport.calls.dropFirst() {
            XCTAssertEqual(call.operation.accountID, "user-b")
        }

        // Switching back to A drains A's preserved operation.
        let successA = notificationExpectation(.favoriteDidChange, center: center) { notification in
            notification.userInfo?[FavoriteChangeUserInfoKey.gameId] as? Int == 1
        }
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")
        await fulfillment(of: [successA], timeout: 10)
        XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty)
    }

    // MARK: 7. Logout behavior

    func testLogoutPreservesQueueSubmitsNothingAndLateCompletionIsInert() async {
        transport.behavior = { _, index in index == 0 ? .hold : .success(nil) }
        let engine = await makeAuthenticatedEngine(accountID: "user-a")
        let recorder = NotificationRecorder(center: center, names: [.favoriteDidChange])

        let firstCall = expectation(description: "operation in flight")
        transport.onCall = { call in
            if call.index == 0 { firstCall.fulfill() }
        }
        _ = await engine.enqueueFavoriteChange(gameID: "9", isFavorite: true)
        await fulfillment(of: [firstCall], timeout: 10)

        await engine.sessionDidChange(isAuthenticated: false, userID: nil)

        // Late completion after logout: must not apply.
        transport.resolveHeldWithDefaultSuccess(index: 0)

        // While logged out the queue is isolated, not cleared.
        XCTAssertEqual(store.storedOperations(accountID: "user-a").count, 1)

        // Enqueue attempts while unauthenticated are rejected.
        let rejected = await engine.enqueueFavoriteChange(gameID: "10", isFavorite: true)
        XCTAssertEqual(rejected, .serviceUnavailable)

        // Same account signs back in: the preserved operation replays once.
        let replayed = notificationExpectation(.favoriteDidChange, center: center)
        transport.onCall = nil
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")
        await fulfillment(of: [replayed], timeout: 10)

        XCTAssertEqual(recorder.count(of: .favoriteDidChange), 1)
        XCTAssertEqual(transport.calls.count, 2)
        XCTAssertEqual(transport.calls[0].operation.id, transport.calls[1].operation.id)
    }

    // MARK: 8. Account deletion cleanup

    func testAccountDeletionPurgesPersistedQueue() async {
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine(accountID: "user-a")

        let transportCalled = expectation(description: "transport called")
        transport.onCall = { _ in transportCalled.fulfill() }
        _ = await engine.enqueueFavoriteChange(gameID: "3", isFavorite: true)
        await fulfillment(of: [transportCalled], timeout: 10)
        XCTAssertEqual(store.storedOperations(accountID: "user-a").count, 1)

        await engine.accountDidDelete(userID: "user-a")

        XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty)
        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 0)
        let snapshot = await engine.diagnosticsSnapshot()
        XCTAssertFalse(snapshot.hasActiveAccount)
        transport.resolveHeldWithDefaultSuccess(index: 0)
    }

    // MARK: 9. Compaction

    func testNewerPendingOperationSupersedesOlderOneForTheSameEntity() async {
        // Only the first call is ever held; the entity's loop is parked on it,
        // so every operation queued behind it is deterministically pending —
        // no scheduling luck involved.
        transport.behavior = { _, index in index == 0 ? .hold : .success(nil) }
        let engine = await makeAuthenticatedEngine()

        let firstCall = expectation(description: "first operation in flight")
        transport.onCall = { call in
            if call.index == 0 { firstCall.fulfill() }
        }
        _ = await engine.enqueueFavoriteChange(gameID: "9", isFavorite: true)
        await fulfillment(of: [firstCall], timeout: 10)

        // Queue a remove, then a newer add, behind the parked in-flight op.
        _ = await engine.enqueueFavoriteChange(gameID: "9", isFavorite: false)
        _ = await engine.enqueueFavoriteChange(gameID: "9", isFavorite: true)

        // The in-flight op survives; of the two pending intents only the
        // newest remains.
        let operations = await engine.pendingOperations
        XCTAssertEqual(operations.count, 2)
        guard case .setFavorite(_, let pendingIsFavorite) = operations[1].kind else {
            return XCTFail("unexpected kind")
        }
        XCTAssertTrue(pendingIsFavorite, "the newest intent (add) must win")

        // The latest local intent is what overlay reads see.
        let intent = await engine.pendingFavoriteIntent(gameID: "9")
        XCTAssertEqual(intent, true)

        // Drain: exactly two transmissions ever happen for this entity —
        // the in-flight add and the surviving add. The superseded remove is
        // never sent.
        let drained = notificationExpectation(.favoriteDidChange, center: center)
        drained.expectedFulfillmentCount = 2
        transport.onCall = nil
        transport.resolveHeldWithDefaultSuccess(index: 0)
        await fulfillment(of: [drained], timeout: 10)

        XCTAssertEqual(transport.calls.count, 2)
        for call in transport.calls {
            guard case .setFavorite(_, let sent) = call.operation.kind else {
                return XCTFail("unexpected kind")
            }
            XCTAssertTrue(sent, "the superseded remove must never be transmitted")
        }
    }

    // MARK: 10. Per-entity FIFO ordering

    func testOperationsForTheSameEntityExecuteStrictlyInOrder() async {
        transport.behavior = { _, index in index == 0 ? .hold : .success(nil) }
        let engine = await makeAuthenticatedEngine()

        let firstCall = expectation(description: "first status update in flight")
        transport.onCall = { call in
            if call.index == 0 { firstCall.fulfill() }
        }
        _ = await engine.enqueueLibraryStatusUpdate(makeStatusRequest(status: .playing))
        await fulfillment(of: [firstCall], timeout: 10)

        // Newer intent for the same entity queues behind the in-flight one.
        _ = await engine.enqueueLibraryStatusUpdate(makeStatusRequest(status: .completed))
        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 2)
        // Structural FIFO: the entity loop cannot start the second operation
        // until the first resolves, so at this point exactly one transport
        // call exists.
        XCTAssertEqual(transport.calls.count, 1)

        let secondDone = notificationExpectation(.libraryDidChange, center: center)
        secondDone.expectedFulfillmentCount = 2
        transport.onCall = nil
        transport.resolveHeldWithDefaultSuccess(index: 0)
        await fulfillment(of: [secondDone], timeout: 10)

        XCTAssertEqual(transport.calls.count, 2)
        guard case .setLibraryStatus(let firstPayload) = transport.calls[0].operation.kind,
              case .setLibraryStatus(let secondPayload) = transport.calls[1].operation.kind else {
            return XCTFail("unexpected kinds")
        }
        XCTAssertEqual(firstPayload.status, .playing)
        XCTAssertEqual(secondPayload.status, .completed)
    }

    // MARK: 11. Parallel sync for independent entities

    func testIndependentEntitiesSyncInParallel() async {
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine()

        let bothInFlight = expectation(description: "both operations in flight concurrently")
        bothInFlight.expectedFulfillmentCount = 2
        transport.onCall = { _ in bothInFlight.fulfill() }

        _ = await engine.enqueueFavoriteChange(gameID: "1", isFavorite: true)
        _ = await engine.enqueueFavoriteChange(gameID: "2", isFavorite: true)

        // Both held at once proves independent entities do not serialize.
        await fulfillment(of: [bothInFlight], timeout: 10)
        XCTAssertEqual(transport.heldCallIndices, [0, 1])

        let bothSucceeded = notificationExpectation(.favoriteDidChange, center: center)
        bothSucceeded.expectedFulfillmentCount = 2
        transport.resolveHeldWithDefaultSuccess(index: 0)
        transport.resolveHeldWithDefaultSuccess(index: 1)
        await fulfillment(of: [bothSucceeded], timeout: 10)
    }

    // MARK: 12. Permanent validation failure

    func testPermanentValidationFailureIsDroppedWithoutRetryAndSurfaced() async {
        transport.behavior = { _, _ in .failure(LibraryError.invalidStatus) }
        let engine = await makeAuthenticatedEngine()

        let failed = notificationExpectation(.librarySyncOperationDidFail, center: center) { notification in
            notification.userInfo?[LibrarySyncFailureUserInfoKey.errorCode] as? String == "INVALID_STATUS"
                && notification.userInfo?[LibrarySyncFailureUserInfoKey.entityKind] as? String
                    == LibrarySyncEntityKind.libraryStatus.rawValue
                && notification.userInfo?[LibrarySyncFailureUserInfoKey.gameID] as? String == "570"
        }
        _ = await engine.enqueueLibraryStatusUpdate(makeStatusRequest())
        await fulfillment(of: [failed], timeout: 10)

        XCTAssertEqual(transport.calls.count, 1, "permanent failures must never retry")
        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 0)
        XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty)
        let snapshot = await engine.diagnosticsSnapshot()
        XCTAssertEqual(snapshot.permanentlyFailedOperationCount, 1)
    }

    // MARK: 13. Token-refresh failure / auth pause

    func testAuthFailurePausesQueuePreservesWorkAndResumesOnReauthentication() async {
        transport.behavior = { _, index in
            index == 0 ? .failure(FavoriteError.unauthorized) : .success(nil)
        }
        let engine = await makeAuthenticatedEngine(accountID: "user-a")

        // Exactly two queue signals occur: one for the enqueue, one when the
        // auth failure pauses the queue (posted after isBlockedOnAuth is set).
        let paused = notificationExpectation(.librarySyncQueueDidChange, center: center)
        paused.expectedFulfillmentCount = 2
        _ = await engine.enqueueFavoriteChange(gameID: "5", isFavorite: true)
        await fulfillment(of: [paused], timeout: 10)

        let snapshot = await engine.diagnosticsSnapshot()
        XCTAssertTrue(snapshot.isBlockedOnAuth)
        XCTAssertEqual(snapshot.lastSafeErrorCode, "UNAUTHORIZED")
        XCTAssertEqual(transport.calls.count, 1, "the engine must not trigger its own refresh loop")
        XCTAssertEqual(store.storedOperations(accountID: "user-a").count, 1)

        // A fresh authenticated session event (the auth layer's refresh
        // succeeding) resumes the queue with the same operation.
        let replayed = notificationExpectation(.favoriteDidChange, center: center)
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")
        await fulfillment(of: [replayed], timeout: 10)
        XCTAssertEqual(transport.calls.count, 2)
        XCTAssertEqual(transport.calls[0].operation.id, transport.calls[1].operation.id)
    }

    // MARK: 14. Server reconciliation stays authoritative

    func testServerResponseValuesAreAuthoritativeInTheSuccessNotification() async {
        // Client queues an "add", server answers "not favorited" — the
        // notification must carry the server's answer, not the local intent.
        transport.behavior = { _, _ in
            .success(.favorite(FavoriteMutationResult(gameId: 42, isFavorite: false)))
        }
        let engine = await makeAuthenticatedEngine()

        let reconciled = notificationExpectation(.favoriteDidChange, center: center) { notification in
            notification.userInfo?[FavoriteChangeUserInfoKey.isFavorite] as? Bool == false
                && notification.userInfo?[FavoriteChangeUserInfoKey.action] as? String
                    == FavoriteChangeAction.removed.rawValue
        }
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [reconciled], timeout: 10)
    }

    // MARK: 17. Duplicate callback protection

    func testDuplicateCompletionForOneOperationAppliesExactlyOnce() async {
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine()
        let recorder = NotificationRecorder(center: center, names: [.favoriteDidChange])

        let transportCalled = expectation(description: "transport called")
        transport.onCall = { call in
            if call.index == 0 { transportCalled.fulfill() }
        }
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [transportCalled], timeout: 10)

        let operations = await engine.pendingOperations
        let operationID = operations[0].id
        let outcome = LibrarySyncOutcome.favorite(FavoriteMutationResult(gameId: 42, isFavorite: true))

        let first = await engine.handleTransportSuccess(operationID: operationID, outcome: outcome)
        let second = await engine.handleTransportSuccess(operationID: operationID, outcome: outcome)
        XCTAssertTrue(first)
        XCTAssertFalse(second, "a duplicate completion must be rejected")

        // The transport's own (third) completion for the same operation is
        // also inert. Probe with a fresh operation to order the assertion.
        transport.behavior = { _, index in index == 0 ? .hold : .success(nil) }
        transport.resolveHeldWithDefaultSuccess(index: 0)
        let probe = notificationExpectation(.favoriteDidChange, center: center) { notification in
            notification.userInfo?[FavoriteChangeUserInfoKey.gameId] as? Int == 77
        }
        transport.onCall = nil
        _ = await engine.enqueueFavoriteChange(gameID: "77", isFavorite: true)
        await fulfillment(of: [probe], timeout: 10)

        XCTAssertEqual(recorder.count(of: .favoriteDidChange), 2, "one apply for 42, one for the probe")
    }

    // MARK: Repeated concurrency races (50x)

    /// Races an account switch against the in-flight operation's completion
    /// 50 times. Whatever the interleaving, the completion either applies
    /// while account A still owns the session (queue drained) or is inert
    /// after the switch (queue preserved) — never both, never a leak into
    /// account B's session.
    func testRepeatedAccountSwitchCompletionRaces50Times() async {
        for iteration in 0..<50 {
            center = NotificationCenter()
            transport = MockLibrarySyncTransport()
            store = InMemorySyncOperationStore()
            transport.behavior = { _, index in index == 0 ? .hold : .success(nil) }
            let engine = await makeAuthenticatedEngine(accountID: "user-a")
            let recorder = NotificationRecorder(center: center, names: [.favoriteDidChange])

            let firstCall = expectation(description: "in flight #\(iteration)")
            transport.onCall = { call in
                if call.index == 0 { firstCall.fulfill() }
            }
            _ = await engine.enqueueFavoriteChange(gameID: "1", isFavorite: true)
            await fulfillment(of: [firstCall], timeout: 10)

            // Genuine race: the switch and the completion run concurrently.
            let localTransport = transport!
            async let switching: Void = engine.sessionDidChange(isAuthenticated: true, userID: "user-b")
            localTransport.resolveHeldWithDefaultSuccess(index: 0)
            await switching

            // Order all assertions behind one full B-side operation.
            let probe = notificationExpectation(.favoriteDidChange, center: center) { notification in
                notification.userInfo?[FavoriteChangeUserInfoKey.gameId] as? Int == 2
            }
            transport.onCall = nil
            _ = await engine.enqueueFavoriteChange(gameID: "2", isFavorite: true)
            await fulfillment(of: [probe], timeout: 10)

            let appliedForA = recorder.notifications.filter {
                $0.name == .favoriteDidChange
                    && $0.userInfo?[FavoriteChangeUserInfoKey.gameId] as? Int == 1
            }.count
            let preservedForA = store.storedOperations(accountID: "user-a").count
            XCTAssertLessThanOrEqual(appliedForA, 1, "iteration \(iteration): at most one apply")
            XCTAssertEqual(
                appliedForA + preservedForA,
                1,
                "iteration \(iteration): the operation must be exactly applied-or-preserved, never lost or duplicated"
            )
            for call in transport.calls.dropFirst() {
                XCTAssertEqual(call.operation.accountID, "user-b", "iteration \(iteration)")
            }
        }
    }

    // MARK: 18. No credential material in persisted operations or diagnostics

    func testPersistedQueueAndDiagnosticsContainNoCredentialMaterial() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-privacy-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileStore = FileSyncOperationStore(directoryURL: directory)
        let heldTransport = MockLibrarySyncTransport()
        heldTransport.behavior = { _, _ in .hold }
        let engine = makeSyncEngine(store: fileStore, transport: heldTransport, notificationCenter: center)
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        _ = await engine.enqueueLibraryStatusUpdate(makeStatusRequest())

        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1)

        // The account ID never appears in the file name (hashed).
        XCTAssertFalse(files[0].lastPathComponent.contains("user-a"))

        let contents = try XCTUnwrap(String(data: Data(contentsOf: files[0]), encoding: .utf8))
        for forbidden in ["bearer", "authorization", "token", "password", "email", "@"] {
            XCTAssertFalse(
                contents.lowercased().contains(forbidden),
                "persisted queue must not contain credential-shaped content: \(forbidden)"
            )
        }

        // Diagnostics expose only counters, booleans, generations, and a
        // static error code.
        let snapshot = await engine.diagnosticsSnapshot()
        if let code = snapshot.lastSafeErrorCode {
            XCTAssertTrue(code.allSatisfy { $0.isUppercase || $0 == "_" || $0.isNumber })
        }
    }
}
