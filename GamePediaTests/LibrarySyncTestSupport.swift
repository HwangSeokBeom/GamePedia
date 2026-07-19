import XCTest
@testable import GamePedia

// MARK: - Deterministic library-sync test doubles
//
// Same discipline as RealtimeTestSupport: no sleeps, no timing-based polling.
// Transport behavior is scripted per call index; "hold" parks the call on a
// continuation the test resolves explicitly. Expectation timeouts are
// failure watchdogs only — success paths never depend on elapsed time.

enum MockSyncTransportBehavior {
    /// Returns the given outcome, or a default outcome derived from the
    /// operation when nil.
    case success(LibrarySyncOutcome?)
    case failure(Error)
    /// Parks until the test resolves it via `resolveHeld`.
    case hold
}

final class MockLibrarySyncTransport: LibrarySyncTransporting, @unchecked Sendable {
    struct RecordedCall {
        let index: Int
        let operation: LibrarySyncOperation
        /// Authorization expectation the engine bound to this execution
        /// (nil when the engine had no adopted authorization context).
        let authorization: AuthorizationExpectation?
    }

    private let lock = NSLock()
    private var callCount = 0
    private var recordedCalls: [RecordedCall] = []
    private var heldContinuations: [Int: CheckedContinuation<Result<LibrarySyncOutcome, Error>, Never>] = [:]

    /// Behavior per 0-based call index. Called under the lock — keep it pure.
    var behavior: @Sendable (LibrarySyncOperation, Int) -> MockSyncTransportBehavior = { _, _ in .success(nil) }
    /// Fired after the call is recorded (safe place to fulfill expectations).
    var onCall: ((RecordedCall) -> Void)?

    var calls: [RecordedCall] {
        lock.lock()
        defer { lock.unlock() }
        return recordedCalls
    }

    var heldCallIndices: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return heldContinuations.keys.sorted()
    }

    func resolveHeld(index: Int, with result: Result<LibrarySyncOutcome, Error>) {
        lock.lock()
        let continuation = heldContinuations.removeValue(forKey: index)
        lock.unlock()
        continuation?.resume(returning: result)
    }

    /// Resolves a held call with its default success outcome.
    func resolveHeldWithDefaultSuccess(index: Int) {
        lock.lock()
        let continuation = heldContinuations.removeValue(forKey: index)
        let operation = recordedCalls.first { $0.index == index }?.operation
        lock.unlock()
        guard let continuation, let operation else { return }
        continuation.resume(returning: .success(Self.defaultOutcome(for: operation)))
    }

    func perform(
        _ operation: LibrarySyncOperation,
        authorization: AuthorizationExpectation?
    ) async throws -> LibrarySyncOutcome {
        lock.lock()
        let index = callCount
        callCount += 1
        let call = RecordedCall(index: index, operation: operation, authorization: authorization)
        recordedCalls.append(call)
        let resolved = behavior(operation, index)
        let callback = onCall
        lock.unlock()

        switch resolved {
        case .success(let outcome):
            callback?(call)
            return outcome ?? Self.defaultOutcome(for: operation)
        case .failure(let error):
            callback?(call)
            throw error
        case .hold:
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<LibrarySyncOutcome, Error>, Never>) in
                lock.lock()
                heldContinuations[index] = continuation
                lock.unlock()
                callback?(call)
            }
            return try result.get()
        }
    }

    static func defaultOutcome(for operation: LibrarySyncOperation) -> LibrarySyncOutcome {
        switch operation.kind {
        case .setFavorite(let gameID, let isFavorite):
            return .favorite(FavoriteMutationResult(gameId: Int(gameID) ?? -1, isFavorite: isFavorite))
        case .setLibraryStatus(let payload):
            return .libraryStatus(
                LibraryGameStatusMutationResult(
                    identifier: payload.domainRequest.identifier,
                    status: payload.status
                )
            )
        }
    }
}

// MARK: - In-memory store double

struct MockStoreWriteError: Error, Equatable {}

final class InMemorySyncOperationStore: SyncOperationStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: [LibrarySyncOperation]] = [:]
    private(set) var persistCallCount = 0
    private var loadCallCount = 0
    private var heldLoads: [Int: CheckedContinuation<Void, Never>] = [:]

    /// Scripted persist failure per 0-based persist call index. Called under
    /// the lock — keep it pure. Return an error to make that write fail.
    var persistBehavior: @Sendable (_ index: Int, _ operations: [LibrarySyncOperation], _ accountID: String) -> Error? =
        { _, _, _ in nil }
    /// When true, every `load` parks on a continuation until the test calls
    /// `resolveHeldLoad(index:)` — the deterministic account-switch window.
    var holdLoads = false
    /// Fired after a load is recorded (parked or not); receives its index.
    var onLoad: ((Int) -> Void)?

    func seed(_ operations: [LibrarySyncOperation], accountID: String) {
        lock.lock()
        storage[accountID] = operations
        lock.unlock()
    }

    func storedOperations(accountID: String) -> [LibrarySyncOperation] {
        lock.lock()
        defer { lock.unlock() }
        return storage[accountID] ?? []
    }

    var heldLoadIndices: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return heldLoads.keys.sorted()
    }

    func resolveHeldLoad(index: Int) {
        lock.lock()
        let continuation = heldLoads.removeValue(forKey: index)
        lock.unlock()
        continuation?.resume()
    }

    func load(accountID: String) async -> SyncStoreLoadResult {
        lock.lock()
        let index = loadCallCount
        loadCallCount += 1
        let shouldHold = holdLoads
        let callback = onLoad
        lock.unlock()

        if shouldHold {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                lock.lock()
                heldLoads[index] = continuation
                lock.unlock()
                callback?(index)
            }
        } else {
            callback?(index)
        }

        lock.lock()
        defer { lock.unlock() }
        return SyncStoreLoadResult(
            operations: storage[accountID] ?? [],
            recoveredFromCorruption: false
        )
    }

    func persist(_ operations: [LibrarySyncOperation], accountID: String) async throws {
        lock.lock()
        let index = persistCallCount
        persistCallCount += 1
        let error = persistBehavior(index, operations, accountID)
        if error == nil {
            storage[accountID] = operations
        }
        lock.unlock()
        if let error {
            throw error
        }
    }

    func purge(accountID: String) async {
        lock.lock()
        storage[accountID] = nil
        lock.unlock()
    }
}

// MARK: - Router double for view-model tests

final class MockLibraryMutationRouter: LibraryMutationSyncing, @unchecked Sendable {

    /// Scope-currency truth for minted ownership. Mirrors the real
    /// ownership context: exactly one live scope id, never reused.
    private final class ScopeAuthority: @unchecked Sendable {
        private let lock = NSLock()
        private var scopeID = UUID()
        private var isCurrentFlag = true

        var currentScopeID: UUID {
            lock.lock()
            defer { lock.unlock() }
            return scopeID
        }

        var isCurrent: Bool {
            get {
                lock.lock()
                defer { lock.unlock() }
                return isCurrentFlag
            }
            set {
                lock.lock()
                isCurrentFlag = newValue
                lock.unlock()
            }
        }

        func isScopeCurrent(_ id: UUID) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return isCurrentFlag && id == scopeID
        }

        func advance() {
            lock.lock()
            scopeID = UUID()
            isCurrentFlag = true
            lock.unlock()
        }
    }

    private let lock = NSLock()
    private let scopeAuthority: ScopeAuthority
    private var sequencesByEntityKey: [String: UInt64] = [:]
    private var heldEnqueues: [String: CheckedContinuation<LibrarySyncEnqueueResult, Never>] = [:]
    private(set) var favoriteChanges: [(gameID: String, isFavorite: Bool)] = []
    private(set) var statusUpdates: [LibraryGameStatusUpdateRequest] = []
    private(set) var capturedOwnerships: [LibraryMutationOwnership] = []
    private(set) var enqueuedOwnerships: [LibraryMutationOwnership] = []
    private(set) var ownershipRevalidationCount = 0
    private(set) var retryNowCallCount = 0
    /// Result every enqueue reports. Non-accepted results are terminal:
    /// callers reconcile the optimistic UI, never call a repository.
    var enqueueResult: LibrarySyncEnqueueResult = .accepted
    /// Account minted into captured ownership; nil simulates a guest gesture
    /// (capture fails and the caller uses the direct path).
    var accountID: String? = "mock-user"
    var pendingFavoriteIntentValue: Bool?
    /// When true, every enqueue parks until the test resolves it via
    /// `resolveHeldEnqueue` — the deterministic Task-arrival inversion
    /// window for fallback-ordering tests.
    var holdEnqueues = false
    /// Fired after an enqueue is recorded (safe place to fulfill expectations).
    var onEnqueue: (() -> Void)?
    /// Fired after retryNow is recorded.
    var onRetryNow: (() -> Void)?
    /// Fired after an ownership revalidation (`isNewestOwnedIntent`) is
    /// recorded.
    var onOwnershipRevalidation: (() -> Void)?

    init() {
        scopeAuthority = ScopeAuthority()
    }

    /// Set false to simulate the owning scope ending between gesture and
    /// completion (`isNewestOwnedIntent` then reports false).
    var ownershipIsCurrent: Bool {
        get { scopeAuthority.isCurrent }
        set { scopeAuthority.isCurrent = newValue }
    }

    /// Replaces the live scope with a fresh id (account replacement or
    /// A → B → A re-login). Sequences restart per scope, like the real
    /// ownership context.
    func advanceScope() {
        lock.lock()
        sequencesByEntityKey = [:]
        lock.unlock()
        scopeAuthority.advance()
    }

    func resolveHeldEnqueue(
        entityKey: String,
        sequence: UInt64,
        with result: LibrarySyncEnqueueResult
    ) {
        lock.lock()
        let continuation = heldEnqueues.removeValue(forKey: "\(entityKey)#\(sequence)")
        lock.unlock()
        continuation?.resume(returning: result)
    }

    func captureFavoriteIntent(gameID: String, isFavorite: Bool) -> LibraryMutationOwnership? {
        mintOwnership(
            entityKey: LibrarySyncEntityKey.favorite(gameID: gameID),
            intendedState: .favorite(isFavorite: isFavorite)
        )
    }

    func captureLibraryStatusIntent(_ request: LibraryGameStatusUpdateRequest) -> LibraryMutationOwnership? {
        mintOwnership(
            entityKey: LibrarySyncEntityKey.libraryStatus(
                source: request.gameSource,
                externalGameID: request.externalGameId
            ),
            intendedState: .libraryStatus(request.status)
        )
    }

    func isNewestOwnedIntent(_ ownership: LibraryMutationOwnership) -> Bool {
        lock.lock()
        ownershipRevalidationCount += 1
        let newestSequence = sequencesByEntityKey[ownership.entityKey]
        let callback = onOwnershipRevalidation
        lock.unlock()
        let result = scopeAuthority.isScopeCurrent(ownership.scopeID)
            && newestSequence == ownership.sequence
        callback?()
        return result
    }

    func enqueueFavoriteChange(
        gameID: String,
        isFavorite: Bool,
        ownership: LibraryMutationOwnership
    ) async -> LibrarySyncEnqueueResult {
        lock.lock()
        favoriteChanges.append((gameID, isFavorite))
        enqueuedOwnerships.append(ownership)
        let result = enqueueResult
        let shouldHold = holdEnqueues
        let callback = onEnqueue
        lock.unlock()
        guard shouldHold else {
            callback?()
            return result
        }
        return await withCheckedContinuation { continuation in
            lock.lock()
            heldEnqueues["\(ownership.entityKey)#\(ownership.sequence)"] = continuation
            lock.unlock()
            callback?()
        }
    }

    func enqueueLibraryStatusUpdate(
        _ request: LibraryGameStatusUpdateRequest,
        ownership: LibraryMutationOwnership
    ) async -> LibrarySyncEnqueueResult {
        lock.lock()
        statusUpdates.append(request)
        enqueuedOwnerships.append(ownership)
        let result = enqueueResult
        let shouldHold = holdEnqueues
        let callback = onEnqueue
        lock.unlock()
        guard shouldHold else {
            callback?()
            return result
        }
        return await withCheckedContinuation { continuation in
            lock.lock()
            heldEnqueues["\(ownership.entityKey)#\(ownership.sequence)"] = continuation
            lock.unlock()
            callback?()
        }
    }

    func pendingFavoriteIntent(gameID: String) async -> Bool? {
        pendingFavoriteIntentValue
    }

    func retryNow() async {
        lock.lock()
        retryNowCallCount += 1
        let callback = onRetryNow
        lock.unlock()
        callback?()
    }

    private func mintOwnership(
        entityKey: String,
        intendedState: LibraryMutationIntendedState
    ) -> LibraryMutationOwnership? {
        lock.lock()
        defer { lock.unlock() }
        guard let accountID else { return nil }
        let sequence = (sequencesByEntityKey[entityKey] ?? 0) + 1
        sequencesByEntityKey[entityKey] = sequence
        let ownership = LibraryMutationOwnership(
            accountID: accountID,
            scopeID: scopeAuthority.currentScopeID,
            generation: 1,
            entityKey: entityKey,
            sequence: sequence,
            intendedState: intendedState
        )
        capturedOwnerships.append(ownership)
        return ownership
    }
}

// MARK: - Capture-at-enqueue conveniences for pre-ownership engine tests
//
// Engine tests written before gesture ownership existed enqueue while a
// known account is active and never interleave a session change between
// gesture and submission, so capturing immediately before enqueue preserves
// their semantics exactly. Ownership/ordering interleaving tests capture
// explicitly instead.

extension LibrarySyncEngine {
    func enqueueFavoriteChange(gameID: String, isFavorite: Bool) async -> LibrarySyncEnqueueResult {
        guard let ownership = captureFavoriteIntent(gameID: gameID, isFavorite: isFavorite) else {
            return .serviceUnavailable
        }
        return await enqueueFavoriteChange(gameID: gameID, isFavorite: isFavorite, ownership: ownership)
    }

    func enqueueLibraryStatusUpdate(_ request: LibraryGameStatusUpdateRequest) async -> LibrarySyncEnqueueResult {
        guard let ownership = captureLibraryStatusIntent(request) else {
            return .serviceUnavailable
        }
        return await enqueueLibraryStatusUpdate(request, ownership: ownership)
    }
}

// MARK: - Notification recording
//
// Deterministic negative assertions: instead of inverted expectations
// (timing-based), tests record every posted notification and, after awaiting
// a later deterministic signal, assert on the recorded order/counts.

final class NotificationRecorder {
    private let lock = NSLock()
    private var recorded: [Notification] = []
    private var observers: [NSObjectProtocol] = []
    private let center: NotificationCenter

    init(center: NotificationCenter, names: [Notification.Name]) {
        self.center = center
        for name in names {
            observers.append(
                center.addObserver(forName: name, object: nil, queue: nil) { [weak self] notification in
                    guard let self else { return }
                    self.lock.lock()
                    self.recorded.append(notification)
                    self.lock.unlock()
                }
            )
        }
    }

    deinit {
        for observer in observers {
            center.removeObserver(observer)
        }
    }

    var notifications: [Notification] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func count(of name: Notification.Name) -> Int {
        notifications.filter { $0.name == name }.count
    }
}

// MARK: - Factories

func makeSyncEngine(
    store: any SyncOperationStoring,
    transport: any LibrarySyncTransporting,
    notificationCenter: NotificationCenter,
    sleeper: RealtimeSleeping = TestRealtimeSleeper(autoResume: true),
    jitterUnit: Double = 0,
    maxAutomaticAttempts: Int = 3,
    baseDelay: TimeInterval = 2
) -> LibrarySyncEngine {
    var configuration = LibrarySyncEngine.Configuration()
    configuration.retryPolicy = ReconnectPolicy(
        baseDelay: baseDelay,
        multiplier: 2,
        maxDelay: 60,
        maxJitterFraction: 0.25
    )
    configuration.maxAutomaticAttempts = maxAutomaticAttempts
    return LibrarySyncEngine(
        store: store,
        transport: transport,
        configuration: configuration,
        jitterSource: FixedJitterSource(unitValue: jitterUnit),
        sleeper: sleeper,
        notificationCenter: notificationCenter,
        now: { Date(timeIntervalSince1970: 1_000) }
    )
}

func makeStatusRequest(
    externalGameID: String = "570",
    source: GameSource = .steam,
    title: String = "Dota 2",
    status: UserGameStatus = .playing
) -> LibraryGameStatusUpdateRequest {
    LibraryGameStatusUpdateRequest(
        identifier: LibraryGameIdentifier(
            source: source,
            sourceID: externalGameID,
            canonicalGameID: nil
        ),
        title: title,
        coverImageURL: nil,
        status: status
    )
}

extension XCTestCase {
    /// Expectation for the next notification on a private test center.
    /// The timeout is a failure watchdog, not a synchronization mechanism.
    func notificationExpectation(
        _ name: Notification.Name,
        center: NotificationCenter,
        handler: ((Notification) -> Bool)? = nil
    ) -> XCTestExpectation {
        XCTNSNotificationExpectation(name: name, object: nil, notificationCenter: center)
            .configured(handler: handler)
    }
}

private extension XCTNSNotificationExpectation {
    func configured(handler: ((Notification) -> Bool)?) -> XCTNSNotificationExpectation {
        if let handler {
            self.handler = handler
        }
        return self
    }
}
