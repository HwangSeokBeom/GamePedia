import XCTest
@testable import GamePedia

// Durable account-scoped live-service state (2.4): restart recovery,
// account isolation, rollback-safe schema versioning, corruption
// quarantine, and account-deletion purge — the same storage contract the
// 2.2 sync queue proved, now generic.
final class AccountScopedStateStoreTests: XCTestCase {

    private struct Payload: Codable, Equatable, Sendable {
        var value: String
    }

    private var directoryURL: URL!

    override func setUp() {
        super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("live-service-store-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        super.tearDown()
    }

    private func makeStore(schemaVersion: Int = 1) -> AccountScopedStateStore<Payload> {
        AccountScopedStateStore<Payload>(
            filePrefix: "test-state",
            schemaVersion: schemaVersion,
            directoryURL: directoryURL
        )
    }

    private func fileURL(accountID: String, schemaVersion: Int = 1) -> URL {
        directoryURL.appendingPathComponent(
            "test-state.v\(schemaVersion).\(AccountScopedStateStore<Payload>.accountFileComponent(accountID)).json"
        )
    }

    // MARK: Round trip + restart

    func test_persistAndLoad_roundTrips() async {
        let store = makeStore()
        await store.persist(Payload(value: "hello"), accountID: "acct-1")

        let result = await store.load(accountID: "acct-1")
        XCTAssertEqual(result.payload, Payload(value: "hello"))
        XCTAssertFalse(result.recoveredFromCorruption)
    }

    func test_processRestart_recoversPersistedState() async {
        await makeStore().persist(Payload(value: "survives"), accountID: "acct-1")

        // A fresh store instance over the same directory simulates a
        // process restart.
        let restarted = makeStore()
        let result = await restarted.load(accountID: "acct-1")
        XCTAssertEqual(result.payload, Payload(value: "survives"))
    }

    func test_missingFile_loadsEmpty() async {
        let result = await makeStore().load(accountID: "acct-none")
        XCTAssertNil(result.payload)
        XCTAssertFalse(result.recoveredFromCorruption)
    }

    // MARK: Account isolation

    func test_accounts_areIsolated() async {
        let store = makeStore()
        await store.persist(Payload(value: "first"), accountID: "acct-1")
        await store.persist(Payload(value: "second"), accountID: "acct-2")

        let first = await store.load(accountID: "acct-1")
        let second = await store.load(accountID: "acct-2")
        XCTAssertEqual(first.payload?.value, "first")
        XCTAssertEqual(second.payload?.value, "second")
    }

    func test_fileNames_neverExposeAccountIDs() async {
        let accountID = "very-private-account-id"
        await makeStore().persist(Payload(value: "x"), accountID: accountID)

        let fileNames = (try? FileManager.default.contentsOfDirectory(atPath: directoryURL.path)) ?? []
        XCTAssertFalse(fileNames.isEmpty)
        for name in fileNames {
            XCTAssertFalse(name.contains(accountID))
        }
    }

    // MARK: Corruption + schema safety

    func test_corruptedFile_isQuarantined_andLoadsEmpty() async throws {
        let store = makeStore()
        await store.persist(Payload(value: "x"), accountID: "acct-1")
        let url = fileURL(accountID: "acct-1")
        try Data("not json at all".utf8).write(to: url)

        let result = await store.load(accountID: "acct-1")
        XCTAssertNil(result.payload)
        XCTAssertTrue(result.recoveredFromCorruption)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.appendingPathExtension("corrupt").path),
            "corrupted file must be preserved for diagnosis"
        )

        // Recovery is stable: the next load starts clean.
        let second = await store.load(accountID: "acct-1")
        XCTAssertNil(second.payload)
        XCTAssertFalse(second.recoveredFromCorruption)
    }

    func test_schemaVersionMismatchInsideFile_isTreatedAsCorruption() async throws {
        let store = makeStore()
        // A v1-named file whose body claims v2 was tampered with or
        // mis-written; the reader must refuse it.
        let bogus = #"{"schemaVersion":2,"payload":{"value":"x"}}"#
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data(bogus.utf8).write(to: fileURL(accountID: "acct-1"))

        let result = await store.load(accountID: "acct-1")
        XCTAssertNil(result.payload)
        XCTAssertTrue(result.recoveredFromCorruption)
    }

    func test_rollbackSafety_oldReaderNeverOpensNewSchemaFiles() async {
        let newStore = makeStore(schemaVersion: 2)
        await newStore.persist(Payload(value: "future"), accountID: "acct-1")

        // A v1 reader (rollback) sees no file at all: the newer schema's
        // data is untouched and unparsed.
        let oldStore = makeStore(schemaVersion: 1)
        let result = await oldStore.load(accountID: "acct-1")
        XCTAssertNil(result.payload)
        XCTAssertFalse(result.recoveredFromCorruption)

        let v2Result = await newStore.load(accountID: "acct-1")
        XCTAssertEqual(v2Result.payload?.value, "future")
    }

    // MARK: Purge

    func test_purge_removesStateAndQuarantinedCopies() async throws {
        let store = makeStore()
        await store.persist(Payload(value: "x"), accountID: "acct-1")
        let url = fileURL(accountID: "acct-1")
        try Data("garbage".utf8).write(to: url)
        _ = await store.load(accountID: "acct-1") // quarantines
        await store.persist(Payload(value: "y"), accountID: "acct-1")

        await store.purge(accountID: "acct-1")

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.appendingPathExtension("corrupt").path))
    }

    func test_purge_leavesOtherAccountsUntouched() async {
        let store = makeStore()
        await store.persist(Payload(value: "keep"), accountID: "acct-2")
        await store.persist(Payload(value: "drop"), accountID: "acct-1")

        await store.purge(accountID: "acct-1")

        let kept = await store.load(accountID: "acct-2")
        XCTAssertEqual(kept.payload?.value, "keep")
    }
}

// Read-state semantics layered on the generic store: monotonic watermark,
// restart persistence, purge on account deletion.
final class ActivityReadStateStoreTests: XCTestCase {

    private var directoryURL: URL!

    override func setUp() {
        super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("read-state-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        super.tearDown()
    }

    func test_defaultState_isEmpty() async {
        let store = ActivityReadStateStore(directoryURL: directoryURL)
        let state = await store.readState(accountID: "acct-1")
        XCTAssertNil(state.readWatermark)
    }

    func test_advanceWatermark_persists_andSurvivesRestart() async {
        let watermark = Date(timeIntervalSince1970: 5_000)
        await ActivityReadStateStore(directoryURL: directoryURL)
            .advanceWatermark(to: watermark, accountID: "acct-1")

        let restarted = ActivityReadStateStore(directoryURL: directoryURL)
        let state = await restarted.readState(accountID: "acct-1")
        XCTAssertEqual(state.readWatermark, watermark)
    }

    func test_watermark_onlyMovesForward() async {
        let store = ActivityReadStateStore(directoryURL: directoryURL)
        await store.advanceWatermark(to: Date(timeIntervalSince1970: 5_000), accountID: "acct-1")
        await store.advanceWatermark(to: Date(timeIntervalSince1970: 1_000), accountID: "acct-1")

        let state = await store.readState(accountID: "acct-1")
        XCTAssertEqual(state.readWatermark, Date(timeIntervalSince1970: 5_000))
    }

    func test_watermarks_areAccountScoped() async {
        let store = ActivityReadStateStore(directoryURL: directoryURL)
        await store.advanceWatermark(to: Date(timeIntervalSince1970: 5_000), accountID: "acct-1")

        let other = await store.readState(accountID: "acct-2")
        XCTAssertNil(other.readWatermark, "one account's read state must never leak to another")
    }

    func test_purge_removesReadState_includingCachedCopy() async {
        let store = ActivityReadStateStore(directoryURL: directoryURL)
        await store.advanceWatermark(to: Date(timeIntervalSince1970: 5_000), accountID: "acct-1")

        await store.purge(accountID: "acct-1")

        let inMemory = await store.readState(accountID: "acct-1")
        XCTAssertNil(inMemory.readWatermark)

        let restarted = ActivityReadStateStore(directoryURL: directoryURL)
        let reloaded = await restarted.readState(accountID: "acct-1")
        XCTAssertNil(reloaded.readWatermark)
    }
}
