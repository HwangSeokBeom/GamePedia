import Foundation

// MARK: - LibrarySyncEngine
//
// Actor-isolated offline-first queue for library mutations.
//
// Invariants (each covered by deterministic tests):
// - every user intent gets exactly one operation with a stable idempotency
//   key (`LibrarySyncOperation.id`); retries reuse the operation verbatim
// - operations are scoped to the authenticated account; a different account
//   can never submit them, and switching accounts swaps the whole queue
// - per entity key, execution is strictly FIFO; independent entities may
//   sync in parallel
// - enqueueing supersedes older *pending* operations for the same entity
//   (absolute-state semantics make keep-only-newest compaction safe);
//   in-flight operations are never compacted away mid-request
// - transient failures preserve work and retry with capped exponential
//   backoff + bounded injected jitter; after the automatic-attempt cap the
//   entity parks until a manual retry / foreground / connectivity event
// - permanent validation failures are dropped immediately and surfaced —
//   never retried forever
// - auth failures pause the whole queue (work preserved) until the next
//   authenticated session event; the engine never triggers a token refresh
//   itself
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
    /// Returns false when no authenticated account is active; callers fall
    /// back to the direct (legacy) mutation path.
    func enqueueFavoriteChange(gameID: String, isFavorite: Bool) async -> Bool
    func enqueueLibraryStatusUpdate(_ request: LibraryGameStatusUpdateRequest) async -> Bool
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

    private var activeAccountID: String?
    private var sessionGeneration: UInt64 = 0
    private var operations: [LibrarySyncOperation] = []
    private var inFlightOperationIDs: Set<UUID> = []
    private var parkedEntityKeys: Set<String> = []
    private var attemptCounts: [UUID: Int] = [:]
    private var entityTasks: [String: Task<Void, Never>] = [:]
    private var isBlockedOnAuth = false

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
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.transport = transport
        self.configuration = configuration
        self.jitterSource = jitterSource
        self.sleeper = sleeper
        self.notificationCenter = notificationCenter
        self.now = now
    }

    // MARK: - Session lifecycle

    func sessionDidChange(isAuthenticated: Bool, userID: String?) async {
        sessionGeneration &+= 1
        cancelAllEntityTasks()
        isBlockedOnAuth = false

        guard isAuthenticated, let userID, !userID.isEmpty else {
            // Logout / supersession / refresh failure: persisted operations
            // stay isolated on disk for this account; nothing is submitted
            // while unauthenticated.
            activeAccountID = nil
            operations = []
            attemptCounts = [:]
            parkedEntityKeys = []
            postQueueDidChange()
            return
        }

        if userID != activeAccountID {
            activeAccountID = userID
            attemptCounts = [:]
            parkedEntityKeys = []
            let generation = sessionGeneration
            let result = await store.load(accountID: userID)
            guard generation == sessionGeneration else { return }
            if result.recoveredFromCorruption {
                recoveredFromCorruptedStore = true
                lastSafeErrorCode = "STORE_CORRUPTED"
            }
            // Defensive account isolation: never adopt records stamped for a
            // different account, whatever the file claimed.
            operations = result.operations.filter { $0.accountID == userID }
        } else {
            // Same account re-authenticated (e.g. token refresh): parked
            // work gets a fresh automatic-retry budget.
            parkedEntityKeys = []
            attemptCounts = [:]
        }
        postQueueDidChange()
        drain()
    }

    func accountDidDelete(userID: String) async {
        await store.purge(accountID: userID)
        if userID == activeAccountID {
            sessionGeneration &+= 1
            cancelAllEntityTasks()
            activeAccountID = nil
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

    // MARK: - LibraryMutationSyncing

    func enqueueFavoriteChange(gameID: String, isFavorite: Bool) async -> Bool {
        await enqueue(kind: .setFavorite(gameID: gameID, isFavorite: isFavorite))
    }

    func enqueueLibraryStatusUpdate(_ request: LibraryGameStatusUpdateRequest) async -> Bool {
        await enqueue(kind: .setLibraryStatus(LibraryStatusSyncPayload(request: request)))
    }

    func pendingFavoriteIntent(gameID: String) async -> Bool? {
        let key = "favorite:\(gameID)"
        for operation in operations.reversed() where operation.entityKey == key {
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

    private func enqueue(kind: LibrarySyncOperationKind) async -> Bool {
        guard let accountID = activeAccountID else {
            return false
        }
        let operation = LibrarySyncOperation(
            id: UUID(),
            accountID: accountID,
            kind: kind,
            createdAt: now()
        )
        // Compaction: pending (not in-flight) operations for the same entity
        // are superseded — every operation kind sets absolute state, so only
        // the newest intent matters. FIFO order per entity is preserved
        // because the survivor is always the newest.
        operations.removeAll { existing in
            existing.entityKey == operation.entityKey
                && !inFlightOperationIDs.contains(existing.id)
        }
        operations.append(operation)
        // A new user intent on this entity earns a fresh automatic budget.
        parkedEntityKeys.remove(operation.entityKey)
        print("[Sync] accepted kind=\(operation.entityKind.rawValue) entity=\(operation.entityKey)")
        await persist()
        postQueueDidChange()
        drain()
        return true
    }

    private func persist() async {
        guard let accountID = activeAccountID else { return }
        await store.persist(operations, accountID: accountID)
    }

    // MARK: - Drain

    private func drain() {
        guard activeAccountID != nil, !isBlockedOnAuth else { return }
        var seenKeys = Set<String>()
        for operation in operations {
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
        operations.first { $0.entityKey == entityKey && !inFlightOperationIDs.contains($0.id) }
    }

    /// Returns true when the entity loop should continue with its next
    /// operation, false when it must stop (cancellation, stale generation,
    /// auth pause, or parking).
    private func performWithRetry(_ operation: LibrarySyncOperation, generation: UInt64) async -> Bool {
        guard operation.accountID == activeAccountID else {
            // Defensive: never submit an operation owned by another account.
            _ = settle(operationID: operation.id)
            await persist()
            postQueueDidChange()
            return true
        }

        while true {
            guard generation == sessionGeneration, !Task.isCancelled else { return false }

            do {
                let outcome = try await transport.perform(operation)
                guard generation == sessionGeneration else {
                    // Late completion from a superseded session: inert.
                    return false
                }
                await applySuccess(operationID: operation.id, outcome: outcome)
                return true
            } catch is CancellationError {
                return false
            } catch {
                guard generation == sessionGeneration, !Task.isCancelled else { return false }
                let failure = LibrarySyncFailureClassifier.classify(error)
                lastSafeErrorCode = failure.code

                switch failure {
                case .permanent(let code):
                    await applyPermanentFailure(operation: operation, code: code)
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

    private func applySuccess(operationID: UUID, outcome: LibrarySyncOutcome) async {
        guard settle(operationID: operationID) else { return }
        completedOperationCount += 1
        await persist()
        postServerAuthoritativeChange(outcome)
        postQueueDidChange()
    }

    private func applyPermanentFailure(operation: LibrarySyncOperation, code: String) async {
        guard settle(operationID: operation.id) else { return }
        permanentlyFailedOperationCount += 1
        print("[Sync] dropped kind=\(operation.entityKind.rawValue) entity=\(operation.entityKey) code=\(code)")
        await persist()
        notificationCenter.post(
            name: .librarySyncOperationDidFail,
            object: nil,
            userInfo: [
                LibrarySyncFailureUserInfoKey.entityKind: operation.entityKind.rawValue,
                LibrarySyncFailureUserInfoKey.gameID: operation.gameIDDescription,
                LibrarySyncFailureUserInfoKey.errorCode: code
            ]
        )
        postQueueDidChange()
    }

    /// Removes the operation from the queue exactly once. Returns false when
    /// the operation was already settled or no longer exists (duplicate
    /// callback, compaction, or account switch).
    private func settle(operationID: UUID) -> Bool {
        guard !settledOperationIDs.contains(operationID),
              let index = operations.firstIndex(where: { $0.id == operationID }) else {
            return false
        }
        operations.remove(at: index)
        attemptCounts[operationID] = nil
        settledOperationIDs.insert(operationID)
        settledOperationOrder.append(operationID)
        if settledOperationOrder.count > settledCapacity {
            let evicted = settledOperationOrder.removeFirst()
            settledOperationIDs.remove(evicted)
        }
        return true
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
        let pending = operations.count
        let parkedKeys = parkedEntityKeys
        let parked = operations.filter { parkedKeys.contains($0.entityKey) }.count
        notificationCenter.post(
            name: .librarySyncQueueDidChange,
            object: nil,
            userInfo: [
                LibrarySyncQueueUserInfoKey.pendingCount: pending,
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

    var pendingOperations: [LibrarySyncOperation] { operations }

    var pendingOperationCount: Int { operations.count }

    func diagnosticsSnapshot() -> LibrarySyncDiagnosticsSnapshot {
        let parkedKeys = parkedEntityKeys
        return LibrarySyncDiagnosticsSnapshot(
            hasActiveAccount: activeAccountID != nil,
            sessionGeneration: sessionGeneration,
            pendingOperationCount: operations.count,
            parkedOperationCount: operations.filter { parkedKeys.contains($0.entityKey) }.count,
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
        let hadOperation = operations.contains { $0.id == operationID }
            && !settledOperationIDs.contains(operationID)
        await applySuccess(operationID: operationID, outcome: outcome)
        return hadOperation
    }
}
