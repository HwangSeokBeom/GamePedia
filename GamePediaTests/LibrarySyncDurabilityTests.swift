import XCTest
@testable import GamePedia

// H2 — durable queue acknowledgement.
//
// Enqueue may only report `.accepted` after the queue file is written; a
// failed write reports `.storageBlocked` and leaves memory identical to
// disk. A completed operation transitions queued → remotelyConfirmed →
// locally cleaned; a failed cleanup write retains the confirmed record
// (never replayed) and retries the removal on later writes and at reload.
final class LibrarySyncDurabilityTests: XCTestCase {

    private var store: InMemorySyncOperationStore!
    private var transport: MockLibrarySyncTransport!
    private var center: NotificationCenter!

    override func setUp() {
        super.setUp()
        store = InMemorySyncOperationStore()
        transport = MockLibrarySyncTransport()
        center = NotificationCenter()
    }

    private func makeEngine() -> LibrarySyncEngine {
        makeSyncEngine(store: store, transport: transport, notificationCenter: center)
    }

    private func makeAuthenticatedEngine() async -> LibrarySyncEngine {
        let engine = makeEngine()
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")
        return engine
    }

    // MARK: - Enqueue acknowledgement

    func testInitialQueueWriteFailureReportsStorageBlockedAndCommitsNothing() async {
        store.persistBehavior = { index, _, _ in index == 0 ? MockStoreWriteError() : nil }
        transport.behavior = { _, _ in .hold }
        let engine = await makeAuthenticatedEngine()

        let recorder = NotificationRecorder(
            center: center,
            names: [.librarySyncQueueDidChange]
        )
        let result = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)

        XCTAssertEqual(result, .storageBlocked)
        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 0, "a non-durable intent must not stay in memory")
        XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty)
        XCTAssertEqual(
            recorder.count(of: .librarySyncQueueDidChange), 0,
            "no queue-accepted signal may fire for a rejected enqueue"
        )

        // The next intent (write succeeds) is accepted normally.
        let second = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        XCTAssertEqual(second, .accepted)
        XCTAssertEqual(store.storedOperations(accountID: "user-a").count, 1)
    }

    func testDiskFullAndProtectedDataStyleFailuresBothBlockAcknowledgement() async {
        let injected: [Error] = [
            CocoaError(.fileWriteOutOfSpace),
            CocoaError(.fileWriteNoPermission)
        ]
        for error in injected {
            let store = InMemorySyncOperationStore()
            store.persistBehavior = { _, _, _ in error }
            let engine = makeSyncEngine(store: store, transport: transport, notificationCenter: center)
            await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

            let result = await engine.enqueueFavoriteChange(gameID: "1", isFavorite: true)
            XCTAssertEqual(result, .storageBlocked, "\(error) must block the acknowledgement")
            let pending = await engine.pendingOperationCount
            XCTAssertEqual(pending, 0)
        }
    }

    func testStorageBlockedEnqueueRestoresSupersededOperationExactly() async {
        // A durable, parked (pending, not in-flight) op exists; a newer
        // intent for the same entity supersedes it in the write candidate,
        // but that write fails. The superseded op must survive in memory AND
        // on disk, or a restart would lose the only durable intent.
        transport.behavior = { _, _ in .failure(LibrarySyncFailure.transient(code: "NETWORK")) }
        let engine = makeSyncEngine(
            store: store,
            transport: transport,
            notificationCenter: center,
            maxAutomaticAttempts: 1
        )
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        let parked = notificationExpectation(.librarySyncQueueDidChange, center: center) { notification in
            (notification.userInfo?[LibrarySyncQueueUserInfoKey.parkedCount] as? Int) == 1
        }
        _ = await engine.enqueueFavoriteChange(gameID: "77", isFavorite: true)
        await fulfillment(of: [parked], timeout: 10)

        store.persistBehavior = { _, _, _ in MockStoreWriteError() }
        let result = await engine.enqueueFavoriteChange(gameID: "77", isFavorite: false)

        XCTAssertEqual(result, .storageBlocked)
        let pending = await engine.pendingOperations
        XCTAssertEqual(pending.count, 1)
        if case .setFavorite(_, let isFavorite) = pending.first?.kind {
            XCTAssertTrue(isFavorite, "the superseded intent must be restored verbatim")
        } else {
            XCTFail("superseded operation missing after failed write")
        }
        XCTAssertEqual(store.storedOperations(accountID: "user-a").count, 1)
    }

    // MARK: - Cleanup semantics

    func testCleanupWriteFailureAfterServerSuccessNeverLosesTheConfirmation() async {
        // persist #0: enqueue write (ok). persist #1: cleanup write (fails).
        store.persistBehavior = { index, _, _ in index == 1 ? MockStoreWriteError() : nil }
        let engine = await makeAuthenticatedEngine()

        let confirmed = notificationExpectation(.favoriteDidChange, center: center)
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [confirmed], timeout: 10)

        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 0, "a confirmed operation is no longer pending")
        let cleanupPending = await engine.cleanupPendingOperations
        XCTAssertEqual(cleanupPending.count, 1)
        XCTAssertEqual(cleanupPending.first?.state, .remotelyConfirmed)
        XCTAssertEqual(transport.calls.count, 1)
        // Disk still holds the record (pre-cleanup write) — the operation is
        // NOT silently deleted while its cleanup is uncertain.
        XCTAssertEqual(store.storedOperations(accountID: "user-a").count, 1)
    }

    func testLaterSuccessfulWriteRetriesTheCleanupWithoutReplayingTheMutation() async {
        store.persistBehavior = { index, _, _ in index == 1 ? MockStoreWriteError() : nil }
        let engine = await makeAuthenticatedEngine()

        let confirmed = notificationExpectation(.favoriteDidChange, center: center)
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [confirmed], timeout: 10)

        // A later operation completes; its cleanup write also sweeps the
        // earlier confirmed leftover.
        let secondConfirmed = notificationExpectation(.favoriteDidChange, center: center)
        _ = await engine.enqueueFavoriteChange(gameID: "77", isFavorite: true)
        await fulfillment(of: [secondConfirmed], timeout: 10)

        let cleanupPending = await engine.cleanupPendingOperations
        XCTAssertTrue(cleanupPending.isEmpty, "a successful write must finish the pending cleanup")
        XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty)
        XCTAssertEqual(
            transport.calls.map(\.operation.gameIDDescription), ["42", "77"],
            "the confirmed operation must never be replayed over the network"
        )
    }

    func testRestartAfterDurableConfirmationDropsTheRecordWithoutReplay() async {
        // Simulate a crash after the confirmed marker reached disk but
        // before the cleanup write: the restarted engine must remove the
        // record without any network call.
        let confirmedOperation = LibrarySyncOperation(
            id: UUID(),
            accountID: "user-a",
            kind: .setFavorite(gameID: "42", isFavorite: true),
            createdAt: Date(timeIntervalSince1970: 500),
            state: .remotelyConfirmed
        )
        store.seed([confirmedOperation], accountID: "user-a")
        let engine = await makeAuthenticatedEngine()

        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 0)
        XCTAssertTrue(
            store.storedOperations(accountID: "user-a").isEmpty,
            "reload retries the cleanup for confirmed leftovers"
        )
        XCTAssertTrue(transport.calls.isEmpty, "a confirmed record must never replay")
        _ = engine
    }

    func testRestartAfterCleanupFailureWithoutDurableMarkerReplaysConvergently() async {
        // The documented fallback: when the crash predates any durable
        // confirmation, the record is still `queued` on disk and replays —
        // the committed REST mutations are absolute-state and convergent.
        let queuedOperation = LibrarySyncOperation(
            id: UUID(),
            accountID: "user-a",
            kind: .setFavorite(gameID: "42", isFavorite: true),
            createdAt: Date(timeIntervalSince1970: 500)
        )
        store.seed([queuedOperation], accountID: "user-a")

        let replayed = notificationExpectation(.favoriteDidChange, center: center)
        let engine = await makeAuthenticatedEngine()
        await fulfillment(of: [replayed], timeout: 10)

        XCTAssertEqual(transport.calls.count, 1)
        XCTAssertEqual(transport.calls.first?.operation.id, queuedOperation.id)
        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 0)
    }

    // MARK: - Schema compatibility

    func testOperationWithoutStateFieldDecodesAsQueued() throws {
        // Files written before the durable-state field existed (and files a
        // rolled-back writer would produce) decode as `queued` — the safe,
        // convergent default.
        let json = """
        {
            "id": "6F9619FF-8B86-D011-B42D-00C04FC964FF",
            "accountID": "user-a",
            "kind": {"setFavorite": {"gameID": "42", "isFavorite": true}},
            "createdAt": "2026-01-01T00:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let operation = try decoder.decode(LibrarySyncOperation.self, from: Data(json.utf8))
        XCTAssertEqual(operation.state, .queued)
    }

    func testConfirmedStateRoundTripsThroughThePersistedEncoding() throws {
        let operation = LibrarySyncOperation(
            id: UUID(),
            accountID: "user-a",
            kind: .setFavorite(gameID: "42", isFavorite: true),
            createdAt: Date(timeIntervalSince1970: 500),
            state: .remotelyConfirmed
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LibrarySyncOperation.self, from: encoder.encode(operation))
        XCTAssertEqual(decoded, operation)
        XCTAssertEqual(decoded.state, .remotelyConfirmed)
    }

    // MARK: - Real file store

    func testFileStorePersistThrowsWhenTheDirectoryCannotBeCreated() async {
        // A file blocks the directory path, so createDirectory fails — a
        // deterministic stand-in for an unwritable disk.
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-durability-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let blockedDirectory = base.appendingPathComponent("blocked", isDirectory: true)
        FileManager.default.createFile(atPath: blockedDirectory.path, contents: Data("x".utf8))

        let fileStore = FileSyncOperationStore(directoryURL: blockedDirectory)
        let operation = LibrarySyncOperation(
            id: UUID(),
            accountID: "user-a",
            kind: .setFavorite(gameID: "42", isFavorite: true),
            createdAt: Date(timeIntervalSince1970: 500)
        )
        do {
            try await fileStore.persist([operation], accountID: "user-a")
            XCTFail("persist into an unwritable location must throw")
        } catch {
            // Expected: the durability failure is surfaced, not swallowed.
        }
    }

    func testFileStoreWritesRemainReadableWithProtectionOptionApplied() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-durability-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileStore = FileSyncOperationStore(directoryURL: directory)
        let operation = LibrarySyncOperation(
            id: UUID(),
            accountID: "user-a",
            kind: .setFavorite(gameID: "42", isFavorite: true),
            createdAt: Date(timeIntervalSince1970: 500)
        )
        try await fileStore.persist([operation], accountID: "user-a")
        let result = await fileStore.load(accountID: "user-a")
        XCTAssertEqual(result.operations, [operation])
    }
}
