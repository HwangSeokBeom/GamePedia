import Foundation

// MARK: - Last-known Activity Center snapshot store
//
// Account-scoped durable copy of the most recent merged Activity Center
// view. Read when every live source fails so the screen can degrade to
// "last known activity" instead of a blank error. Storage semantics
// (schema-versioned file name, hashed account component, corruption
// quarantine, purge-on-deletion) come from AccountScopedStateStore.

actor FileActivityCenterSnapshotStore: ActivityCenterSnapshotStoring {

    private let store: AccountScopedStateStore<PersistedActivityCenterSnapshot>

    init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        store = AccountScopedStateStore(
            filePrefix: "activity-center-snapshot",
            schemaVersion: 1,
            directoryURL: directoryURL,
            fileManager: fileManager
        )
    }

    func loadSnapshot(accountID: String) async -> PersistedActivityCenterSnapshot? {
        await store.load(accountID: accountID).payload
    }

    func persistSnapshot(_ snapshot: PersistedActivityCenterSnapshot, accountID: String) async {
        await store.persist(snapshot, accountID: accountID)
    }

    func purge(accountID: String) async {
        await store.purge(accountID: accountID)
    }
}
