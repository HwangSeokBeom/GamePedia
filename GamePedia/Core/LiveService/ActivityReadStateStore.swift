import Foundation

// MARK: - Activity read state
//
// Durable per-account read/unread state for the unified Activity Center.
//
// The backend exposes only "mark ALL notifications read"
// (PATCH /users/me/notifications/read-all); there is no per-item read
// mutation and the friend activity feed carries no read state at all
// (docs/backend/ACTIVITY_CENTER_CONTRACT_REQUEST.md). The client therefore
// keeps a local, account-scoped read watermark: when the user views the
// Activity Center, everything at or before the newest visible item's
// timestamp is recorded as read. Server `isRead` remains authoritative
// where it exists; the watermark only widens read state, never un-reads.
//
// The state survives process restart via `AccountScopedStateStore` and is
// purged on account deletion.

struct ActivityReadState: Codable, Equatable, Sendable {
    /// Items with occurredAt <= watermark count as read locally.
    var readWatermark: Date?

    static let empty = ActivityReadState(readWatermark: nil)
}

protocol ActivityReadStateStoring: Sendable {
    func readState(accountID: String) async -> ActivityReadState
    func advanceWatermark(to date: Date, accountID: String) async
    func purge(accountID: String) async
}

actor ActivityReadStateStore: ActivityReadStateStoring {

    private let store: AccountScopedStateStore<ActivityReadState>
    private var cached: [String: ActivityReadState] = [:]

    init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        store = AccountScopedStateStore(
            filePrefix: "activity-read-state",
            schemaVersion: 1,
            directoryURL: directoryURL,
            fileManager: fileManager
        )
    }

    func readState(accountID: String) async -> ActivityReadState {
        if let cached = cached[accountID] {
            return cached
        }
        let loaded = await store.load(accountID: accountID).payload ?? .empty
        cached[accountID] = loaded
        return loaded
    }

    func advanceWatermark(to date: Date, accountID: String) async {
        let current = await readState(accountID: accountID)
        // Watermarks only move forward; a stale caller can never un-read.
        if let existing = current.readWatermark, existing >= date {
            return
        }
        let updated = ActivityReadState(readWatermark: date)
        cached[accountID] = updated
        await store.persist(updated, accountID: accountID)
    }

    func purge(accountID: String) async {
        cached.removeValue(forKey: accountID)
        await store.purge(accountID: accountID)
    }
}
