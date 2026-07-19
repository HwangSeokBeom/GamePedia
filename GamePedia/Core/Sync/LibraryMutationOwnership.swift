import Foundation

// MARK: - Gesture-time mutation ownership (iOS 2.4 review follow-up)
//
// Every UI-originated library/favorite mutation captures an immutable
// ownership context SYNCHRONOUSLY at gesture time, before its submission
// Task is created. The context pins:
//
// - which account owned the gesture (`accountID`)
// - which account-scope generation owned it (`scopeID` + `generation`)
// - which entity it targets (`entityKey`, which also encodes the mutation
//   family: favorite vs library status)
// - where it sits in the user's gesture order (`sequence`)
// - the absolute state the user intended (`intendedState`)
//
// The context is threaded through every asynchronous boundary — submission
// Task → engine enqueue → persisted operation → direct-fallback decision →
// remote mutation → completion — and is revalidated after each one. The
// engine never infers ownership from whichever account happens to be active
// when the enqueue executes, and the direct (legacy) path never runs for a
// scope that is no longer current.
//
// No credential material is ever captured: the context holds account and
// scope identifiers only. The network layer keeps obtaining current
// credentials exactly as before.

/// Absolute state a gesture intended to set. Carried by the ownership
/// context so completion handlers reconcile against the user's intent, never
/// against whatever happens to be on screen.
enum LibraryMutationIntendedState: Equatable, Sendable {
    case favorite(isFavorite: Bool)
    case libraryStatus(UserGameStatus)
}

/// Immutable ownership snapshot captured at gesture time.
struct LibraryMutationOwnership: Equatable, Sendable {
    /// Account that owned the gesture. Identifier only — never a token.
    let accountID: String
    /// Unique id of the account-scope generation that owned the gesture.
    /// A scope id is never reused: A → B → A produces a third, distinct id,
    /// so an old A capture can never revive.
    let scopeID: UUID
    /// Monotonic account-scope generation counter (diagnostics/ordering).
    let generation: UInt64
    /// Entity the mutation targets; also encodes the mutation family.
    let entityKey: String
    /// Gesture-time order within (scope, entity). Assigned synchronously at
    /// gesture time — later gestures always carry a higher sequence, no
    /// matter how their Tasks are scheduled.
    let sequence: UInt64
    /// Absolute state the user intended to set.
    let intendedState: LibraryMutationIntendedState
}

/// Entity-key builders shared by gesture capture and the persisted
/// operation, so ownership and queue records can never disagree on identity.
enum LibrarySyncEntityKey {
    static func favorite(gameID: String) -> String {
        "favorite:\(gameID)"
    }

    static func libraryStatus(source: GameSource, externalGameID: String) -> String {
        "library-status:\(source.rawValue):\(externalGameID)"
    }
}

// MARK: - Ownership context

/// Synchronous gesture-time authority for account scope and intent order.
///
/// - The scope advances only when the account scope itself changes: first
///   login, account replacement, logout, or account deletion. A same-account
///   credential refresh preserves the scope (and its sequences) — exactly
///   mirroring the engine's account-scope generation semantics.
/// - `captureIntent` is called synchronously inside the gesture handler and
///   assigns the next per-(scope, entity) sequence under the lock, so two
///   rapid gestures observe their true user order even when their Tasks are
///   scheduled in reverse.
/// - `isCurrent` compares the captured scope id against the live one; a
///   scope id is never reused, so staleness is permanent.
///
/// Lock-based (never actor-isolated) so capture and validation stay
/// synchronous at the gesture site and in completion handlers.
final class LibraryMutationOwnershipContext: @unchecked Sendable {

    private struct Scope {
        let accountID: String
        let id: UUID
        let generation: UInt64
    }

    private let lock = NSLock()
    private var scope: Scope?
    private var generationCounter: UInt64 = 0
    /// Last handed-out sequence per entity key, valid for the current scope
    /// only (cleared whenever the scope advances).
    private var sequencesByEntityKey: [String: UInt64] = [:]

    /// Mirrors the auth session into the ownership scope. Idempotent: a
    /// repeated event for the already-current account (same-account
    /// credential refresh) preserves the scope and its sequences.
    func adoptSession(isAuthenticated: Bool, userID: String?) {
        lock.lock()
        defer { lock.unlock() }
        let accountID = (isAuthenticated && userID?.isEmpty == false) ? userID : nil
        guard scope?.accountID != accountID else { return }
        advanceScopeLocked(to: accountID)
    }

    /// Account deletion: the deleted account's scope becomes permanently
    /// unusable. No-op for a non-current account (its captures are already
    /// stale by scope comparison).
    func invalidateAccount(_ accountID: String) {
        lock.lock()
        defer { lock.unlock() }
        guard scope?.accountID == accountID else { return }
        advanceScopeLocked(to: nil)
    }

    /// Synchronous gesture-time capture. Returns nil when no authenticated
    /// account owns the gesture (guest), which routes callers to the
    /// pre-2.2 direct path exactly as before.
    func captureIntent(
        entityKey: String,
        intendedState: LibraryMutationIntendedState
    ) -> LibraryMutationOwnership? {
        lock.lock()
        defer { lock.unlock() }
        guard let scope else { return nil }
        let sequence = (sequencesByEntityKey[entityKey] ?? 0) &+ 1
        sequencesByEntityKey[entityKey] = sequence
        return LibraryMutationOwnership(
            accountID: scope.accountID,
            scopeID: scope.id,
            generation: scope.generation,
            entityKey: entityKey,
            sequence: sequence,
            intendedState: intendedState
        )
    }

    /// True while the captured scope still owns the session. Scope ids are
    /// never reused, so once false this stays false forever.
    func isCurrent(_ ownership: LibraryMutationOwnership) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return scope?.id == ownership.scopeID
    }

    /// Scope-id form of `isCurrent`, for authorities (the direct-fallback
    /// coordinator) that adjudicate by scope id alone. Same permanence:
    /// ids are never reused, so once false this stays false forever.
    func isScopeCurrent(_ scopeID: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return scope?.id == scopeID
    }

    /// Currently owning account, if any (tests/diagnostics).
    var currentAccountID: String? {
        lock.lock()
        defer { lock.unlock() }
        return scope?.accountID
    }

    private func advanceScopeLocked(to accountID: String?) {
        generationCounter &+= 1
        sequencesByEntityKey = [:]
        scope = accountID.map {
            Scope(accountID: $0, id: UUID(), generation: generationCounter)
        }
    }
}
