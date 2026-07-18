import Foundation

// MARK: - Library sync models
//
// Offline-first library synchronization foundation (iOS 2.2).
//
// Backend contract status: the committed REST mutations this queue replays
// (`POST /favorites`, `DELETE /favorites/{gameId}`,
// `POST /users/me/library/status`) are naturally convergent on retry —
// re-adding an existing favorite, re-removing a missing one, and re-posting
// a status all converge server-side. The server does NOT consume an
// Idempotency-Key header, client operation IDs, or version/If-Match
// preconditions; concurrent edits are last-write-wins
// (docs/backend/LIBRARY_SYNC_CONTRACT_REQUEST.md). The `id` below is the
// client-side idempotency key: it is created once per user intent and
// reused verbatim across every retry of that operation.

/// Absolute-state library mutations. Every case sets a final state for its
/// entity, which is what makes per-entity "keep only the newest pending
/// operation" compaction safe.
enum LibrarySyncOperationKind: Codable, Equatable {
    case setFavorite(gameID: String, isFavorite: Bool)
    case setLibraryStatus(LibraryStatusSyncPayload)
}

/// Codable snapshot of `LibraryGameStatusUpdateRequest`, persisted instead of
/// the domain struct so the on-disk schema stays independent of domain-model
/// evolution.
struct LibraryStatusSyncPayload: Codable, Equatable {
    let source: GameSource
    let externalGameID: String
    let canonicalGameID: Int?
    let title: String
    let coverURL: URL?
    let status: UserGameStatus

    init(request: LibraryGameStatusUpdateRequest) {
        source = request.gameSource
        externalGameID = request.externalGameId
        canonicalGameID = request.identifier.canonicalGameID
        title = request.title
        coverURL = request.coverImageURL
        status = request.status
    }

    init(
        source: GameSource,
        externalGameID: String,
        canonicalGameID: Int?,
        title: String,
        coverURL: URL?,
        status: UserGameStatus
    ) {
        self.source = source
        self.externalGameID = externalGameID
        self.canonicalGameID = canonicalGameID
        self.title = title
        self.coverURL = coverURL
        self.status = status
    }

    var domainRequest: LibraryGameStatusUpdateRequest {
        LibraryGameStatusUpdateRequest(
            identifier: LibraryGameIdentifier(
                source: source,
                sourceID: externalGameID,
                canonicalGameID: canonicalGameID
            ),
            title: title,
            coverImageURL: coverURL,
            status: status
        )
    }
}

struct LibrarySyncOperation: Codable, Equatable, Identifiable {
    /// Stable client-side idempotency key. Assigned once when the user intent
    /// is accepted and reused for every retry; never regenerated.
    let id: UUID
    /// Authenticated user this operation belongs to. Operations are only ever
    /// submitted while this exact account owns the active session. The raw
    /// UUID is persisted in the queue body for account isolation (the queue
    /// file name only carries its SHA-256 hash); it is personal metadata —
    /// sandbox-protected, excluded from logs, and never credential material.
    let accountID: String
    let kind: LibrarySyncOperationKind
    let createdAt: Date

    /// Serialization key: operations sharing an entity key execute strictly
    /// FIFO; distinct entity keys may sync in parallel.
    var entityKey: String {
        switch kind {
        case .setFavorite(let gameID, _):
            return "favorite:\(gameID)"
        case .setLibraryStatus(let payload):
            return "library-status:\(payload.source.rawValue):\(payload.externalGameID)"
        }
    }

    var entityKind: LibrarySyncEntityKind {
        switch kind {
        case .setFavorite: return .favorite
        case .setLibraryStatus: return .libraryStatus
        }
    }

    /// Game identifier that is safe to expose in notifications and logs
    /// (game IDs are public catalog identifiers, never credential material).
    var gameIDDescription: String {
        switch kind {
        case .setFavorite(let gameID, _):
            return gameID
        case .setLibraryStatus(let payload):
            return payload.externalGameID
        }
    }
}

enum LibrarySyncEntityKind: String, Codable {
    case favorite
    case libraryStatus
}

/// Server-authoritative result of a successfully replayed operation.
enum LibrarySyncOutcome: Equatable {
    case favorite(FavoriteMutationResult)
    case libraryStatus(LibraryGameStatusMutationResult)
}

/// Stable classification of a transport failure. Codes are semantic
/// `error.code`-style strings only — never localized messages, never payloads.
enum LibrarySyncFailure: Error, Equatable {
    /// Retry with backoff; pending work is preserved.
    case transient(code: String)
    /// Never retried; the operation is dropped and the failure surfaced.
    case permanent(code: String)
    /// The session cannot authorize requests right now. The queue pauses
    /// (operations preserved) until the next authenticated session event.
    case authRequired(code: String)

    var code: String {
        switch self {
        case .transient(let code), .permanent(let code), .authRequired(let code):
            return code
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// Posted whenever queue composition changes (accepted, completed,
    /// dropped, parked, account switched). Safe metadata only.
    static let librarySyncQueueDidChange =
        Notification.Name("LibrarySyncQueueDidChangeNotification")
    /// Posted when an operation permanently fails (dropped). Safe metadata
    /// only: entity kind, game ID, stable error code.
    static let librarySyncOperationDidFail =
        Notification.Name("LibrarySyncOperationDidFailNotification")
}

enum LibrarySyncQueueUserInfoKey {
    static let pendingCount = "pendingCount"
    static let parkedCount = "parkedCount"
}

enum LibrarySyncFailureUserInfoKey {
    static let entityKind = "entityKind"
    static let gameID = "gameID"
    static let errorCode = "errorCode"
}

// MARK: - Diagnostics

/// Snapshot for the DEBUG diagnostics screen. Safe metadata only: booleans,
/// counters, generations, and static error codes. Never tokens, emails,
/// titles, or request payloads.
struct LibrarySyncDiagnosticsSnapshot: Equatable {
    let hasActiveAccount: Bool
    let sessionGeneration: UInt64
    let pendingOperationCount: Int
    let parkedOperationCount: Int
    let inFlightEntityCount: Int
    let completedOperationCount: Int
    let permanentlyFailedOperationCount: Int
    let recoveredFromCorruptedStore: Bool
    let isBlockedOnAuth: Bool
    let lastSafeErrorCode: String?
}
