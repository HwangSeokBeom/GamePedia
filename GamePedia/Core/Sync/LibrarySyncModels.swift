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

/// Durable settlement state of a queued operation.
///
/// - `queued`: the intent is durably recorded and its remote outcome is
///   unknown; it is eligible for (re)submission.
/// - `remotelyConfirmed`: the remote outcome is known (server success or a
///   deterministic permanent rejection); the operation must NEVER be
///   submitted again. A confirmed record only remains on disk while its
///   cleanup write is pending — the terminal "locally cleaned" state is the
///   record's removal from the file.
///
/// The transient "submitted" state is in-memory only
/// (`inFlightOperationIDs`): after a crash mid-request the outcome is
/// unknown, so the record correctly collapses back to `queued` and the
/// replayed mutations converge server-side (absolute-state semantics, see
/// header note above).
enum LibrarySyncDurableState: String, Codable {
    case queued
    case remotelyConfirmed
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
    /// Account-scope id of the gesture-time ownership that produced this
    /// operation. nil in records persisted before ownership capture existed;
    /// gesture-time sequences are only comparable within one scope id, so a
    /// legacy (nil-scope) record is deterministically superseded by any new
    /// gesture for its entity.
    let scopeID: String?
    /// Gesture-time intent sequence within (scope, entity). 0 in legacy
    /// records, which sorts below every real sequence (they start at 1).
    let sequence: UInt64
    /// Durable settlement state. Missing in files written before this field
    /// existed, which decodes as `queued` — the safe default (re-submission
    /// converges). Older readers ignore the extra key and also treat the
    /// record as queued, which is equally convergent on rollback.
    var state: LibrarySyncDurableState

    init(
        id: UUID,
        accountID: String,
        kind: LibrarySyncOperationKind,
        createdAt: Date,
        scopeID: String? = nil,
        sequence: UInt64 = 0,
        state: LibrarySyncDurableState = .queued
    ) {
        self.id = id
        self.accountID = accountID
        self.kind = kind
        self.createdAt = createdAt
        self.scopeID = scopeID
        self.sequence = sequence
        self.state = state
    }

    private enum CodingKeys: String, CodingKey {
        case id, accountID, kind, createdAt, scopeID, sequence, state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        accountID = try container.decode(String.self, forKey: .accountID)
        kind = try container.decode(LibrarySyncOperationKind.self, forKey: .kind)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        // Ownership fields are absent in pre-ownership files; the defaults
        // (nil scope, sequence 0) deterministically lose to any new gesture,
        // and older readers ignore the extra keys on rollback.
        scopeID = try container.decodeIfPresent(String.self, forKey: .scopeID)
        sequence = try container.decodeIfPresent(UInt64.self, forKey: .sequence) ?? 0
        state = try container.decodeIfPresent(LibrarySyncDurableState.self, forKey: .state) ?? .queued
    }

    /// Serialization key: operations sharing an entity key execute strictly
    /// FIFO; distinct entity keys may sync in parallel.
    var entityKey: String {
        switch kind {
        case .setFavorite(let gameID, _):
            return LibrarySyncEntityKey.favorite(gameID: gameID)
        case .setLibraryStatus(let payload):
            return LibrarySyncEntityKey.libraryStatus(
                source: payload.source,
                externalGameID: payload.externalGameID
            )
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

/// Acknowledgement for an enqueue request. The optimistic UI may only treat
/// an intent as "queued offline" on `.accepted`, which is returned strictly
/// after the queue file was durably written.
///
/// Fallback contract: ONLY `.storageBlocked` and `.serviceUnavailable` may
/// route the caller to the direct (legacy) mutation path, and only after the
/// caller revalidates the same captured ownership context. `.staleOwnership`
/// and `.supersededByNewerIntent` are terminal — a direct call for either
/// would submit a dead scope's or an outdated gesture's intent with the
/// current account's credentials.
enum LibrarySyncEnqueueResult: Equatable {
    /// Durably persisted; the engine owns delivery from here.
    case accepted
    /// The captured ownership scope no longer owns the session (logout,
    /// account replacement, or deletion since the gesture). The intent is
    /// dropped; it must NEVER reach the direct path.
    case staleOwnership
    /// A newer gesture (higher sequence) for the same entity already
    /// governs; this older intent is obsolete and is dropped. No fallback —
    /// the newest intent posts its own outcome.
    case supersededByNewerIntent
    /// Durable persistence failed; the intent was NOT queued and must not be
    /// presented as saved. Callers may fall back to the direct mutation path
    /// after revalidating the captured ownership.
    case storageBlocked
    /// The engine cannot own the intent right now (no adopted account, or
    /// the ownership scope is current but the engine has not finished
    /// adopting it). Callers may fall back to the direct mutation path
    /// after revalidating the captured ownership.
    case serviceUnavailable
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
    /// UUID string of the failed operation (client idempotency key).
    static let operationID = "operationID"
    /// For favorite operations: the Bool state the failed operation intended
    /// to set. Failure observers reconcile against this — never against
    /// whatever state currently happens to be on screen.
    static let intendedIsFavorite = "intendedIsFavorite"
    /// True when a newer queued intent exists for the same entity. Observers
    /// must ignore the failure for optimistic-state purposes: the newest
    /// intent still governs the UI and will post its own outcome.
    static let supersededByNewerIntent = "supersededByNewerIntent"
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
