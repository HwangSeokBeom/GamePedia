import Foundation

// MARK: - Authenticated direct-fallback coordination
//
// When the durable LibrarySyncEngine cannot own an authenticated intent
// (`.storageBlocked` / `.serviceUnavailable`), ViewModels fall back to a
// direct repository mutation. Those fallback Tasks revalidate account
// ownership, but without a shared sequence authority two of them targeting
// the same (account scope, entity) — possibly from different ViewModels —
// race on the network, and an older gesture's request can commit after a
// newer one's.
//
// One coordinator instance — owned by the engine and reached through the
// `LibraryMutationSyncing` router that every ViewModel already shares — is
// the single adjudicator for every authenticated direct fallback:
//
// - identity is the existing gesture-time `LibraryMutationOwnership`
//   (account scope id, entity key — which encodes the mutation family —
//   gesture sequence, intended absolute state). There is no second
//   sequence system
// - the highest observed gesture sequence per (current scope, entity) is
//   retained; a submission carrying a lower sequence is suppressed without
//   networking
// - requests for one (scope, entity) are strictly serialized. A newer
//   sequence arriving while an older request is in flight waits and
//   commits after it; requests are never cancelled — an already-sent
//   request cannot be retracted, and cancelling it would let its commit
//   land after a newer request's. Distinct entities execute independently
// - scope ownership is revalidated immediately before the operation runs
//   (request construction) and again before the outcome is applied; the
//   outcome is applied while the entity claim is still held, so a stale
//   completion can never be applied after a newer sequence started
// - retained state belongs to exactly one live scope id. Logout, account
//   replacement, deletion, and A → B → A all advance the scope id in the
//   gesture-time ownership authority (ids are never reused), which makes
//   every old capture — queued, waiting, or in flight — permanently
//   suppressible; adopting the next current scope physically drops the old
//   state and releases its waiters. A same-account credential refresh
//   preserves the scope id, so retained sequences stay authoritative
// - no token or credential is ever captured: the coordinator holds scope
//   identifiers and sequences only. Operation closures call the existing
//   use cases, whose network layer obtains current credentials per call

/// Adjudicated result of one authenticated direct-fallback submission.
enum LibraryDirectFallbackOutcome<Value: Sendable> {
    /// The request ran and its gesture still owns the entity: the caller
    /// applies the result (UI + notifications) exactly as the legacy
    /// direct path did.
    case success(Value)
    /// The request ran and failed while its gesture still owns the entity:
    /// the caller surfaces the error.
    case failure(Error)
    /// Nothing may be applied: the request was never sent (stale scope, or
    /// a newer gesture sequence already governs the entity) or lost
    /// authority while in flight. The newest intent posts its own outcome.
    case suppressed
}

/// Adjudication milestones, exposed for deterministic test sequencing only
/// (safe metadata: entity key and gesture sequence — never titles, tokens,
/// or payloads). Production code never installs a handler and never drives
/// control flow from milestones.
enum LibraryDirectFallbackMilestone: Equatable, Sendable {
    /// The sequence became the highest observed for its entity.
    case admitted(entityKey: String, sequence: UInt64)
    /// The sequence is parked behind a running request for its entity.
    case waiting(entityKey: String, sequence: UInt64)
    /// The sequence claimed its entity; its operation is about to run.
    case started(entityKey: String, sequence: UInt64)
    /// The sequence's outcome was applied and its entity claim released.
    case finished(entityKey: String, sequence: UInt64)
    /// The submission ended with `.suppressed` (never sent, or its
    /// completion lost authority).
    case suppressed(entityKey: String, sequence: UInt64)
}

/// Single shared sequence authority for authenticated direct (engine
/// fallback) mutations. See the header note for the full contract.
actor LibraryDirectMutationCoordinator {

    private struct EntityState {
        /// Highest gesture sequence ever admitted for this entity in the
        /// retained scope. A lower sequence never starts a request — and,
        /// because execution is serialized, can never commit after one.
        var highestObservedSequence: UInt64 = 0
        /// Sequence whose request (or outcome application) currently holds
        /// the entity. Exactly one submission holds it at a time.
        var runningSequence: UInt64?
        /// Submissions parked until the entity is released. Every waiter
        /// revalidates scope and sequence when it wakes.
        var waiters: [CheckedContinuation<Void, Never>] = []
    }

    /// The single scope this coordinator retains state for. Scope ids are
    /// never reused, so state kept for any other scope belongs to a dead
    /// scope and is discarded on adoption of the live one.
    private var retainedScopeID: UUID?
    private var entityStates: [String: EntityState] = [:]
    /// Live scope authority — backed by the gesture-time ownership context.
    /// Identifiers only; never credential material.
    private let isScopeCurrent: @Sendable (UUID) -> Bool
    private var milestoneHandler: (@Sendable (LibraryDirectFallbackMilestone) -> Void)?

    init(isScopeCurrent: @escaping @Sendable (UUID) -> Bool) {
        self.isScopeCurrent = isScopeCurrent
    }

    /// Test-only observation hook; see `LibraryDirectFallbackMilestone`.
    func setMilestoneHandler(
        _ handler: (@Sendable (LibraryDirectFallbackMilestone) -> Void)?
    ) {
        milestoneHandler = handler
    }

    /// Adjudicates and (when the gesture still governs) executes one
    /// authenticated direct fallback. `apply` is invoked exactly once with
    /// the final outcome; for executed requests it runs while the entity
    /// claim is still held, so no newer sequence can start — or apply —
    /// until this outcome has been applied.
    func run<Value: Sendable>(
        ownership: LibraryMutationOwnership,
        operation: @escaping @Sendable () async throws -> Value,
        apply: @escaping @Sendable (LibraryDirectFallbackOutcome<Value>) async -> Void
    ) async {
        let key = ownership.entityKey

        // Scope admission: only the live scope may retain state. A dead
        // scope's submission is suppressed before any bookkeeping.
        guard isScopeCurrent(ownership.scopeID) else {
            await suppress(ownership, apply: apply)
            return
        }
        adoptScopeIfNeeded(ownership.scopeID)

        // Sequence admission: a sequence below the highest observed for
        // this entity is already outdated — reject without networking.
        var state = entityStates[key] ?? EntityState()
        guard ownership.sequence >= state.highestObservedSequence else {
            await suppress(ownership, apply: apply)
            return
        }
        state.highestObservedSequence = ownership.sequence
        entityStates[key] = state
        milestoneHandler?(.admitted(entityKey: key, sequence: ownership.sequence))

        // Serialization: wait while another sequence holds the entity.
        // Never cancel the holder — its request may already be on the wire
        // and cannot be retracted; cancelling would let its commit land
        // after ours. Waking waiters revalidate scope and sequence.
        while true {
            guard isScopeCurrent(ownership.scopeID),
                  retainedScopeID == ownership.scopeID,
                  entityStates[key]?.highestObservedSequence == ownership.sequence else {
                await suppress(ownership, apply: apply)
                return
            }
            guard entityStates[key]?.runningSequence != nil else { break }
            milestoneHandler?(.waiting(entityKey: key, sequence: ownership.sequence))
            await withCheckedContinuation { continuation in
                entityStates[key]?.waiters.append(continuation)
            }
        }

        // Claim and final revalidation immediately before the operation
        // constructs its request. No suspension separates the checks above
        // from the claim, and none separates the claim from `operation()`.
        entityStates[key]?.runningSequence = ownership.sequence
        milestoneHandler?(.started(entityKey: key, sequence: ownership.sequence))

        let outcome: LibraryDirectFallbackOutcome<Value>
        do {
            let value = try await operation()
            outcome = isStillAuthoritative(ownership) ? .success(value) : .suppressed
        } catch {
            outcome = isStillAuthoritative(ownership) ? .failure(error) : .suppressed
        }

        // Applied while the claim is held: a newer waiting sequence cannot
        // start, so a lower sequence's outcome can never be applied after
        // a higher sequence's request began.
        await apply(outcome)
        release(key: key, ownership: ownership)
        if case .suppressed = outcome {
            milestoneHandler?(.suppressed(entityKey: key, sequence: ownership.sequence))
        } else {
            milestoneHandler?(.finished(entityKey: key, sequence: ownership.sequence))
        }
    }

    /// True while the submission's scope is still live, is the retained
    /// one, and its sequence is still the highest observed for its entity.
    private func isStillAuthoritative(_ ownership: LibraryMutationOwnership) -> Bool {
        isScopeCurrent(ownership.scopeID)
            && retainedScopeID == ownership.scopeID
            && entityStates[ownership.entityKey]?.highestObservedSequence == ownership.sequence
    }

    /// Adopts the submitting (live) scope. State retained for any other
    /// scope belongs to a scope that can never be current again: drop it
    /// and release its waiters, which revalidate and suppress themselves.
    /// Different entities and different accounts therefore never block
    /// each other. A same-account credential refresh keeps the scope id,
    /// so this is a no-op and retained ordering survives.
    private func adoptScopeIfNeeded(_ liveScopeID: UUID) {
        guard retainedScopeID != liveScopeID else { return }
        let orphaned = entityStates
        retainedScopeID = liveScopeID
        entityStates = [:]
        for state in orphaned.values {
            for waiter in state.waiters {
                waiter.resume()
            }
        }
    }

    /// Releases the entity claim held by `ownership` and wakes all waiters
    /// (each revalidates; only the highest still-live sequence proceeds).
    /// A completion from a scope that is no longer retained must not touch
    /// the live scope's state — sequences restart at 1 per scope, so a
    /// numeric match across scopes would release a foreign claim.
    private func release(key: String, ownership: LibraryMutationOwnership) {
        guard retainedScopeID == ownership.scopeID,
              var state = entityStates[key] else { return }
        if state.runningSequence == ownership.sequence {
            state.runningSequence = nil
        }
        let waiters = state.waiters
        state.waiters = []
        entityStates[key] = state
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func suppress<Value: Sendable>(
        _ ownership: LibraryMutationOwnership,
        apply: @escaping @Sendable (LibraryDirectFallbackOutcome<Value>) async -> Void
    ) async {
        await apply(.suppressed)
        milestoneHandler?(
            .suppressed(entityKey: ownership.entityKey, sequence: ownership.sequence)
        )
    }
}
