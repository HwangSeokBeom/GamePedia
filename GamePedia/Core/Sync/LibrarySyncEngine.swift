import Foundation

// MARK: - LibrarySyncEngine
//
// Actor-isolated offline-first queue for library mutations.
//
// Invariants (each covered by deterministic tests):
// - every user intent gets exactly one operation with a stable idempotency
//   key (`LibrarySyncOperation.id`); retries reuse the operation verbatim
// - every UI-originated mutation carries a gesture-time ownership context
//   (account, scope id, entity, sequence, intended state) captured
//   synchronously in the gesture handler; enqueue validates it against the
//   ownership authority and revalidates after every suspension — the engine
//   never binds an intent to whichever account is active when enqueue runs.
//   A stale scope returns `.staleOwnership`; every non-accepted result is
//   terminal for the intent — no second transport path exists
// - the engine is the ONLY authority for authenticated favorite/library
//   mutations: ownership, gesture order, compaction, persistence, retry,
//   remote execution, and completion settlement. Remote execution binds the
//   adoption-time authorization expectation (account + session epoch,
//   identifiers only) atomically to that account's credential at request
//   construction; a stale expectation fails before transmission
// - gesture-time sequences, not Task-arrival order, decide which intent is
//   newest: an equal-or-higher sequence that is queued, in-flight, or
//   already settled in the same scope rejects a late lower sequence with
//   `.supersededByNewerIntent`; compaction therefore always preserves the
//   highest gesture sequence. Sequences are scoped per (account scope,
//   entity); scope ids are never reused, and legacy records (nil scope,
//   sequence 0) deterministically lose to any new gesture
// - operations are scoped to the authenticated account; a different account
//   can never submit them, and switching accounts swaps the whole queue
// - the in-memory queue is detached BEFORE the engine suspends to load the
//   next account's persisted queue, and enqueue/read paths wait for that
//   load to resolve — a mixed-account operation array can never exist in
//   memory or reach disk
// - a stale account load (superseded by a newer session event) commits
//   nothing: every await is followed by a session-generation revalidation
// - enqueue is acknowledged (`.accepted`) only after the queue file is
//   durably written; a failed write reports `.storageBlocked` and leaves
//   both memory and disk exactly as they were
// - a completed operation transitions queued → remotelyConfirmed →
//   locally cleaned; when the cleanup write fails the confirmed record is
//   retained (never resubmitted) and the removal retries on later writes
// - per entity key, execution is strictly FIFO; independent entities may
//   sync in parallel
// - enqueueing supersedes older *pending* operations for the same entity
//   (absolute-state semantics make keep-only-newest compaction safe);
//   in-flight operations are never compacted away mid-request
// - transient failures preserve work and retry with capped exponential
//   backoff + bounded injected jitter; after the automatic-attempt cap the
//   entity parks until a manual retry / foreground / connectivity event
// - permanent validation failures are dropped immediately and surfaced —
//   never retried forever; the failure notification carries the failed
//   intent and whether a newer intent supersedes it, so observers reconcile
//   instead of blindly inverting current UI state
// - auth failures pause the whole queue (work preserved) until the next
//   authenticated session event; the engine never triggers a token refresh
//   itself
// - the ACCOUNT-SCOPE generation is distinct from credential state: a
//   same-account credential refresh (token refreshed, session re-issued
//   for the identical account ID) never advances the generation, never
//   cancels an in-flight request (it may already be on the wire and is
//   not retractable), never clears in-flight ownership, and never reloads
//   the persisted queue — it only lifts an auth pause and refreshes retry
//   budgets. The engine holds no credentials; requests pick up the newly
//   adopted token through the existing auth/network layer per call
// - the account-scope generation advances only when the scope itself
//   changes: account A → B, authenticated → logged out, account deletion,
//   or any transition after which the old account's data must be unusable
// - logout: the queue is persisted and isolated, not submitted, and is
//   reloaded only when the SAME account authenticates again
// - account deletion: the account's persisted queue is purged
// - a completion can only apply once per operation id (duplicate callback
//   protection)
// - session generations make every late completion from a superseded
//   session inert; no sync task outlives its session generation
// - no lock is held across await (actor isolation only); all child tasks
//   are owned by the engine and cancelled on session change
// - REST responses remain authoritative: success re-posts the existing
//   `.favoriteDidChange` / `.libraryDidChange` notifications with
//   server-returned values, driving the same reconciliation reloads as the
//   pre-2.2 direct call paths

protocol LibraryMutationSyncing: Sendable {
    /// Synchronous gesture-time ownership capture. Called inside the gesture
    /// handler BEFORE the submission Task is created; assigns the gesture's
    /// intent sequence. nil when no authenticated account owns the gesture
    /// (guest), which routes the caller to the guest-only direct path.
    func captureFavoriteIntent(gameID: String, isFavorite: Bool) -> LibraryMutationOwnership?
    func captureLibraryStatusIntent(_ request: LibraryGameStatusUpdateRequest) -> LibraryMutationOwnership?
    /// True while the captured scope still owns the session AND the capture
    /// is still the newest gesture for its entity. Completion handlers use
    /// this to decide whether a local failure may reconcile the optimistic
    /// UI: a stale scope must not touch the current account's UI, and an
    /// old gesture must not overwrite a newer one's optimistic intent.
    func isNewestOwnedIntent(_ ownership: LibraryMutationOwnership) -> Bool
    /// `.accepted` only after durable persistence. Every other result is
    /// terminal for the intent: there is NO second transport path. In
    /// particular `.storageBlocked` / `.serviceUnavailable` mean the intent
    /// was refused locally — callers surface a retryable failure and
    /// reconcile the optimistic UI; they must never invoke the favorite or
    /// library repositories directly for an authenticated intent.
    func enqueueFavoriteChange(
        gameID: String,
        isFavorite: Bool,
        ownership: LibraryMutationOwnership
    ) async -> LibrarySyncEnqueueResult
    func enqueueLibraryStatusUpdate(
        _ request: LibraryGameStatusUpdateRequest,
        ownership: LibraryMutationOwnership
    ) async -> LibrarySyncEnqueueResult
    /// Latest locally pending favorite intent for a game, or nil when none.
    func pendingFavoriteIntent(gameID: String) async -> Bool?
    /// Un-parks everything and drains now (user-initiated retry).
    func retryNow() async
}

actor LibrarySyncEngine: LibraryMutationSyncing {

    struct Configuration {
        var retryPolicy = ReconnectPolicy(baseDelay: 2, multiplier: 2, maxDelay: 60, maxJitterFraction: 0.25)
        /// Automatic transient retries per operation between drain triggers.
        var maxAutomaticAttempts = 5
    }

    private let store: any SyncOperationStoring
    private let transport: any LibrarySyncTransporting
    private let configuration: Configuration
    private let jitterSource: any JitterSourcing
    private let sleeper: any RealtimeSleeping
    private let notificationCenter: NotificationCenter
    private let now: @Sendable () -> Date

    /// Gesture-time ownership authority. Adopted synchronously by the
    /// session-event bridges (LibrarySyncRuntime updates it inside the
    /// notification handler, before the engine's async event lands) and kept
    /// aligned by the engine's own session methods. Deliberately lock-based
    /// and non-isolated so gesture handlers capture synchronously.
    nonisolated let ownershipContext: LibraryMutationOwnershipContext

    /// Captures the expected authorization context (account + session
    /// epoch, identifiers only — never credentials) for an adopted account.
    /// Backed by the auth/network boundary's credential authority in
    /// production; injectable for tests.
    private let authorizationProvider: @Sendable (String) -> AuthorizationExpectation?

    /// The expected authorization context of the currently adopted account
    /// session. Captured at adoption and passed by value into every remote
    /// execution, so a request the engine validated for this session can
    /// only bind this session's credential — an account transition (
    /// replacement, logout, deletion, A → B → A) invalidates the
    /// expectation and every not-yet-transmitted request with it. A
    /// same-account credential refresh preserves the expectation.
    private var activeAuthorization: AuthorizationExpectation?

    private var activeAccountID: String?
    private var sessionGeneration: UInt64 = 0
    /// Highest gesture sequence whose remote outcome is settled, per entity
    /// key, valid only for the scope id that produced it. A later-arriving
    /// LOWER sequence must lose even after the higher one completed.
    private var settledIntentSequences: [String: (scopeID: String, sequence: UInt64)] = [:]
    private var operations: [LibrarySyncOperation] = []
    private var inFlightOperationIDs: Set<UUID> = []
    private var parkedEntityKeys: Set<String> = []
    private var attemptCounts: [UUID: Int] = [:]
    private var entityTasks: [String: Task<Void, Never>] = [:]
    private var isBlockedOnAuth = false

    // Account-load gate: while the persisted queue for a newly active
    // account is loading, enqueue/read paths suspend here instead of
    // observing (or mutating) a half-switched queue. Any session event
    // resolves the gate; waiters then revalidate their captured generation.
    private var isAccountLoadInFlight = false
    private var accountLoadWaiters: [CheckedContinuation<Void, Never>] = []

    // Queue-file writer gate: persists are strictly serialized so a slower,
    // older snapshot can never overwrite a newer accepted one.
    private var isWritingStore = false
    private var storeWriteWaiters: [CheckedContinuation<Void, Never>] = []

    // Duplicate-callback protection: ids that already completed or dropped.
    private var settledOperationIDs: Set<UUID> = []
    private var settledOperationOrder: [UUID] = []
    private let settledCapacity = 256

    // Diagnostics (safe metadata only).
    private var completedOperationCount = 0
    private var permanentlyFailedOperationCount = 0
    private var recoveredFromCorruptedStore = false
    private var lastSafeErrorCode: String?

    init(
        store: any SyncOperationStoring,
        transport: any LibrarySyncTransporting,
        configuration: Configuration = Configuration(),
        jitterSource: any JitterSourcing = SystemJitterSource(),
        sleeper: any RealtimeSleeping = TaskRealtimeSleeper(),
        notificationCenter: NotificationCenter = .default,
        now: @escaping @Sendable () -> Date = { Date() },
        authorizationProvider: @escaping @Sendable (String) -> AuthorizationExpectation? = { accountID in
            APIClient.shared.credentialAuthority.expectation(accountID: accountID)
        }
    ) {
        self.store = store
        self.transport = transport
        self.configuration = configuration
        self.jitterSource = jitterSource
        self.sleeper = sleeper
        self.notificationCenter = notificationCenter
        self.now = now
        self.authorizationProvider = authorizationProvider
        self.ownershipContext = LibraryMutationOwnershipContext()
    }

    // MARK: - Session lifecycle

    func sessionDidChange(isAuthenticated: Bool, userID: String?) async {
        // Same-account credential refresh: the account SCOPE is unchanged,
        // so nothing owned by this scope may be disturbed. An in-flight
        // mutation's request may already have reached the server and is not
        // retractable — cancelling and replaying it here would submit the
        // same intent twice and let the original commit after a newer one.
        // This also covers a refresh arriving while this same account's
        // queue load is still suspended: the load stays valid (generation
        // unchanged) and adopts normally when it resolves.
        if isAuthenticated, let userID, !userID.isEmpty, userID == activeAccountID {
            // Idempotent context alignment (no-op when the runtime already
            // adopted this event synchronously): same account → the
            // ownership scope, and every capture made under it, stays valid.
            ownershipContext.adoptSession(isAuthenticated: true, userID: userID)
            // Same account → the authority preserved the session epoch, so
            // this re-capture yields the same expectation (now backed by the
            // refreshed credential). Kept as a fallback for the rare case
            // where adoption raced the credential write.
            activeAuthorization = authorizationProvider(userID) ?? activeAuthorization
            adoptSameAccountCredentialRefresh()
            return
        }

        // Account-scope transition: first login, account replacement,
        // logout, or scope invalidation. The old scope's work must become
        // unusable, so the generation advances and its tasks are cancelled.
        // Ownership captured under the old scope is invalidated first, so a
        // gesture Task that has not reached enqueue yet can only observe
        // staleness — never the new account.
        ownershipContext.adoptSession(isAuthenticated: isAuthenticated, userID: userID)
        settledIntentSequences = [:]
        sessionGeneration &+= 1
        cancelAllEntityTasks()
        isBlockedOnAuth = false
        // Any in-flight account load now belongs to a superseded generation;
        // release its waiters so they revalidate and reject.
        resolveAccountLoad()

        guard isAuthenticated, let userID, !userID.isEmpty else {
            // Logout / supersession / refresh failure: persisted operations
            // stay isolated on disk for this account; nothing is submitted
            // while unauthenticated.
            activeAccountID = nil
            activeAuthorization = nil
            operations = []
            attemptCounts = [:]
            parkedEntityKeys = []
            postQueueDidChange()
            return
        }

        activeAccountID = userID
        // Expected authorization for everything this session will submit:
        // captured once at adoption (identifiers only) and passed by value
        // into each remote execution. The auth layer adopted the credential
        // before posting the session event, so the expectation is available
        // here; if it is not (no credential yet), remote execution fails
        // closed with an auth pause until the next session event.
        activeAuthorization = authorizationProvider(userID)
        // Detach the previous account's queue BEFORE suspending: its
        // durable copy is already on disk (every mutation persists), so
        // clearing memory here is what guarantees the arrays of two
        // accounts can never mix across the load suspension.
        operations = []
        attemptCounts = [:]
        parkedEntityKeys = []
        let generation = sessionGeneration
        isAccountLoadInFlight = true
        let result = await store.load(accountID: userID)
        guard generation == sessionGeneration else {
            // Stale load: a newer session event owns all state (and has
            // already resolved this load's waiters). Commit nothing.
            return
        }
        if result.recoveredFromCorruption {
            recoveredFromCorruptedStore = true
            lastSafeErrorCode = "STORE_CORRUPTED"
        }
        await adoptLoadedOperations(result.operations, accountID: userID, generation: generation)
        guard generation == sessionGeneration else { return }
        postQueueDidChange()
        drain()
    }

    /// Same-account credential refresh. The account-scope generation does
    /// NOT advance, no entity task is cancelled, in-flight ownership is
    /// untouched, and the persisted queue is not reloaded. The event still
    /// (a) lifts an auth pause — this is how the queue resumes after the
    /// auth layer's single-flight refresh succeeds — and (b) grants parked
    /// work a fresh automatic-retry budget. Credentials live in the
    /// auth/network layer, never in the engine, so subsequent requests use
    /// the newly adopted token without any engine-side state.
    private func adoptSameAccountCredentialRefresh() {
        isBlockedOnAuth = false
        parkedEntityKeys = []
        attemptCounts = [:]
        postQueueDidChange()
        // Entities with an in-flight or backing-off operation still own an
        // entity task and are skipped by drain(); only idle queued work
        // (e.g. paused by the auth failure) starts here.
        drain()
    }

    /// Adopts a freshly loaded queue for `accountID` and retries the cleanup
    /// of any leftover remotely-confirmed records without ever resubmitting
    /// them. Ends with the account-load gate resolved.
    private func adoptLoadedOperations(
        _ loaded: [LibrarySyncOperation],
        accountID: String,
        generation: UInt64
    ) async {
        // Defensive account isolation: never adopt records stamped for a
        // different account, whatever the file claimed.
        let owned = loaded.filter { $0.accountID == accountID }
        let confirmedLeftovers = owned.filter { $0.state == .remotelyConfirmed }
        operations = owned.filter { $0.state == .queued }
        // Enqueues buffered behind the gate proceed from here and observe a
        // fully adopted queue.
        resolveAccountLoad()
        guard confirmedLeftovers.isEmpty == false else { return }
        // A confirmed record means a previous cleanup write failed after the
        // remote outcome was known. Rewrite the file without it; on another
        // write failure keep it in memory (still never submitted) so a later
        // successful write finishes the cleanup.
        let cleaned = await persistCurrentQueue(accountID: accountID, generation: generation)
        guard generation == sessionGeneration else { return }
        if cleaned == false {
            operations.append(contentsOf: confirmedLeftovers)
            lastSafeErrorCode = "STORE_CLEANUP_PENDING"
        }
    }

    func accountDidDelete(userID: String) async {
        // Ownership dies before any suspension: a submission Task for the
        // deleted account that reaches enqueue mid-purge is already stale.
        ownershipContext.invalidateAccount(userID)
        await store.purge(accountID: userID)
        if userID == activeAccountID {
            sessionGeneration &+= 1
            settledIntentSequences = [:]
            cancelAllEntityTasks()
            resolveAccountLoad()
            activeAccountID = nil
            activeAuthorization = nil
            operations = []
            attemptCounts = [:]
            parkedEntityKeys = []
            postQueueDidChange()
        }
    }

    func appWillEnterForeground() {
        unparkAllAndDrain()
    }

    func connectivityDidChange(isSatisfied: Bool) {
        guard isSatisfied else { return }
        unparkAllAndDrain()
    }

    // MARK: - Account-load gate

    private func waitForAccountLoadResolution() async {
        while isAccountLoadInFlight {
            await withCheckedContinuation { accountLoadWaiters.append($0) }
        }
    }

    private func resolveAccountLoad() {
        isAccountLoadInFlight = false
        let waiters = accountLoadWaiters
        accountLoadWaiters = []
        for waiter in waiters {
            waiter.resume()
        }
    }

    // MARK: - Store writer gate

    private func acquireStoreWriteLock() async {
        while isWritingStore {
            await withCheckedContinuation { storeWriteWaiters.append($0) }
        }
        isWritingStore = true
    }

    private func releaseStoreWriteLock() {
        isWritingStore = false
        if storeWriteWaiters.isEmpty == false {
            storeWriteWaiters.removeFirst().resume()
        }
    }

    /// Serialized durable write of the current queue. Returns false (and
    /// records a safe error code) when the write failed.
    private func persistCurrentQueue(accountID: String, generation: UInt64) async -> Bool {
        await acquireStoreWriteLock()
        defer { releaseStoreWriteLock() }
        guard generation == sessionGeneration else { return false }
        do {
            try await store.persist(operations, accountID: accountID)
            return true
        } catch {
            lastSafeErrorCode = "STORE_WRITE_FAILED"
            return false
        }
    }

    // MARK: - LibraryMutationSyncing

    nonisolated func captureFavoriteIntent(gameID: String, isFavorite: Bool) -> LibraryMutationOwnership? {
        ownershipContext.captureIntent(
            entityKey: LibrarySyncEntityKey.favorite(gameID: gameID),
            intendedState: .favorite(isFavorite: isFavorite)
        )
    }

    nonisolated func captureLibraryStatusIntent(_ request: LibraryGameStatusUpdateRequest) -> LibraryMutationOwnership? {
        ownershipContext.captureIntent(
            entityKey: LibrarySyncEntityKey.libraryStatus(
                source: request.gameSource,
                externalGameID: request.externalGameId
            ),
            intendedState: .libraryStatus(request.status)
        )
    }

    nonisolated func isNewestOwnedIntent(_ ownership: LibraryMutationOwnership) -> Bool {
        ownershipContext.isNewestIntent(ownership)
    }

    func enqueueFavoriteChange(
        gameID: String,
        isFavorite: Bool,
        ownership: LibraryMutationOwnership
    ) async -> LibrarySyncEnqueueResult {
        await enqueue(kind: .setFavorite(gameID: gameID, isFavorite: isFavorite), ownership: ownership)
    }

    func enqueueLibraryStatusUpdate(
        _ request: LibraryGameStatusUpdateRequest,
        ownership: LibraryMutationOwnership
    ) async -> LibrarySyncEnqueueResult {
        await enqueue(
            kind: .setLibraryStatus(LibraryStatusSyncPayload(request: request)),
            ownership: ownership
        )
    }

    func pendingFavoriteIntent(gameID: String) async -> Bool? {
        let generation = sessionGeneration
        await waitForAccountLoadResolution()
        guard generation == sessionGeneration else { return nil }
        let key = "favorite:\(gameID)"
        for operation in operations.reversed()
        where operation.entityKey == key && operation.state == .queued {
            if case .setFavorite(_, let isFavorite) = operation.kind {
                return isFavorite
            }
        }
        return nil
    }

    func retryNow() async {
        unparkAllAndDrain()
    }

    // MARK: - Queue

    private func enqueue(
        kind: LibrarySyncOperationKind,
        ownership: LibraryMutationOwnership
    ) async -> LibrarySyncEnqueueResult {
        // Ownership is validated against the gesture-time authority — never
        // inferred from whichever account is active when this executes — and
        // revalidated after every suspension point below.
        guard ownershipContext.isCurrent(ownership) else { return .staleOwnership }
        let generation = sessionGeneration
        await waitForAccountLoadResolution()
        guard ownershipContext.isCurrent(ownership) else { return .staleOwnership }
        guard generation == sessionGeneration,
              let accountID = activeAccountID,
              accountID == ownership.accountID else {
            // The gesture scope is still current but the engine has not
            // finished adopting it (session event still in flight). The
            // intent must never bind to the engine's outgoing account.
            return .serviceUnavailable
        }
        let operation = LibrarySyncOperation(
            id: UUID(),
            accountID: accountID,
            kind: kind,
            createdAt: now(),
            scopeID: ownership.scopeID.uuidString,
            sequence: ownership.sequence
        )
        guard operation.entityKey == ownership.entityKey else {
            // Defensive: ownership captured for a different entity can never
            // authorize this mutation.
            lastSafeErrorCode = "OWNERSHIP_ENTITY_MISMATCH"
            return .serviceUnavailable
        }
        // Gesture-time ordering: a queued, in-flight, or already-settled
        // intent with an equal-or-higher sequence in the same scope wins,
        // however the submission Tasks were scheduled.
        guard isSupersededByNewerIntent(ownership) == false else {
            return .supersededByNewerIntent
        }

        await acquireStoreWriteLock()
        defer { releaseStoreWriteLock() }
        guard ownershipContext.isCurrent(ownership), generation == sessionGeneration else {
            return .staleOwnership
        }
        guard isSupersededByNewerIntent(ownership) == false else {
            return .supersededByNewerIntent
        }

        // Compaction: pending (not in-flight) operations for the same entity
        // are superseded — every operation kind sets absolute state, so only
        // the newest intent matters. The gesture-sequence guard above proved
        // this operation carries the highest sequence of its scope (foreign
        // scope ids are older epochs), so the survivor is always the newest
        // USER intent, not merely the last arrival. The superseded records
        // are kept aside so a failed write can restore them exactly.
        let superseded = operations.filter { existing in
            existing.entityKey == operation.entityKey
                && !inFlightOperationIDs.contains(existing.id)
        }
        operations.removeAll { existing in
            existing.entityKey == operation.entityKey
                && !inFlightOperationIDs.contains(existing.id)
        }
        operations.append(operation)

        do {
            try await store.persist(operations, accountID: accountID)
        } catch {
            // Durability could not be established: leave memory exactly as
            // the (unchanged) file describes it and refuse the intent.
            lastSafeErrorCode = "STORE_WRITE_BLOCKED"
            print("[Sync] enqueue rejected code=STORE_WRITE_BLOCKED")
            guard generation == sessionGeneration else { return .storageBlocked }
            operations.removeAll { $0.id == operation.id }
            operations.append(contentsOf: superseded)
            return .storageBlocked
        }
        guard generation == sessionGeneration else {
            // The session moved on mid-write, but the intent is durably
            // queued for its account and loads on that account's next login.
            return .accepted
        }
        // A new user intent on this entity earns a fresh automatic budget.
        parkedEntityKeys.remove(operation.entityKey)
        print("[Sync] accepted kind=\(operation.entityKind.rawValue) entity=\(operation.entityKey)")
        postQueueDidChange()
        drain()
        return .accepted
    }

    /// True when a queued, in-flight, or settled operation for the same
    /// entity already carries an equal-or-higher gesture sequence in the
    /// same ownership scope. Sequences are only comparable within one scope
    /// id: records from another scope (older epoch, legacy nil-scope
    /// migrations) never block a current gesture.
    private func isSupersededByNewerIntent(_ ownership: LibraryMutationOwnership) -> Bool {
        let scopeID = ownership.scopeID.uuidString
        if operations.contains(where: { existing in
            existing.entityKey == ownership.entityKey
                && existing.scopeID == scopeID
                && existing.sequence >= ownership.sequence
        }) {
            return true
        }
        if let settled = settledIntentSequences[ownership.entityKey],
           settled.scopeID == scopeID,
           settled.sequence >= ownership.sequence {
            return true
        }
        return false
    }

    /// Records a settled operation's gesture sequence so a slower Task
    /// carrying an OLDER gesture can still be rejected after the newer one
    /// completed. Failure callbacks settle through the same paths, so they
    /// retain sequence ownership too.
    private func recordSettledIntentSequence(_ operation: LibrarySyncOperation) {
        guard let scopeID = operation.scopeID, operation.sequence > 0 else { return }
        if let existing = settledIntentSequences[operation.entityKey],
           existing.scopeID == scopeID,
           existing.sequence >= operation.sequence {
            return
        }
        settledIntentSequences[operation.entityKey] = (scopeID, operation.sequence)
    }

    // MARK: - Drain

    private func drain() {
        guard activeAccountID != nil, !isBlockedOnAuth, !isAccountLoadInFlight else { return }
        var seenKeys = Set<String>()
        for operation in operations where operation.state == .queued {
            let key = operation.entityKey
            guard seenKeys.insert(key).inserted else { continue }
            guard entityTasks[key] == nil, !parkedEntityKeys.contains(key) else { continue }
            startEntityTask(entityKey: key)
        }
    }

    private func startEntityTask(entityKey: String) {
        let generation = sessionGeneration
        entityTasks[entityKey] = Task { [weak self] in
            await self?.runEntityLoop(entityKey: entityKey, generation: generation)
            await self?.entityTaskDidFinish(entityKey: entityKey, generation: generation)
        }
    }

    private func entityTaskDidFinish(entityKey: String, generation: UInt64) {
        guard generation == sessionGeneration else { return }
        entityTasks[entityKey] = nil
        // New operations may have been compacted in while we were finishing.
        drain()
    }

    private func runEntityLoop(entityKey: String, generation: UInt64) async {
        while generation == sessionGeneration,
              !Task.isCancelled,
              !isBlockedOnAuth,
              !parkedEntityKeys.contains(entityKey),
              let operation = firstPendingOperation(entityKey: entityKey) {
            inFlightOperationIDs.insert(operation.id)
            let shouldContinue = await performWithRetry(operation, generation: generation)
            inFlightOperationIDs.remove(operation.id)
            guard shouldContinue else { return }
        }
    }

    private func firstPendingOperation(entityKey: String) -> LibrarySyncOperation? {
        operations.first {
            $0.entityKey == entityKey
                && $0.state == .queued
                && !inFlightOperationIDs.contains($0.id)
        }
    }

    /// Returns true when the entity loop should continue with its next
    /// operation, false when it must stop (cancellation, stale generation,
    /// auth pause, or parking).
    private func performWithRetry(_ operation: LibrarySyncOperation, generation: UInt64) async -> Bool {
        guard operation.accountID == activeAccountID else {
            // Defensive: never submit an operation owned by another account.
            await discardForeignOperation(operationID: operation.id, generation: generation)
            return true
        }

        while true {
            guard generation == sessionGeneration, !Task.isCancelled else { return false }
            // Captured by value while still inside the generation guard: the
            // request can only bind the credential of the session the engine
            // validated this operation against. Any account transition after
            // this point makes the expectation unbindable, so the request
            // fails before transmission instead of reading a newer token.
            let authorization = activeAuthorization

            do {
                let outcome = try await transport.perform(operation, authorization: authorization)
                guard generation == sessionGeneration else {
                    // Late completion from a superseded session: inert.
                    return false
                }
                await applySuccess(operationID: operation.id, outcome: outcome, generation: generation)
                return true
            } catch is CancellationError {
                return false
            } catch {
                guard generation == sessionGeneration, !Task.isCancelled else { return false }
                let failure = LibrarySyncFailureClassifier.classify(error)
                lastSafeErrorCode = failure.code

                switch failure {
                case .permanent(let code):
                    await applyPermanentFailure(operation: operation, code: code, generation: generation)
                    return true

                case .authRequired:
                    // Preserve the operation; pause the whole queue until
                    // the next authenticated session event. Never triggers
                    // a refresh itself.
                    isBlockedOnAuth = true
                    print("[Sync] paused code=\(failure.code)")
                    postQueueDidChange()
                    return false

                case .transient(let code):
                    let attempts = (attemptCounts[operation.id] ?? 0) + 1
                    attemptCounts[operation.id] = attempts
                    if attempts >= configuration.maxAutomaticAttempts {
                        parkedEntityKeys.insert(operation.entityKey)
                        print("[Sync] parked entity=\(operation.entityKey) code=\(code)")
                        postQueueDidChange()
                        return false
                    }
                    let delay = configuration.retryPolicy.delay(
                        forAttempt: attempts,
                        jitterUnit: jitterSource.nextUnitValue()
                    )
                    do {
                        try await sleeper.sleep(seconds: delay)
                    } catch {
                        return false
                    }
                }
            }
        }
    }

    // MARK: - Completion (applies at most once per operation id)

    private func applySuccess(operationID: UUID, outcome: LibrarySyncOutcome, generation: UInt64) async {
        guard generation == sessionGeneration else { return }
        guard let index = settleIndex(operationID: operationID) else { return }
        let accountID = operations[index].accountID
        // queued → remotelyConfirmed: the outcome is known; from this point
        // the operation must never be submitted again.
        operations[index].state = .remotelyConfirmed
        recordSettledIntentSequence(operations[index])
        markSettled(operationID)
        completedOperationCount += 1
        attemptCounts[operationID] = nil
        await cleanupSettledOperation(operationID: operationID, accountID: accountID, generation: generation)
        guard generation == sessionGeneration else { return }
        postServerAuthoritativeChange(outcome)
        postQueueDidChange()
    }

    private func applyPermanentFailure(operation: LibrarySyncOperation, code: String, generation: UInt64) async {
        guard generation == sessionGeneration else { return }
        guard let index = settleIndex(operationID: operation.id) else { return }
        // A deterministic remote rejection settles the operation exactly
        // like a success: the outcome is known and must never be replayed.
        operations[index].state = .remotelyConfirmed
        recordSettledIntentSequence(operations[index])
        markSettled(operation.id)
        permanentlyFailedOperationCount += 1
        attemptCounts[operation.id] = nil
        // Computed before observers run: is the failed intent already
        // superseded by a newer queued intent for the same entity?
        let supersededByNewerIntent = operations.contains {
            $0.entityKey == operation.entityKey && $0.state == .queued
        }
        print("[Sync] dropped kind=\(operation.entityKind.rawValue) entity=\(operation.entityKey) code=\(code)")
        await cleanupSettledOperation(operationID: operation.id, accountID: operation.accountID, generation: generation)
        guard generation == sessionGeneration else { return }
        var userInfo: [String: Any] = [
            LibrarySyncFailureUserInfoKey.entityKind: operation.entityKind.rawValue,
            LibrarySyncFailureUserInfoKey.gameID: operation.gameIDDescription,
            LibrarySyncFailureUserInfoKey.errorCode: code,
            LibrarySyncFailureUserInfoKey.operationID: operation.id.uuidString,
            LibrarySyncFailureUserInfoKey.supersededByNewerIntent: supersededByNewerIntent
        ]
        if case .setFavorite(_, let isFavorite) = operation.kind {
            userInfo[LibrarySyncFailureUserInfoKey.intendedIsFavorite] = isFavorite
        }
        notificationCenter.post(
            name: .librarySyncOperationDidFail,
            object: nil,
            userInfo: userInfo
        )
        postQueueDidChange()
    }

    /// remotelyConfirmed → locally cleaned: removes every settled record
    /// (the one just confirmed plus any earlier ones whose cleanup write
    /// failed) from the durable queue. When the write fails the confirmed
    /// records stay in memory — skipped by every submission path — so a
    /// later successful write retries the removal instead of the network
    /// mutation.
    private func cleanupSettledOperation(operationID: UUID, accountID: String, generation: UInt64) async {
        await acquireStoreWriteLock()
        defer { releaseStoreWriteLock() }
        guard generation == sessionGeneration,
              operations.contains(where: { $0.id == operationID }) else { return }
        let removed = operations.filter { $0.state == .remotelyConfirmed }
        operations.removeAll { $0.state == .remotelyConfirmed }
        do {
            try await store.persist(operations, accountID: accountID)
        } catch {
            guard generation == sessionGeneration else { return }
            operations.append(contentsOf: removed)
            lastSafeErrorCode = "STORE_CLEANUP_PENDING"
            print("[Sync] cleanup deferred code=STORE_CLEANUP_PENDING")
        }
    }

    /// Drops an operation that belongs to another account from memory
    /// without settling it: its remote outcome is unknown and its durable
    /// record (in its own account's file) must stay intact.
    private func discardForeignOperation(operationID: UUID, generation: UInt64) async {
        guard generation == sessionGeneration else { return }
        operations.removeAll { $0.id == operationID }
        attemptCounts[operationID] = nil
        guard let accountID = activeAccountID else { return }
        _ = await persistCurrentQueue(accountID: accountID, generation: generation)
        guard generation == sessionGeneration else { return }
        postQueueDidChange()
    }

    /// Index of a not-yet-settled queued operation, or nil (duplicate
    /// callback, compaction, or account switch).
    private func settleIndex(operationID: UUID) -> Int? {
        guard !settledOperationIDs.contains(operationID),
              let index = operations.firstIndex(where: { $0.id == operationID }),
              operations[index].state == .queued else {
            return nil
        }
        return index
    }

    private func markSettled(_ operationID: UUID) {
        settledOperationIDs.insert(operationID)
        settledOperationOrder.append(operationID)
        if settledOperationOrder.count > settledCapacity {
            let evicted = settledOperationOrder.removeFirst()
            settledOperationIDs.remove(evicted)
        }
    }

    // MARK: - Signals out

    private func postServerAuthoritativeChange(_ outcome: LibrarySyncOutcome) {
        switch outcome {
        case .favorite(let result):
            notificationCenter.post(
                name: .favoriteDidChange,
                object: nil,
                userInfo: [
                    FavoriteChangeUserInfoKey.gameId: result.gameId,
                    FavoriteChangeUserInfoKey.isFavorite: result.isFavorite,
                    FavoriteChangeUserInfoKey.action: result.isFavorite
                        ? FavoriteChangeAction.added.rawValue
                        : FavoriteChangeAction.removed.rawValue
                ]
            )
        case .libraryStatus:
            notificationCenter.post(
                name: .libraryDidChange,
                object: nil,
                userInfo: [LibraryChangeUserInfoKey.source: "libraryStatusUpdated"]
            )
        }
    }

    private func postQueueDidChange() {
        let pendingOps = operations.filter { $0.state == .queued }
        let parkedKeys = parkedEntityKeys
        let parked = pendingOps.filter { parkedKeys.contains($0.entityKey) }.count
        notificationCenter.post(
            name: .librarySyncQueueDidChange,
            object: nil,
            userInfo: [
                LibrarySyncQueueUserInfoKey.pendingCount: pendingOps.count,
                LibrarySyncQueueUserInfoKey.parkedCount: parked
            ]
        )
    }

    // MARK: - Helpers

    private func unparkAllAndDrain() {
        parkedEntityKeys = []
        attemptCounts = [:]
        drain()
    }

    private func cancelAllEntityTasks() {
        for task in entityTasks.values {
            task.cancel()
        }
        entityTasks = [:]
        inFlightOperationIDs = []
    }

    // MARK: - Introspection (tests + diagnostics)

    var pendingOperations: [LibrarySyncOperation] { operations.filter { $0.state == .queued } }

    /// Callers currently suspended on the account-load gate (tests).
    var accountLoadWaiterCount: Int { accountLoadWaiters.count }

    /// Ids of operations whose request is currently owned by an entity
    /// loop — possibly already on the wire (tests).
    var inFlightOperationIDsSnapshot: Set<UUID> { inFlightOperationIDs }

    var pendingOperationCount: Int { operations.filter { $0.state == .queued }.count }

    /// Confirmed records whose cleanup write is still pending (tests).
    var cleanupPendingOperations: [LibrarySyncOperation] {
        operations.filter { $0.state == .remotelyConfirmed }
    }

    func diagnosticsSnapshot() -> LibrarySyncDiagnosticsSnapshot {
        let parkedKeys = parkedEntityKeys
        let pendingOps = operations.filter { $0.state == .queued }
        return LibrarySyncDiagnosticsSnapshot(
            hasActiveAccount: activeAccountID != nil,
            sessionGeneration: sessionGeneration,
            pendingOperationCount: pendingOps.count,
            parkedOperationCount: pendingOps.filter { parkedKeys.contains($0.entityKey) }.count,
            inFlightEntityCount: entityTasks.count,
            completedOperationCount: completedOperationCount,
            permanentlyFailedOperationCount: permanentlyFailedOperationCount,
            recoveredFromCorruptedStore: recoveredFromCorruptedStore,
            isBlockedOnAuth: isBlockedOnAuth,
            lastSafeErrorCode: lastSafeErrorCode
        )
    }

    /// Test seam for duplicate-callback protection: applies a success
    /// outcome for an operation id exactly as the drain loop would. Returns
    /// whether the completion was applied (false on duplicates).
    func handleTransportSuccess(operationID: UUID, outcome: LibrarySyncOutcome) async -> Bool {
        let hadOperation = settleIndex(operationID: operationID) != nil
        await applySuccess(operationID: operationID, outcome: outcome, generation: sessionGeneration)
        return hadOperation
    }
}
