import XCTest
@testable import GamePedia

// FINDING 2 — gesture order must never become Task order.
//
// A monotonically increasing intent sequence is assigned synchronously at
// gesture time, scoped by (account scope, entity). The engine compares
// gesture-time sequences — never Task-arrival order — so a later gesture
// always wins even when the scheduler runs its submission Task first, and a
// stale lower sequence can never replace a newer queued, in-flight, or
// completed intent.
//
// Deterministic throughout: staleness and inversions are produced by
// explicitly enqueueing captured ownerships out of order, in-flight windows
// park on transport continuations, and no assertion depends on wall-clock
// time.
final class LibraryIntentOrderingTests: XCTestCase {

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

    // MARK: 1 + 2 + 12. Sequences follow gesture order, per entity

    func testGestureSequencesAreAssignedInGestureOrderPerEntity() async throws {
        let engine = await makeAuthenticatedEngine()

        let add = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))
        let remove = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: false))
        let otherEntity = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "43", isFavorite: true))
        let statusIntent = try XCTUnwrap(engine.captureLibraryStatusIntent(makeStatusRequest()))

        XCTAssertEqual(add.sequence, 1)
        XCTAssertEqual(remove.sequence, 2)
        XCTAssertEqual(add.scopeID, remove.scopeID)
        // Distinct entities (and mutation families) order independently.
        XCTAssertEqual(otherEntity.sequence, 1)
        XCTAssertEqual(statusIntent.sequence, 1)
        XCTAssertEqual(add.intendedState, .favorite(isFavorite: true))
        XCTAssertEqual(remove.intendedState, .favorite(isFavorite: false))
    }

    // MARK: 3 + 4. Reversed submission keeps the newest gesture

    func testReversedTaskArrivalPersistsAndSubmitsOnlyTheNewestGesture() async throws {
        let engine = await makeAuthenticatedEngine()

        // Gesture order: add (1), then remove (2).
        let add = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))
        let remove = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: false))

        // The user's final intent — remove — is what syncs and persists.
        let applied = notificationExpectation(.favoriteDidChange, center: center) { notification in
            notification.userInfo?[FavoriteChangeUserInfoKey.isFavorite] as? Bool == false
        }

        // Scheduler inversion: the REMOVE submission reaches the engine
        // first, and the ADD submission arrives afterwards.
        let removeResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: false, ownership: remove)
        XCTAssertEqual(removeResult, .accepted)
        let addResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: add)
        XCTAssertEqual(addResult, .supersededByNewerIntent)

        await fulfillment(of: [applied], timeout: 10)
        XCTAssertEqual(transport.calls.count, 1, "the superseded add must never be submitted")
        if case .setFavorite(_, let isFavorite) = transport.calls[0].operation.kind {
            XCTAssertFalse(isFavorite)
        } else {
            XCTFail("unexpected operation kind")
        }
        XCTAssertEqual(transport.calls[0].operation.sequence, 2)
    }

    // MARK: 5. Three rapid gestures under fully reversed scheduling

    func testThreeRapidGesturesWithReversedSchedulingEndOnTheFinalGesture() async throws {
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine()
        let submissionStarted = expectation(description: "final gesture in flight")
        transport.onCall = { call in
            if call.index == 0 { submissionStarted.fulfill() }
        }

        // Gesture order: add (1), remove (2), add (3).
        let first = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))
        let second = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: false))
        let third = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))

        // Fully reversed scheduler: 3, then 2, then 1.
        let thirdResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: third)
        let secondResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: false, ownership: second)
        let firstResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: first)

        XCTAssertEqual(thirdResult, .accepted)
        XCTAssertEqual(secondResult, .supersededByNewerIntent)
        XCTAssertEqual(firstResult, .supersededByNewerIntent)

        // Exactly one submission: the final gesture (sequence 3, add).
        await fulfillment(of: [submissionStarted], timeout: 10)
        XCTAssertEqual(transport.calls.count, 1)
        XCTAssertEqual(transport.calls[0].operation.sequence, 3)
        transport.resolveHeldWithDefaultSuccess(index: 0)
    }

    // MARK: 6. Lower sequence arrives while a higher sequence is queued

    func testLowerSequenceArrivingWhileHigherSequenceIsQueuedIsRejected() async throws {
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine()

        let first = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))
        let second = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: false))
        let third = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))

        // Sequence 1 goes in flight (held); sequence 3 queues behind it.
        let firstInFlight = expectation(description: "sequence 1 in flight")
        transport.onCall = { call in
            if call.index == 0 { firstInFlight.fulfill() }
        }
        let firstResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: first)
        XCTAssertEqual(firstResult, .accepted)
        await fulfillment(of: [firstInFlight], timeout: 10)
        let thirdResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: third)
        XCTAssertEqual(thirdResult, .accepted)

        // Sequence 2 arrives late while 3 is QUEUED: rejected.
        let secondResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: false, ownership: second)
        XCTAssertEqual(secondResult, .supersededByNewerIntent)

        transport.resolveHeldWithDefaultSuccess(index: 0)
        let applied = notificationExpectation(.favoriteDidChange, center: center) { notification in
            notification.userInfo?[FavoriteChangeUserInfoKey.isFavorite] as? Bool == true
        }
        applied.expectedFulfillmentCount = 2
        transport.onCall = { [transport] call in
            if call.index == 1 { transport?.resolveHeldWithDefaultSuccess(index: 1) }
        }
        await fulfillment(of: [applied], timeout: 10)
        // Only sequences 1 and 3 were ever submitted, in FIFO order.
        XCTAssertEqual(transport.calls.map { $0.operation.sequence }, [1, 3])
    }

    // MARK: 7. Lower sequence arrives while a higher sequence is in flight

    func testLowerSequenceArrivingWhileHigherSequenceIsInFlightIsRejected() async throws {
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine()

        let first = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))
        let second = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: false))

        // Sequence 2 reaches the engine first and goes in flight (held).
        let inFlightStarted = expectation(description: "sequence 2 in flight")
        transport.onCall = { call in
            if call.index == 0 { inFlightStarted.fulfill() }
        }
        let secondResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: false, ownership: second)
        XCTAssertEqual(secondResult, .accepted)
        await fulfillment(of: [inFlightStarted], timeout: 10)
        let inFlight = await engine.inFlightOperationIDsSnapshot
        XCTAssertEqual(inFlight.count, 1)

        // Sequence 1 arrives while 2 is IN FLIGHT: rejected, not queued.
        let firstResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: first)
        XCTAssertEqual(firstResult, .supersededByNewerIntent)

        transport.resolveHeldWithDefaultSuccess(index: 0)
        let applied = notificationExpectation(.favoriteDidChange, center: center)
        await fulfillment(of: [applied], timeout: 10)
        XCTAssertEqual(transport.calls.count, 1)
        XCTAssertEqual(transport.calls[0].operation.sequence, 2)
    }

    // MARK: Lower sequence arrives after the higher sequence completed

    func testLowerSequenceCannotReplaceACompletedHigherSequence() async throws {
        let engine = await makeAuthenticatedEngine()

        let first = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))
        let second = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: false))

        // Sequence 2 completes fully before sequence 1 even arrives.
        let applied = notificationExpectation(.favoriteDidChange, center: center)
        let secondResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: false, ownership: second)
        XCTAssertEqual(secondResult, .accepted)
        await fulfillment(of: [applied], timeout: 10)

        let firstResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: first)
        XCTAssertEqual(firstResult, .supersededByNewerIntent)
        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 0, "the completed remove must remain the final intent")
        XCTAssertEqual(transport.calls.count, 1)
    }

    // MARK: 8. Failure of the lower sequence after the higher one is accepted

    func testLowerSequenceFailureRetainsSequenceOwnershipAndFlagsSupersession() async throws {
        transport.behavior = { _, index in
            index == 0 ? .hold : .success(nil)
        }
        let engine = await makeAuthenticatedEngine()

        let first = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))
        let second = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: false))

        // Sequence 1 goes in flight (held); sequence 2 queues behind it.
        let firstInFlight = expectation(description: "sequence 1 in flight")
        transport.onCall = { call in
            if call.index == 0 { firstInFlight.fulfill() }
        }
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: first)
        await fulfillment(of: [firstInFlight], timeout: 10)
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: false, ownership: second)

        // Sequence 1 fails permanently AFTER sequence 2 was accepted: the
        // failure notification retains the failed gesture's identity and
        // reports that a newer intent supersedes it, so observers must not
        // touch the newest optimistic state.
        let recorder = NotificationRecorder(center: center, names: [.librarySyncOperationDidFail])
        let failed = notificationExpectation(.librarySyncOperationDidFail, center: center)
        let newestApplied = notificationExpectation(.favoriteDidChange, center: center) { notification in
            notification.userInfo?[FavoriteChangeUserInfoKey.isFavorite] as? Bool == false
        }
        transport.resolveHeld(index: 0, with: .failure(FavoriteError.invalidGameId))
        await fulfillment(of: [failed, newestApplied], timeout: 10)

        let failureUserInfo = try XCTUnwrap(recorder.notifications.last?.userInfo)
        XCTAssertEqual(
            failureUserInfo[LibrarySyncFailureUserInfoKey.intendedIsFavorite] as? Bool,
            true,
            "the failure must carry the FAILED gesture's intended state"
        )
        XCTAssertEqual(
            failureUserInfo[LibrarySyncFailureUserInfoKey.supersededByNewerIntent] as? Bool,
            true,
            "observers must know the newest intent still governs"
        )
        XCTAssertEqual(transport.calls.map { $0.operation.sequence }, [1, 2])
    }

    // MARK: 9. Account switch invalidates prior ordering

    func testAccountSwitchInvalidatesPriorOrderingAndRestartsSequences() async throws {
        let engine = await makeAuthenticatedEngine(accountID: "user-a")
        let oldCapture = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))
        XCTAssertEqual(oldCapture.sequence, 1)

        await engine.sessionDidChange(isAuthenticated: true, userID: "user-b")

        // The old scope's ordering is dead…
        let staleResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: oldCapture)
        XCTAssertEqual(staleResult, .staleOwnership)

        // …and B's ordering for the SAME entity starts fresh, unblocked by
        // A's history.
        let freshCapture = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: false))
        XCTAssertEqual(freshCapture.sequence, 1)
        XCTAssertNotEqual(freshCapture.scopeID, oldCapture.scopeID)
        let freshResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: false, ownership: freshCapture)
        XCTAssertEqual(freshResult, .accepted)
    }

    // MARK: 10. Restart restores ordering; new gestures supersede persisted intents

    func testRestartPersistsOrderingFieldsAndNewGestureSupersedesReloadedIntent() async throws {
        transport.behavior = { _, _ in .hold }
        let engineBeforeRestart = await makeAuthenticatedEngine(accountID: "user-a")

        let capture = try XCTUnwrap(engineBeforeRestart.captureFavoriteIntent(gameID: "42", isFavorite: true))
        let accepted = await engineBeforeRestart.enqueueFavoriteChange(
            gameID: "42",
            isFavorite: true,
            ownership: capture
        )
        XCTAssertEqual(accepted, .accepted)

        // The durable record carries the ordering fields.
        let persisted = store.storedOperations(accountID: "user-a")
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted[0].sequence, 1)
        XCTAssertEqual(persisted[0].scopeID, capture.scopeID.uuidString)

        // "Restart": a new engine over the same store, same account.
        let transport2 = MockLibrarySyncTransport()
        transport2.behavior = { _, _ in .hold }
        let engineAfterRestart = makeSyncEngine(store: store, transport: transport2, notificationCenter: center)
        let replayStarted = expectation(description: "persisted operation replays")
        transport2.onCall = { call in
            if call.index == 0 { replayStarted.fulfill() }
        }
        await engineAfterRestart.sessionDidChange(isAuthenticated: true, userID: "user-a")
        await fulfillment(of: [replayStarted], timeout: 10)

        // The reloaded operation kept its pre-restart ordering identity…
        XCTAssertEqual(transport2.calls[0].operation.sequence, 1)
        XCTAssertEqual(transport2.calls[0].operation.scopeID, capture.scopeID.uuidString)

        // …and a fresh post-restart gesture (new scope) supersedes it
        // deterministically: it is accepted and queues as the newest intent.
        let freshCapture = try XCTUnwrap(engineAfterRestart.captureFavoriteIntent(gameID: "42", isFavorite: false))
        XCTAssertEqual(freshCapture.sequence, 1)
        XCTAssertNotEqual(freshCapture.scopeID.uuidString, capture.scopeID.uuidString)
        let freshResult = await engineAfterRestart.enqueueFavoriteChange(
            gameID: "42",
            isFavorite: false,
            ownership: freshCapture
        )
        XCTAssertEqual(freshResult, .accepted)

        // FIFO replay: old intent first, then the newest wins last.
        let bothApplied = notificationExpectation(.favoriteDidChange, center: center)
        bothApplied.expectedFulfillmentCount = 2
        transport2.onCall = { call in
            if call.index == 1 { transport2.resolveHeldWithDefaultSuccess(index: 1) }
        }
        transport2.resolveHeldWithDefaultSuccess(index: 0)
        await fulfillment(of: [bothApplied], timeout: 10)
        if case .setFavorite(_, let finalIsFavorite) = transport2.calls[1].operation.kind {
            XCTAssertFalse(finalIsFavorite, "the newest gesture must be the last submitted intent")
        } else {
            XCTFail("unexpected operation kind")
        }
    }

    // MARK: Migration — legacy records without ordering fields

    func testLegacyPersistedOperationDecodesWithDeterministicOrderingDefaults() throws {
        let legacyJSON = """
        {
            "id": "6F1D9E9E-51B5-4E4E-9C9F-3D9D3E2A0A01",
            "accountID": "user-a",
            "kind": {"setFavorite": {"gameID": "42", "isFavorite": true}},
            "createdAt": 1000
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let operation = try decoder.decode(LibrarySyncOperation.self, from: Data(legacyJSON.utf8))

        XCTAssertNil(operation.scopeID)
        XCTAssertEqual(operation.sequence, 0)
        XCTAssertEqual(operation.state, .queued)

        // Round-trip: the new fields persist and decode unchanged.
        let modern = LibrarySyncOperation(
            id: UUID(),
            accountID: "user-a",
            kind: .setFavorite(gameID: "9", isFavorite: false),
            createdAt: Date(timeIntervalSince1970: 2_000),
            scopeID: UUID().uuidString,
            sequence: 7
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(
            LibrarySyncOperation.self,
            from: try encoder.encode(modern)
        )
        XCTAssertEqual(decoded, modern)
    }

    func testNewGestureDeterministicallySupersedesLegacyOperationWithoutSequence() async throws {
        // A pre-ownership record (no scope, no sequence) sits in the queue.
        store.seed(
            [
                LibrarySyncOperation(
                    id: UUID(),
                    accountID: "user-a",
                    kind: .setFavorite(gameID: "42", isFavorite: true),
                    createdAt: Date(timeIntervalSince1970: 500)
                )
            ],
            accountID: "user-a"
        )
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine(accountID: "user-a")

        // A new gesture is never blocked by the legacy record: sequences are
        // only comparable within one scope id.
        let capture = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: false))
        let result = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: false, ownership: capture)
        XCTAssertEqual(result, .accepted)
    }

    // MARK: 11. Same entity across different accounts stays isolated

    func testSameEntityAcrossAccountsKeepsIndependentOrderingAndQueues() async throws {
        let engineA = await makeAuthenticatedEngine(accountID: "user-a")
        let captureA = try XCTUnwrap(engineA.captureFavoriteIntent(gameID: "42", isFavorite: true))
        let appliedA = notificationExpectation(.favoriteDidChange, center: center)
        let resultA = await engineA.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: captureA)
        XCTAssertEqual(resultA, .accepted)
        await fulfillment(of: [appliedA], timeout: 10)

        await engineA.sessionDidChange(isAuthenticated: true, userID: "user-b")

        // B's first gesture for the SAME entity: sequence 1 in B's scope,
        // accepted into B's queue, blind to A's settled sequence.
        let captureB = try XCTUnwrap(engineA.captureFavoriteIntent(gameID: "42", isFavorite: false))
        XCTAssertEqual(captureB.sequence, 1)
        let resultB = await engineA.enqueueFavoriteChange(gameID: "42", isFavorite: false, ownership: captureB)
        XCTAssertEqual(resultB, .accepted)
    }

    // MARK: 12. Different entities proceed independently

    func testDifferentEntitiesProceedIndependently() async throws {
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine()
        let bothSubmitted = expectation(description: "both entities in flight")
        bothSubmitted.expectedFulfillmentCount = 2
        transport.onCall = { _ in bothSubmitted.fulfill() }

        let first = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))
        let second = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "43", isFavorite: true))

        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: first)
        _ = await engine.enqueueFavoriteChange(gameID: "43", isFavorite: true, ownership: second)

        // Both entities sync in parallel — two independent held requests.
        await fulfillment(of: [bothSubmitted], timeout: 10)
        let bothInFlight = await engine.inFlightOperationIDsSnapshot
        XCTAssertEqual(bothInFlight.count, 2)
        transport.resolveHeldWithDefaultSuccess(index: 0)
        transport.resolveHeldWithDefaultSuccess(index: 1)
    }

    // MARK: 13. Fifty deterministic scheduler inversions

    func testFiftyDeterministicSchedulerInversionsNeverReverseUserIntent() async throws {
        for iteration in 0..<50 {
            center = NotificationCenter()
            store = InMemorySyncOperationStore()
            transport = MockLibrarySyncTransport()
            let holdFirst = iteration.isMultiple(of: 2)
            transport.behavior = { _, index in
                (holdFirst && index == 0) ? .hold : .success(nil)
            }
            let engine = await makeAuthenticatedEngine()

            // Gesture order: add (1), remove (2). Scheduler order: reversed.
            let add = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: true))
            let remove = try XCTUnwrap(engine.captureFavoriteIntent(gameID: "42", isFavorite: false))

            let removeApplied = notificationExpectation(.favoriteDidChange, center: center) { notification in
                notification.userInfo?[FavoriteChangeUserInfoKey.isFavorite] as? Bool == false
            }
            let removeSubmitted = expectation(description: "iteration \(iteration): remove submitted")
            transport.onCall = { call in
                if call.index == 0 { removeSubmitted.fulfill() }
            }

            let removeResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: false, ownership: remove)
            XCTAssertEqual(removeResult, .accepted, "iteration \(iteration)")

            if holdFirst {
                // Odd-shaped interleaving: the late ADD arrives while the
                // newer REMOVE is still in flight (the hold is only released
                // once the submission is deterministically parked).
                let addResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: add)
                XCTAssertEqual(addResult, .supersededByNewerIntent, "iteration \(iteration)")
                await fulfillment(of: [removeSubmitted], timeout: 10)
                transport.resolveHeldWithDefaultSuccess(index: 0)
                await fulfillment(of: [removeApplied], timeout: 10)
            } else {
                // Even-shaped interleaving: the late ADD arrives after the
                // newer REMOVE already completed and was cleaned up.
                await fulfillment(of: [removeSubmitted, removeApplied], timeout: 10)
                let addResult = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true, ownership: add)
                XCTAssertEqual(addResult, .supersededByNewerIntent, "iteration \(iteration)")
            }

            // The reversed scheduler never resurrected the older gesture.
            XCTAssertEqual(transport.calls.count, 1, "iteration \(iteration)")
            XCTAssertEqual(transport.calls[0].operation.sequence, 2, "iteration \(iteration)")
            let pending = await engine.pendingOperationCount
            XCTAssertEqual(pending, 0, "iteration \(iteration): the stale add must not remain queued")
        }
    }
}
