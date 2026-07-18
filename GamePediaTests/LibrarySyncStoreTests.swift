import XCTest
@testable import GamePedia

// MARK: - FileSyncOperationStore persistence, migration, and corruption

final class LibrarySyncStoreTests: XCTestCase {

    private var directory: URL!
    private var store: FileSyncOperationStore!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-store-\(UUID().uuidString)", isDirectory: true)
        store = FileSyncOperationStore(directoryURL: directory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func makeOperation(accountID: String = "user-a", gameID: String = "42") -> LibrarySyncOperation {
        LibrarySyncOperation(
            id: UUID(),
            accountID: accountID,
            kind: .setFavorite(gameID: gameID, isFavorite: true),
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
    }

    private func currentFileURL(accountID: String) -> URL {
        directory.appendingPathComponent(
            "library-sync-queue.v\(FileSyncOperationStore.currentSchemaVersion)."
                + FileSyncOperationStore.accountFileComponent(accountID) + ".json"
        )
    }

    func testPersistAndLoadRoundTripPreservesOperations() async {
        let operations = [makeOperation(), makeOperation(gameID: "7")]
        await store.persist(operations, accountID: "user-a")

        let result = await store.load(accountID: "user-a")
        XCTAssertEqual(result.operations, operations)
        XCTAssertFalse(result.recoveredFromCorruption)
    }

    func testAccountsAreIsolatedOnDisk() async {
        await store.persist([makeOperation(accountID: "user-a")], accountID: "user-a")
        await store.persist([makeOperation(accountID: "user-b", gameID: "9")], accountID: "user-b")

        let loadedA = await store.load(accountID: "user-a")
        let loadedB = await store.load(accountID: "user-b")
        XCTAssertEqual(loadedA.operations.map(\.accountID), ["user-a"])
        XCTAssertEqual(loadedB.operations.map(\.accountID), ["user-b"])
    }

    // MARK: 15. Local migration

    func testDecodingToleratesUnknownFieldsFromNewerMinorWriters() async throws {
        // Forward-compatible decode: a same-schema-version writer that added
        // extra optional fields must not break this reader.
        let operationID = UUID()
        let json = """
        {
          "schemaVersion": 1,
          "futureTopLevelField": "ignored",
          "operations": [
            {
              "id": "\(operationID.uuidString)",
              "accountID": "user-a",
              "createdAt": "2026-07-18T00:00:00Z",
              "futureOperationField": 7,
              "kind": { "setFavorite": { "gameID": "42", "isFavorite": true } }
            }
          ]
        }
        """
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: currentFileURL(accountID: "user-a"))

        let result = await store.load(accountID: "user-a")
        XCTAssertEqual(result.operations.count, 1)
        XCTAssertEqual(result.operations[0].id, operationID)
        XCTAssertEqual(result.operations[0].kind, .setFavorite(gameID: "42", isFavorite: true))
        XCTAssertFalse(result.recoveredFromCorruption)
    }

    func testRollbackSafetyNeverTouchesAFutureSchemaVersionFile() async throws {
        // A future app version writes `.v2.` files; this (v1) store must
        // neither read nor destroy them.
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let futureURL = directory.appendingPathComponent(
            "library-sync-queue.v2."
                + FileSyncOperationStore.accountFileComponent("user-a") + ".json"
        )
        let futureContents = Data(#"{"schemaVersion":2,"operations":[],"newV2Field":true}"#.utf8)
        try futureContents.write(to: futureURL)

        let loaded = await store.load(accountID: "user-a")
        XCTAssertTrue(loaded.operations.isEmpty)

        await store.persist([makeOperation()], accountID: "user-a")
        let untouched = try Data(contentsOf: futureURL)
        XCTAssertEqual(untouched, futureContents, "a rollback must never corrupt newer-schema data")
    }

    // MARK: 16. Corrupted-store recovery

    func testCorruptedFileIsQuarantinedAndStoreRecovers() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = currentFileURL(accountID: "user-a")
        try Data("not json at all {{{{".utf8).write(to: url)

        let recovered = await store.load(accountID: "user-a")
        XCTAssertTrue(recovered.operations.isEmpty)
        XCTAssertTrue(recovered.recoveredFromCorruption)

        // Original bytes preserved for diagnosis; primary file gone.
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let quarantined = url.appendingPathExtension("corrupt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: quarantined.path))

        // The store keeps working after recovery.
        let operations = [makeOperation()]
        await store.persist(operations, accountID: "user-a")
        let reloaded = await store.load(accountID: "user-a")
        XCTAssertEqual(reloaded.operations, operations)
        XCTAssertFalse(reloaded.recoveredFromCorruption)
    }

    func testTamperedSchemaVersionInsideFileIsTreatedAsCorruption() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = currentFileURL(accountID: "user-a")
        try Data(#"{"schemaVersion":9,"operations":[]}"#.utf8).write(to: url)

        let result = await store.load(accountID: "user-a")
        XCTAssertTrue(result.operations.isEmpty)
        XCTAssertTrue(result.recoveredFromCorruption)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.appendingPathExtension("corrupt").path)
        )
    }

    // MARK: 8-support. Purge

    func testPurgeRemovesQueueAndQuarantineFilesForTheAccountOnly() async throws {
        await store.persist([makeOperation()], accountID: "user-a")
        await store.persist([makeOperation(accountID: "user-b", gameID: "9")], accountID: "user-b")

        // Also leave a quarantined artifact for user-a.
        let corruptURL = currentFileURL(accountID: "user-a").appendingPathExtension("corrupt")
        try Data("junk".utf8).write(to: corruptURL)

        await store.purge(accountID: "user-a")

        let loadedA = await store.load(accountID: "user-a")
        XCTAssertTrue(loadedA.operations.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: corruptURL.path))

        let loadedB = await store.load(accountID: "user-b")
        XCTAssertEqual(loadedB.operations.count, 1)
    }

    func testPersistingEmptyQueueRemovesTheFile() async {
        await store.persist([makeOperation()], accountID: "user-a")
        XCTAssertTrue(FileManager.default.fileExists(atPath: currentFileURL(accountID: "user-a").path))

        await store.persist([], accountID: "user-a")
        XCTAssertFalse(FileManager.default.fileExists(atPath: currentFileURL(accountID: "user-a").path))
    }
}
