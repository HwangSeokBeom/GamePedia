import XCTest
@testable import GamePedia

// H1 — account-switch isolation in LibrarySyncEngine.
//
// The account-load gate must guarantee that the in-memory queue never mixes
// two accounts across the load suspension, that enqueues arriving during an
// unresolved load wait and land against the fully adopted queue, that stale
// loads commit nothing, and that persisted files stay account-pure under
// repeated switch races.
final class LibrarySyncAccountIsolationTests: XCTestCase {

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

    private func makeOperation(
        accountID: String,
        gameID: String = "42",
        isFavorite: Bool = true
    ) -> LibrarySyncOperation {
        LibrarySyncOperation(
            id: UUID(),
            accountID: accountID,
            kind: .setFavorite(gameID: gameID, isFavorite: isFavorite),
            createdAt: Date(timeIntervalSince1970: 500)
        )
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

    /// Issues a session change and returns only after its (held) store load
    /// has started, so racing switches enter the engine in a known order.
    private func startSessionChange(
        _ engine: LibrarySyncEngine,
        userID: String,
        expectedLoadIndex: Int
    ) async -> Task<Void, Never> {
        let loadStarted = expectation(description: "load \(expectedLoadIndex) started")
        store.onLoad = { index in
            if index == expectedLoadIndex { loadStarted.fulfill() }
        }
        let task = Task { await engine.sessionDidChange(isAuthenticated: true, userID: userID) }
        await fulfillment(of: [loadStarted], timeout: 10)
        return task
    }

    // MARK: - Tests

    func testEnqueueDuringSuspendedLoadWaitsAndLandsAccountPure() async {
        // A's queue exists on disk; transport holds so nothing completes.
        store.seed([makeOperation(accountID: "user-a", gameID: "1")], accountID: "user-a")
        transport.behavior = { _, _ in .hold }
        let engine = makeEngine()
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        // Switch to B with B's load suspended.
        store.holdLoads = true
        let loadStarted = expectation(description: "B load started")
        store.onLoad = { index in
            if index == 1 { loadStarted.fulfill() }
        }
        let switchTask = Task { await engine.sessionDidChange(isAuthenticated: true, userID: "user-b") }
        await fulfillment(of: [loadStarted], timeout: 10)

        // Enqueue B work while the load is unresolved: it must suspend.
        let enqueueTask = Task { await engine.enqueueFavoriteChange(gameID: "7", isFavorite: true) }
        await waitForLoadWaiters(engine, count: 1)
        let pendingDuringLoad = await engine.pendingOperationCount
        XCTAssertEqual(pendingDuringLoad, 0, "no operation may be visible while the load is unresolved")

        store.resolveHeldLoad(index: 1)
        let result = await enqueueTask.value
        await switchTask.value
        XCTAssertEqual(result, .accepted)

        // Memory and disk are B-pure; A's file is untouched.
        let pending = await engine.pendingOperations
        XCTAssertEqual(pending.map(\.accountID), ["user-b"])
        XCTAssertTrue(store.storedOperations(accountID: "user-b").allSatisfy { $0.accountID == "user-b" })
        XCTAssertEqual(store.storedOperations(accountID: "user-b").count, 1)
        XCTAssertEqual(store.storedOperations(accountID: "user-a").count, 1)
        XCTAssertEqual(store.storedOperations(accountID: "user-a").first?.accountID, "user-a")
    }

    func testOverlappingSwitchesOnlyTheNewestLoadCommits() async {
        // A → B → A with every load suspended; only the final A load may
        // commit anything.
        store.seed([makeOperation(accountID: "user-a", gameID: "1")], accountID: "user-a")
        store.seed([makeOperation(accountID: "user-b", gameID: "2")], accountID: "user-b")
        store.holdLoads = true
        transport.behavior = { _, _ in .hold }
        let engine = makeEngine()

        // Sequence the switches deterministically: each one suspends at its
        // held load before the next is issued.
        let first = await startSessionChange(engine, userID: "user-a", expectedLoadIndex: 0)
        let second = await startSessionChange(engine, userID: "user-b", expectedLoadIndex: 1)
        let third = await startSessionChange(engine, userID: "user-a", expectedLoadIndex: 2)

        // Stale loads resolve first and must commit nothing.
        store.resolveHeldLoad(index: 0)
        await first.value
        store.resolveHeldLoad(index: 1)
        await second.value
        var pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 0, "superseded loads must not adopt their queues")

        store.resolveHeldLoad(index: 2)
        await third.value
        pending = await engine.pendingOperationCount
        let operations = await engine.pendingOperations
        XCTAssertEqual(pending, 1)
        XCTAssertEqual(operations.map(\.accountID), ["user-a"])
    }

    func testLogoutDuringLoadCommitsNothingAndRejectsEnqueues() async {
        store.seed([makeOperation(accountID: "user-a", gameID: "1")], accountID: "user-a")
        store.holdLoads = true
        let engine = makeEngine()

        let loadStarted = expectation(description: "load started")
        store.onLoad = { _ in loadStarted.fulfill() }
        let login = Task { await engine.sessionDidChange(isAuthenticated: true, userID: "user-a") }
        await fulfillment(of: [loadStarted], timeout: 10)

        await engine.sessionDidChange(isAuthenticated: false, userID: nil)
        store.resolveHeldLoad(index: 0)
        await login.value

        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 0)
        let rejected = await engine.enqueueFavoriteChange(gameID: "9", isFavorite: true)
        XCTAssertEqual(rejected, .unavailable)
        // The persisted queue stays isolated on disk for A.
        XCTAssertEqual(store.storedOperations(accountID: "user-a").count, 1)
    }

    func testAccountDeletionDuringLoadPurgesAndCommitsNothing() async {
        store.seed([makeOperation(accountID: "user-a", gameID: "1")], accountID: "user-a")
        store.holdLoads = true
        let engine = makeEngine()

        let loadStarted = expectation(description: "load started")
        store.onLoad = { _ in loadStarted.fulfill() }
        let login = Task { await engine.sessionDidChange(isAuthenticated: true, userID: "user-a") }
        await fulfillment(of: [loadStarted], timeout: 10)

        await engine.accountDidDelete(userID: "user-a")
        store.resolveHeldLoad(index: 0)
        await login.value

        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 0)
        XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty)
        let snapshot = await engine.diagnosticsSnapshot()
        XCTAssertFalse(snapshot.hasActiveAccount)
    }

    func testSameAccountReauthDuringSuspendedLoadKeepsTheLoadAndNeverClobbers() async {
        // A credential refresh arriving while A's own load is still
        // suspended is a same-scope event: the in-flight load stays valid
        // (the generation did not advance), completes, and adopts A's
        // durable queue — no abandon, no second load, and a later enqueue
        // supersedes within the adopted queue instead of clobbering it.
        store.seed([makeOperation(accountID: "user-a", gameID: "1")], accountID: "user-a")
        store.holdLoads = true
        transport.behavior = { _, _ in .hold }
        let engine = makeEngine()

        let first = await startSessionChange(engine, userID: "user-a", expectedLoadIndex: 0)
        // Same-account refresh while the load is suspended: no new load may
        // start, and the suspended one must remain resolvable.
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        store.resolveHeldLoad(index: 0)
        await first.value

        let pending = await engine.pendingOperations
        XCTAssertEqual(pending.count, 1, "the surviving load must adopt A's durable queue exactly once")
        XCTAssertEqual(pending.first?.accountID, "user-a")
        XCTAssertEqual(store.heldLoadIndices, [], "no second load may be issued for a same-account refresh")

        // A new enqueue supersedes within the loaded queue, never clobbers.
        _ = await engine.enqueueFavoriteChange(gameID: "5", isFavorite: true)
        XCTAssertEqual(store.storedOperations(accountID: "user-a").count, 2)
    }

    func testStaleLoadCompletionCannotOverwriteNewerAcceptedOperations() async {
        // B's load resolves and B accepts new work; then A's older stale
        // load resolves and must not replace B's state.
        store.seed([makeOperation(accountID: "user-a", gameID: "1")], accountID: "user-a")
        store.holdLoads = true
        transport.behavior = { _, _ in .hold }
        let engine = makeEngine()

        let loginA = await startSessionChange(engine, userID: "user-a", expectedLoadIndex: 0)
        let loginB = await startSessionChange(engine, userID: "user-b", expectedLoadIndex: 1)

        // Newest (B) load resolves first; B accepts an operation.
        store.resolveHeldLoad(index: 1)
        await loginB.value
        let accepted = await engine.enqueueFavoriteChange(gameID: "7", isFavorite: true)
        XCTAssertEqual(accepted, .accepted)

        // The stale A load now completes: inert.
        store.resolveHeldLoad(index: 0)
        await loginA.value

        let pending = await engine.pendingOperations
        XCTAssertEqual(pending.map(\.accountID), ["user-b"])
        XCTAssertEqual(store.storedOperations(accountID: "user-b").map(\.accountID), ["user-b"])
    }

    func testRepeatedSwitchRacesKeepEveryPersistedArrayAccountPure() async {
        // 60 iterations of racing switches + enqueues; the store fake
        // verifies every single persisted array is pure for its file.
        transport.behavior = { _, _ in .hold }
        let engine = makeEngine()

        store.persistBehavior = { _, operations, accountID in
            if operations.allSatisfy({ $0.accountID == accountID }) == false {
                return MockStoreWriteError()
            }
            return nil
        }

        for iteration in 0..<60 {
            let accountA = "user-a-\(iteration % 3)"
            let accountB = "user-b-\(iteration % 3)"
            await engine.sessionDidChange(isAuthenticated: true, userID: accountA)
            let enqueueA = Task { await engine.enqueueFavoriteChange(gameID: "1", isFavorite: true) }
            let switchTask = Task { await engine.sessionDidChange(isAuthenticated: true, userID: accountB) }
            let enqueueB = Task { await engine.enqueueFavoriteChange(gameID: "2", isFavorite: false) }
            let resultA = await enqueueA.value
            await switchTask.value
            let resultB = await enqueueB.value
            XCTAssertNotEqual(resultA, .storageBlocked, "iteration \(iteration): a mixed-account array reached persist")
            XCTAssertNotEqual(resultB, .storageBlocked, "iteration \(iteration): a mixed-account array reached persist")

            // In-memory queue only ever holds the active account's work.
            let snapshotOps = await engine.pendingOperations
            let active = await engine.diagnosticsSnapshot()
            XCTAssertTrue(active.hasActiveAccount)
            XCTAssertTrue(
                snapshotOps.allSatisfy { $0.accountID == accountA || $0.accountID == accountB },
                "iteration \(iteration): foreign operations in memory"
            )
            let uniqueAccounts = Set(snapshotOps.map(\.accountID))
            XCTAssertLessThanOrEqual(uniqueAccounts.count, 1, "iteration \(iteration): mixed accounts in memory")
        }
    }
}
