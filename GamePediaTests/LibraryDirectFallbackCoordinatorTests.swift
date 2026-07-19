import XCTest
@testable import GamePedia

// HIGH-1 — authenticated direct fallback must preserve gesture-time intent
// ordering.
//
// When enqueue reports `.storageBlocked` / `.serviceUnavailable`, every
// ViewModel routes its direct repository mutation through ONE shared
// coordinator (hosted by the engine / router). These tests prove, along the
// actual ViewModel → router → coordinator → use case → repository path:
//
// - a lower gesture sequence never commits after a higher one, whatever the
//   Task arrival or transport completion order
// - requests for one (scope, entity) are serialized; an already-sent
//   request is never cancelled (non-cooperative transports)
// - exactly one network request per accepted sequence; suppressed
//   sequences never reach the network
// - scope lifecycle (logout, A → B, A → B → A, deletion, same-account
//   refresh) invalidates or preserves fallback state exactly like the
//   engine's ownership semantics
// - distinct entities and distinct accounts never block each other
//
// Deterministic throughout: enqueues and repository calls park on
// continuations the test resolves explicitly, coordinator milestones and
// fallback resolutions gate every step, and expectation timeouts are
// failure watchdogs only. No sleeps.
final class LibraryDirectFallbackCoordinatorTests: XCTestCase {

    // MARK: - Deterministic event watching

    /// Records equatable events and vends watchdog expectations that
    /// fulfill when (or as soon as) a matching event was recorded.
    private final class EventWatcher<Event: Equatable>: @unchecked Sendable {
        private let lock = NSLock()
        private var recorded: [Event] = []
        private var watchers: [(event: Event, expectation: XCTestExpectation)] = []

        func record(_ event: Event) {
            lock.lock()
            recorded.append(event)
            let matched = watchers.filter { $0.event == event }.map(\.expectation)
            lock.unlock()
            matched.forEach { $0.fulfill() }
        }

        func expectation(for event: Event, _ description: String) -> XCTestExpectation {
            let expectation = XCTestExpectation(description: description)
            expectation.assertForOverFulfill = false
            lock.lock()
            let alreadySeen = recorded.contains(event)
            watchers.append((event, expectation))
            lock.unlock()
            if alreadySeen {
                expectation.fulfill()
            }
            return expectation
        }

        var events: [Event] {
            lock.lock()
            defer { lock.unlock() }
            return recorded
        }
    }

    private struct ResolutionEvent: Equatable {
        let entityKey: String
        let sequence: UInt64
        let resolution: MockLibraryMutationRouter.FallbackResolution
    }

    private typealias MilestoneWatcher = EventWatcher<LibraryDirectFallbackMilestone>
    private typealias ResolutionWatcher = EventWatcher<ResolutionEvent>

    private func attachResolutionWatcher(to router: MockLibraryMutationRouter) -> ResolutionWatcher {
        let watcher = ResolutionWatcher()
        router.onFallbackResolved = { ownership, resolution in
            watcher.record(
                ResolutionEvent(
                    entityKey: ownership.entityKey,
                    sequence: ownership.sequence,
                    resolution: resolution
                )
            )
        }
        return watcher
    }

    private func attachMilestoneWatcher(
        to coordinator: LibraryDirectMutationCoordinator
    ) async -> MilestoneWatcher {
        let watcher = MilestoneWatcher()
        await coordinator.setMilestoneHandler { watcher.record($0) }
        return watcher
    }

    // MARK: - Repository doubles (holdable, deterministic)

    private struct ScriptedRepositoryError: Error, Equatable {}
    private struct UnsupportedTestCallError: Error {}

    private final class HoldableFavoriteRepository: FavoriteRepository, @unchecked Sendable {
        enum Mutation: Equatable, Hashable {
            case add(String)
            case remove(String)
        }

        private let lock = NSLock()
        private var callIndex = 0
        private var heldCalls: [Int: CheckedContinuation<Void, Never>] = [:]
        private var parkedIndices: Set<Int> = []
        private var parkedWatchers: [(index: Int, expectation: XCTestExpectation)] = []
        private(set) var startedMutations: [Mutation] = []
        private(set) var completedMutations: [Mutation] = []
        /// When true, every mutation parks until `resolveHeld(index:)` —
        /// the deterministic "request is on the wire" window.
        var holdMutations = false
        /// Scripted error per 0-based call index, thrown after release.
        var errorBehavior: @Sendable (Int) -> Error? = { _ in nil }
        /// Fired once the call is recorded (and parked, when holding).
        var onMutationStart: ((Int, Mutation) -> Void)?

        /// Watchdog that fulfills once call `index` is parked on the wire.
        /// Await it BEFORE `resolveHeld(index:)` — resolving a call that
        /// has not parked yet would silently no-op.
        func expectParked(index: Int, _ description: String) -> XCTestExpectation {
            let expectation = XCTestExpectation(description: description)
            expectation.assertForOverFulfill = false
            lock.lock()
            let alreadyParked = parkedIndices.contains(index)
            parkedWatchers.append((index, expectation))
            lock.unlock()
            if alreadyParked {
                expectation.fulfill()
            }
            return expectation
        }

        func resolveHeld(index: Int) {
            lock.lock()
            let continuation = heldCalls.removeValue(forKey: index)
            lock.unlock()
            continuation?.resume()
        }

        func addFavorite(gameId: String) async throws -> FavoriteMutationResult {
            try await perform(.add(gameId))
            return FavoriteMutationResult(gameId: Int(gameId) ?? -1, isFavorite: true)
        }

        func removeFavorite(gameId: String) async throws -> FavoriteMutationResult {
            try await perform(.remove(gameId))
            return FavoriteMutationResult(gameId: Int(gameId) ?? -1, isFavorite: false)
        }

        func fetchMyFavorites(sort: FavoriteSortOption?) async throws -> [FavoriteItem] { [] }

        func fetchFavoriteStatus(gameId: String) async throws -> FavoriteStatus {
            FavoriteStatus(isFavorite: false)
        }

        private func perform(_ mutation: Mutation) async throws {
            lock.lock()
            let index = callIndex
            callIndex += 1
            startedMutations.append(mutation)
            let shouldHold = holdMutations
            let callback = onMutationStart
            lock.unlock()

            if shouldHold {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    lock.lock()
                    heldCalls[index] = continuation
                    parkedIndices.insert(index)
                    let watchers = parkedWatchers.filter { $0.index == index }.map(\.expectation)
                    lock.unlock()
                    watchers.forEach { $0.fulfill() }
                    callback?(index, mutation)
                }
            } else {
                callback?(index, mutation)
            }

            lock.lock()
            let error = errorBehavior(index)
            completedMutations.append(mutation)
            lock.unlock()
            if let error {
                throw error
            }
        }
    }

    private final class HoldableLibraryRepository: LibraryRepository, @unchecked Sendable {
        private let lock = NSLock()
        private var callIndex = 0
        private var heldCalls: [Int: CheckedContinuation<Void, Never>] = [:]
        private(set) var startedStatuses: [UserGameStatus] = []
        private(set) var completedStatuses: [UserGameStatus] = []
        var holdMutations = false
        var onMutationStart: ((Int, UserGameStatus) -> Void)?

        func resolveHeld(index: Int) {
            lock.lock()
            let continuation = heldCalls.removeValue(forKey: index)
            lock.unlock()
            continuation?.resume()
        }

        func updateGameStatus(
            request: LibraryGameStatusUpdateRequest
        ) async throws -> LibraryGameStatusMutationResult {
            lock.lock()
            let index = callIndex
            callIndex += 1
            startedStatuses.append(request.status)
            let shouldHold = holdMutations
            let callback = onMutationStart
            lock.unlock()

            if shouldHold {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    lock.lock()
                    heldCalls[index] = continuation
                    lock.unlock()
                    callback?(index, request.status)
                }
            } else {
                callback?(index, request.status)
            }

            lock.lock()
            completedStatuses.append(request.status)
            lock.unlock()
            return LibraryGameStatusMutationResult(
                identifier: request.identifier,
                status: request.status
            )
        }

        func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverview {
            throw UnsupportedTestCallError()
        }
        func fetchOwnedLibrary() async throws -> OwnedLibraryCollection {
            throw UnsupportedTestCallError()
        }
        func fetchPlayingLibrary() async throws -> [LibraryGameSummary] {
            throw UnsupportedTestCallError()
        }
        func fetchRecentlyPlayedLibrary() async throws -> [LibraryGameSummary] {
            throw UnsupportedTestCallError()
        }
        func fetchPlaytimeRecommendations() async throws -> [PlaytimeRecommendation] {
            throw UnsupportedTestCallError()
        }
        func fetchInAppFriendRecommendations() async throws -> [SteamFriendRecommendation] {
            throw UnsupportedTestCallError()
        }
        func fetchSteamFriendRecommendations() async throws -> [SteamFriendRecommendation] {
            throw UnsupportedTestCallError()
        }
        func fetchSteamLinkStatus() async throws -> SteamLinkStatus {
            throw UnsupportedTestCallError()
        }
        func startSteamLink() async throws -> URL {
            throw UnsupportedTestCallError()
        }
        func unlinkSteamAccount() async throws -> SteamUnlinkResult {
            throw UnsupportedTestCallError()
        }
        func syncOwnedSteamLibrary() async throws -> SteamOwnedLibrarySyncResult {
            throw UnsupportedTestCallError()
        }
    }

    /// Thread-safe log of applied fallback outcomes for direct
    /// engine-contract calls (no router recording available).
    private final class AppliedSequenceLog: @unchecked Sendable {
        private let lock = NSLock()
        private var applied: [UInt64] = []
        private var suppressed: [UInt64] = []

        func recordApplied(_ sequence: UInt64) {
            lock.lock()
            applied.append(sequence)
            lock.unlock()
        }

        func recordSuppressed(_ sequence: UInt64) {
            lock.lock()
            suppressed.append(sequence)
            lock.unlock()
        }

        var appliedSequences: [UInt64] {
            lock.lock()
            defer { lock.unlock() }
            return applied
        }

        var suppressedSequences: [UInt64] {
            lock.lock()
            defer { lock.unlock() }
            return suppressed
        }
    }

    // MARK: - Shared fixtures

    private var center: NotificationCenter!
    private var transport: MockLibrarySyncTransport!
    private var store: InMemorySyncOperationStore!

    override func setUp() {
        super.setUp()
        center = NotificationCenter()
        transport = MockLibrarySyncTransport()
        store = InMemorySyncOperationStore()
    }

    /// Engine whose durable writes always fail: every authenticated enqueue
    /// reports `.storageBlocked` and legitimately reaches the fallback.
    private func makeStorageBlockedEngine(accountID: String = "user-1") async -> LibrarySyncEngine {
        store.persistBehavior = { _, _, _ in MockStoreWriteError() }
        let engine = makeSyncEngine(store: store, transport: transport, notificationCenter: center)
        await engine.sessionDidChange(isAuthenticated: true, userID: accountID)
        return engine
    }

    private func makeHomeGameListViewModel(
        repository: HoldableFavoriteRepository,
        librarySync: any LibraryMutationSyncing,
        wishlistedGameIDs: Set<Int> = []
    ) -> HomeGameListViewModel {
        HomeGameListViewModel(
            section: .popular,
            games: [],
            wishlistedGameIDs: wishlistedGameIDs,
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: repository),
            librarySync: librarySync
        )
    }

    /// Watchdog that fulfills once `count` submissions are parked inside a
    /// held enqueue. Install BEFORE sending gestures: `resolveHeldEnqueue`
    /// only resolves a submission that has actually parked.
    private func expectParkedEnqueues(
        _ router: MockLibraryMutationRouter,
        count: Int
    ) -> XCTestExpectation {
        let parked = XCTestExpectation(description: "\(count) submissions parked in enqueue")
        parked.expectedFulfillmentCount = count
        router.onEnqueue = { parked.fulfill() }
        return parked
    }

    // MARK: - Favorite: reversed Task arrival (storageBlocked)

    // Matrix 1, 3, 7, 8: add seq1 / remove seq2, seq2's Task reaches the
    // coordinator first; the late seq1 must be suppressed without
    // networking and the server must end at seq2's state.
    func testStorageBlockedReversedArrivalCommitsOnlyTheNewestFavoriteIntent() async {
        let repository = HoldableFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .storageBlocked
        router.holdEnqueues = true
        let resolutions = attachResolutionWatcher(to: router)
        let viewModel = makeHomeGameListViewModel(repository: repository, librarySync: router)
        let entityKey = LibrarySyncEntityKey.favorite(gameID: "1")

        // Gesture order: add (seq1), then remove (seq2). Both submission
        // Tasks park inside enqueue, giving full control of arrival order.
        let parked = expectParkedEnqueues(router, count: 2)
        viewModel.send(.didTapFavorite(gameId: 1))
        viewModel.send(.didTapFavorite(gameId: 1))
        XCTAssertEqual(router.capturedOwnerships.map(\.sequence), [1, 2])
        await fulfillment(of: [parked], timeout: 10)

        // Reverse arrival: seq2 reaches the coordinator (and the network)
        // first…
        let newerResolved = resolutions.expectation(
            for: ResolutionEvent(entityKey: entityKey, sequence: 2, resolution: .success),
            "seq2 executed and applied"
        )
        router.resolveHeldEnqueue(entityKey: entityKey, sequence: 2, with: .storageBlocked)
        await fulfillment(of: [newerResolved], timeout: 10)

        // …then the older seq1 arrives late and must die without a request.
        let olderSuppressed = resolutions.expectation(
            for: ResolutionEvent(entityKey: entityKey, sequence: 1, resolution: .suppressed),
            "seq1 suppressed without networking"
        )
        router.resolveHeldEnqueue(entityKey: entityKey, sequence: 1, with: .storageBlocked)
        await fulfillment(of: [olderSuppressed], timeout: 10)

        // Exactly one request (seq2's), and the server ends at remove.
        XCTAssertEqual(repository.completedMutations, [.remove("1")])
        XCTAssertEqual(repository.startedMutations, [.remove("1")])
    }

    // Matrix 3 for the serviceUnavailable trigger.
    func testServiceUnavailableReversedArrivalSuppressesTheOlderIntent() async {
        let repository = HoldableFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .serviceUnavailable
        router.holdEnqueues = true
        let resolutions = attachResolutionWatcher(to: router)
        let viewModel = makeHomeGameListViewModel(repository: repository, librarySync: router)
        let entityKey = LibrarySyncEntityKey.favorite(gameID: "6")

        let parked = expectParkedEnqueues(router, count: 2)
        viewModel.send(.didTapFavorite(gameId: 6))
        viewModel.send(.didTapFavorite(gameId: 6))
        await fulfillment(of: [parked], timeout: 10)

        let newerResolved = resolutions.expectation(
            for: ResolutionEvent(entityKey: entityKey, sequence: 2, resolution: .success),
            "seq2 executed and applied"
        )
        router.resolveHeldEnqueue(entityKey: entityKey, sequence: 2, with: .serviceUnavailable)
        await fulfillment(of: [newerResolved], timeout: 10)

        let olderSuppressed = resolutions.expectation(
            for: ResolutionEvent(entityKey: entityKey, sequence: 1, resolution: .suppressed),
            "seq1 suppressed without networking"
        )
        router.resolveHeldEnqueue(entityKey: entityKey, sequence: 1, with: .serviceUnavailable)
        await fulfillment(of: [olderSuppressed], timeout: 10)

        XCTAssertEqual(repository.completedMutations, [.remove("6")])
    }

    // MARK: - Favorite: older request already running (non-cooperative)

    // Matrix 2, 5, 6: seq1's request is already on the wire (and cannot be
    // retracted). seq2 must wait — never cancel seq1, never run
    // concurrently — and commit strictly after seq1's transport completes,
    // even though seq1 completes last relative to seq2's arrival.
    func testOlderRunningRequestIsNeverCancelledAndNewestCommitsLast() async {
        let repository = HoldableFavoriteRepository()
        repository.holdMutations = true
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .storageBlocked
        router.holdEnqueues = true
        let resolutions = attachResolutionWatcher(to: router)
        let milestones = await attachMilestoneWatcher(to: router.directFallbackCoordinator)
        let viewModel = makeHomeGameListViewModel(repository: repository, librarySync: router)
        let entityKey = LibrarySyncEntityKey.favorite(gameID: "2")

        let parked = expectParkedEnqueues(router, count: 2)
        viewModel.send(.didTapFavorite(gameId: 2))
        viewModel.send(.didTapFavorite(gameId: 2))
        await fulfillment(of: [parked], timeout: 10)

        // seq1 (add) starts first and parks on the wire.
        let olderStarted = milestones.expectation(
            for: .started(entityKey: entityKey, sequence: 1),
            "seq1 request started"
        )
        router.resolveHeldEnqueue(entityKey: entityKey, sequence: 1, with: .storageBlocked)
        await fulfillment(of: [olderStarted], timeout: 10)
        XCTAssertEqual(repository.startedMutations, [.add("2")])

        // seq2 (remove) arrives while seq1 is in flight: it must wait.
        let newerWaiting = milestones.expectation(
            for: .waiting(entityKey: entityKey, sequence: 2),
            "seq2 parked behind the running seq1"
        )
        router.resolveHeldEnqueue(entityKey: entityKey, sequence: 2, with: .storageBlocked)
        await fulfillment(of: [newerWaiting], timeout: 10)
        XCTAssertEqual(
            repository.startedMutations, [.add("2")],
            "the newer sequence must not open a concurrent request"
        )

        // The non-cooperative seq1 request completes (it was never
        // cancelled), then — and only then — seq2 starts and commits last.
        let newerStarted = milestones.expectation(
            for: .started(entityKey: entityKey, sequence: 2),
            "seq2 started after seq1 finished"
        )
        await fulfillment(of: [repository.expectParked(index: 0, "seq1 on the wire")], timeout: 10)
        repository.resolveHeld(index: 0)
        await fulfillment(of: [newerStarted], timeout: 10)
        XCTAssertEqual(
            repository.completedMutations, [.add("2")],
            "seq1's transport completed; it was not cancelled"
        )

        let newerResolved = resolutions.expectation(
            for: ResolutionEvent(entityKey: entityKey, sequence: 2, resolution: .success),
            "seq2 committed last and applied"
        )
        await fulfillment(of: [repository.expectParked(index: 1, "seq2 on the wire")], timeout: 10)
        repository.resolveHeld(index: 1)
        await fulfillment(of: [newerResolved], timeout: 10)

        XCTAssertEqual(repository.completedMutations, [.add("2"), .remove("2")])
        // seq1 executed but was superseded mid-flight: its completion is
        // suppressed (seq2 owns the outcome), never applied out of order.
        XCTAssertEqual(
            resolutions.events.filter { $0.sequence == 1 },
            [ResolutionEvent(entityKey: entityKey, sequence: 1, resolution: .suppressed)]
        )
    }

    // MARK: - Favorite: add/remove/add, all six arrival permutations

    // Matrix 4, 7, 8: whatever order the three submission Tasks reach the
    // coordinator, executed requests are strictly sequence-increasing, each
    // accepted sequence issues exactly one request, and the server ends at
    // seq3 (add).
    func testAddRemoveAddConvergesToHighestSequenceAcrossAllSixArrivalPermutations() async {
        let permutations: [[UInt64]] = [
            [1, 2, 3], [1, 3, 2], [2, 1, 3], [2, 3, 1], [3, 1, 2], [3, 2, 1]
        ]

        for permutation in permutations {
            let repository = HoldableFavoriteRepository()
            let router = MockLibraryMutationRouter()
            router.enqueueResult = .storageBlocked
            router.holdEnqueues = true
            let resolutions = attachResolutionWatcher(to: router)
            let viewModel = makeHomeGameListViewModel(repository: repository, librarySync: router)
            let entityKey = LibrarySyncEntityKey.favorite(gameID: "3")

            // Gesture order add / remove / add (the toggle follows the
            // optimistic state), sequences 1 / 2 / 3.
            let parked = expectParkedEnqueues(router, count: 3)
            viewModel.send(.didTapFavorite(gameId: 3))
            viewModel.send(.didTapFavorite(gameId: 3))
            viewModel.send(.didTapFavorite(gameId: 3))
            XCTAssertEqual(router.capturedOwnerships.map(\.sequence), [1, 2, 3])
            await fulfillment(of: [parked], timeout: 10)

            // A sequence executes iff it exceeds every sequence that
            // arrived before it (running-max scan of the permutation).
            var runningMax: UInt64 = 0
            var expectedExecuted: [HoldableFavoriteRepository.Mutation] = []
            let mutationBySequence: [UInt64: HoldableFavoriteRepository.Mutation] = [
                1: .add("3"), 2: .remove("3"), 3: .add("3")
            ]
            for sequence in permutation {
                let expected: MockLibraryMutationRouter.FallbackResolution
                if sequence > runningMax {
                    runningMax = sequence
                    expectedExecuted.append(mutationBySequence[sequence]!)
                    expected = .success
                } else {
                    expected = .suppressed
                }
                let resolved = resolutions.expectation(
                    for: ResolutionEvent(entityKey: entityKey, sequence: sequence, resolution: expected),
                    "\(permutation): seq\(sequence) resolved as \(expected)"
                )
                router.resolveHeldEnqueue(entityKey: entityKey, sequence: sequence, with: .storageBlocked)
                await fulfillment(of: [resolved], timeout: 10)
            }

            XCTAssertEqual(
                repository.completedMutations, expectedExecuted,
                "\(permutation): executed requests must be exactly the running-max chain"
            )
            XCTAssertEqual(
                repository.completedMutations.last, .add("3"),
                "\(permutation): the server must end at the highest sequence (add)"
            )
        }
    }

    // MARK: - Library status: reversed arrival and three-way inversion

    // Matrix 9, 11 (storageBlocked): wishlist → playing with reversed Task
    // arrival, through the exact caller contract the LibraryViewModel uses
    // (engine enqueue → storageBlocked → runAuthenticatedDirectFallback →
    // real use case → repository).
    func testLibraryStatusReversedArrivalCommitsOnlyTheNewestStatus() async throws {
        let engine = await makeStorageBlockedEngine()
        let repository = HoldableLibraryRepository()
        let useCase = UpdateLibraryGameStatusUseCase(libraryRepository: repository)
        let log = AppliedSequenceLog()

        let wishlistRequest = makeStatusRequest(status: .wishlist)
        let playingRequest = makeStatusRequest(status: .playing)
        let older = try XCTUnwrap(engine.captureLibraryStatusIntent(wishlistRequest))
        let newer = try XCTUnwrap(engine.captureLibraryStatusIntent(playingRequest))
        XCTAssertEqual(older.sequence, 1)
        XCTAssertEqual(newer.sequence, 2)

        let olderEnqueue = await engine.enqueueLibraryStatusUpdate(wishlistRequest, ownership: older)
        let newerEnqueue = await engine.enqueueLibraryStatusUpdate(playingRequest, ownership: newer)
        XCTAssertEqual(olderEnqueue, .storageBlocked)
        XCTAssertEqual(newerEnqueue, .storageBlocked)

        // Reversed arrival: the newer fallback reaches the coordinator
        // first and completes; the older one then dies without networking.
        await runStatusFallback(engine, ownership: newer, request: playingRequest, useCase: useCase, log: log)
        await runStatusFallback(engine, ownership: older, request: wishlistRequest, useCase: useCase, log: log)

        XCTAssertEqual(repository.completedStatuses, [.playing])
        XCTAssertEqual(log.appliedSequences, [2])
        XCTAssertEqual(log.suppressedSequences, [1])
    }

    // Matrix 10, 11: playing → completed → dropped with inverted
    // scheduling; the server must end at dropped (seq3).
    func testLibraryStatusThreeWayInversionConvergesToHighestSequence() async throws {
        let engine = await makeStorageBlockedEngine()
        let repository = HoldableLibraryRepository()
        let useCase = UpdateLibraryGameStatusUseCase(libraryRepository: repository)
        let log = AppliedSequenceLog()

        let requests: [UserGameStatus: LibraryGameStatusUpdateRequest] = [
            .playing: makeStatusRequest(status: .playing),
            .completed: makeStatusRequest(status: .completed),
            .dropped: makeStatusRequest(status: .dropped)
        ]
        let playing = try XCTUnwrap(engine.captureLibraryStatusIntent(requests[.playing]!))
        let completed = try XCTUnwrap(engine.captureLibraryStatusIntent(requests[.completed]!))
        let dropped = try XCTUnwrap(engine.captureLibraryStatusIntent(requests[.dropped]!))
        for (ownership, request) in [(playing, requests[.playing]!), (completed, requests[.completed]!), (dropped, requests[.dropped]!)] {
            let result = await engine.enqueueLibraryStatusUpdate(request, ownership: ownership)
            XCTAssertEqual(result, .storageBlocked)
        }

        // Inverted arrival: seq2, then seq3, then the late seq1.
        await runStatusFallback(engine, ownership: completed, request: requests[.completed]!, useCase: useCase, log: log)
        await runStatusFallback(engine, ownership: dropped, request: requests[.dropped]!, useCase: useCase, log: log)
        await runStatusFallback(engine, ownership: playing, request: requests[.playing]!, useCase: useCase, log: log)

        XCTAssertEqual(repository.completedStatuses, [.completed, .dropped])
        XCTAssertEqual(repository.completedStatuses.last, .dropped, "the server must end at the highest sequence")
        XCTAssertEqual(log.appliedSequences, [2, 3])
        XCTAssertEqual(log.suppressedSequences, [1])
    }

    private func runStatusFallback(
        _ engine: LibrarySyncEngine,
        ownership: LibraryMutationOwnership,
        request: LibraryGameStatusUpdateRequest,
        useCase: UpdateLibraryGameStatusUseCase,
        log: AppliedSequenceLog
    ) async {
        await engine.runAuthenticatedDirectFallback(
            ownership: ownership,
            operation: { try await useCase.execute(request: request) },
            apply: { outcome in
                switch outcome {
                case .success:
                    log.recordApplied(ownership.sequence)
                case .failure:
                    log.recordApplied(ownership.sequence)
                case .suppressed:
                    log.recordSuppressed(ownership.sequence)
                }
            }
        )
    }

    // MARK: - Cross-ViewModel: one shared coordinator

    // Matrix 12, 14: HomeViewModel seq1 and GameDetailViewModel seq2 target
    // the same game through the same router; the shared coordinator lets
    // seq2 execute and rejects the late seq1 without networking.
    func testHomeAndGameDetailViewModelsShareOneCoordinatorForTheSameGame() async {
        let repository = HoldableFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .storageBlocked
        router.holdEnqueues = true
        let resolutions = attachResolutionWatcher(to: router)
        let homeViewModel = HomeViewModel(
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: repository),
            librarySync: router
        )
        let detailViewModel = GameDetailViewModel(
            fetchFavoriteStatusUseCase: FetchFavoriteStatusUseCase(favoriteRepository: repository),
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: repository),
            fetchAIReviewSummaryUseCase: DefaultFetchAIReviewSummaryUseCase(
                repository: MockAIReviewSummaryRepository()
            ),
            librarySync: router
        )
        detailViewModel.send(.viewDidLoad(gameId: 55))
        let entityKey = LibrarySyncEntityKey.favorite(gameID: "55")

        // Home gestures first (seq1), the detail screen second (seq2) —
        // one shared per-entity sequence stream across both ViewModels.
        let parked = expectParkedEnqueues(router, count: 2)
        homeViewModel.send(.didTapFavorite(gameId: 55))
        detailViewModel.send(.didTapHaveIt)
        XCTAssertEqual(router.capturedOwnerships.map(\.sequence), [1, 2])
        await fulfillment(of: [parked], timeout: 10)

        // The detail gesture's fallback arrives first and executes.
        let newerResolved = resolutions.expectation(
            for: ResolutionEvent(entityKey: entityKey, sequence: 2, resolution: .success),
            "GameDetail seq2 executed"
        )
        router.resolveHeldEnqueue(entityKey: entityKey, sequence: 2, with: .storageBlocked)
        await fulfillment(of: [newerResolved], timeout: 10)

        // Home's older fallback is adjudicated by the SAME coordinator and
        // suppressed without a request.
        let olderSuppressed = resolutions.expectation(
            for: ResolutionEvent(entityKey: entityKey, sequence: 1, resolution: .suppressed),
            "Home seq1 suppressed by the shared coordinator"
        )
        router.resolveHeldEnqueue(entityKey: entityKey, sequence: 1, with: .storageBlocked)
        await fulfillment(of: [olderSuppressed], timeout: 10)

        XCTAssertEqual(repository.completedMutations.count, 1, "exactly one request for the newest intent")
        XCTAssertEqual(
            resolutions.events.map(\.sequence).sorted(), [1, 2],
            "one shared coordinator adjudicated both ViewModels' submissions"
        )
    }

    // Matrix 13, 14: HomeGameListViewModel (add seq1) and LibraryViewModel
    // (remove seq2) target the same favorite entity; the shared coordinator
    // serializes them and the remove commits last.
    func testHomeGameListAndLibraryViewModelsSerializeOnTheSameFavoriteEntity() async {
        let repository = HoldableFavoriteRepository()
        repository.holdMutations = true
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .storageBlocked
        router.holdEnqueues = true
        let resolutions = attachResolutionWatcher(to: router)
        let milestones = await attachMilestoneWatcher(to: router.directFallbackCoordinator)
        let listViewModel = makeHomeGameListViewModel(repository: repository, librarySync: router)
        let libraryViewModel = LibraryViewModel(
            removeFavoriteUseCase: RemoveFavoriteUseCase(favoriteRepository: repository),
            librarySync: router
        )
        let recorder = NotificationRecorder(center: .default, names: [.favoriteDidChange])
        let entityKey = LibrarySyncEntityKey.favorite(gameID: "42")

        let parked = expectParkedEnqueues(router, count: 2)
        listViewModel.send(.didTapFavorite(gameId: 42))
        libraryViewModel.send(
            .didConfirmRemoveFavorite(
                LibraryGameIdentifier(source: .igdb, sourceID: "42", canonicalGameID: 42)
            )
        )
        XCTAssertEqual(router.capturedOwnerships.map(\.sequence), [1, 2])
        await fulfillment(of: [parked], timeout: 10)

        // seq1 (add, from the list screen) starts and parks on the wire.
        let olderStarted = milestones.expectation(
            for: .started(entityKey: entityKey, sequence: 1),
            "list seq1 started"
        )
        router.resolveHeldEnqueue(entityKey: entityKey, sequence: 1, with: .storageBlocked)
        await fulfillment(of: [olderStarted], timeout: 10)

        // seq2 (remove, from the library screen) must wait on the SAME
        // coordinator, not race a second request.
        let newerWaiting = milestones.expectation(
            for: .waiting(entityKey: entityKey, sequence: 2),
            "library seq2 parked behind list seq1"
        )
        router.resolveHeldEnqueue(entityKey: entityKey, sequence: 2, with: .storageBlocked)
        await fulfillment(of: [newerWaiting], timeout: 10)
        XCTAssertEqual(repository.startedMutations, [.add("42")])

        let newerResolved = resolutions.expectation(
            for: ResolutionEvent(entityKey: entityKey, sequence: 2, resolution: .success),
            "library seq2 committed last"
        )
        await fulfillment(of: [repository.expectParked(index: 0, "seq1 on the wire")], timeout: 10)
        repository.resolveHeld(index: 0)
        let newerStarted = milestones.expectation(
            for: .started(entityKey: entityKey, sequence: 2),
            "library seq2 started after seq1 completed"
        )
        await fulfillment(of: [newerStarted], timeout: 10)
        await fulfillment(of: [repository.expectParked(index: 1, "seq2 on the wire")], timeout: 10)
        repository.resolveHeld(index: 1)
        await fulfillment(of: [newerResolved], timeout: 10)

        XCTAssertEqual(repository.completedMutations, [.add("42"), .remove("42")])
        // The applied outcome is the remove (seq2); the superseded add was
        // suppressed, so no stale "added" notification may exist.
        let publishedStates = recorder.notifications.compactMap {
            $0.userInfo?[FavoriteChangeUserInfoKey.isFavorite] as? Bool
        }
        XCTAssertEqual(publishedStates, [false], "only the newest intent may publish its outcome")
    }

    // MARK: - Engine fallback path (real engine, real ownership context)

    // storageBlocked through the actual ViewModel → engine → coordinator →
    // repository path: rapid gestures serialize and the newest wins.
    func testStorageBlockedEngineFallbackSerializesRapidGestures() async {
        let engine = await makeStorageBlockedEngine()
        let repository = HoldableFavoriteRepository()
        repository.holdMutations = true
        let milestones = await attachMilestoneWatcher(to: engine.directFallbackCoordinator)
        let viewModel = makeHomeGameListViewModel(repository: repository, librarySync: engine)
        let recorder = NotificationRecorder(center: .default, names: [.favoriteDidChange])
        let entityKey = LibrarySyncEntityKey.favorite(gameID: "9")

        // First gesture: enqueue fails durably, the fallback starts and
        // parks on the wire.
        let olderStarted = milestones.expectation(
            for: .started(entityKey: entityKey, sequence: 1),
            "seq1 fallback started"
        )
        viewModel.send(.didTapFavorite(gameId: 9))
        await fulfillment(of: [olderStarted], timeout: 10)

        // Second gesture while seq1 is in flight: waits, never races.
        let newerWaiting = milestones.expectation(
            for: .waiting(entityKey: entityKey, sequence: 2),
            "seq2 parked behind seq1"
        )
        viewModel.send(.didTapFavorite(gameId: 9))
        await fulfillment(of: [newerWaiting], timeout: 10)
        XCTAssertEqual(repository.startedMutations, [.add("9")])

        let newerStarted = milestones.expectation(
            for: .started(entityKey: entityKey, sequence: 2),
            "seq2 started after seq1 completed"
        )
        await fulfillment(of: [repository.expectParked(index: 0, "seq1 on the wire")], timeout: 10)
        repository.resolveHeld(index: 0)
        await fulfillment(of: [newerStarted], timeout: 10)

        let newerFinished = milestones.expectation(
            for: .finished(entityKey: entityKey, sequence: 2),
            "seq2 finished"
        )
        await fulfillment(of: [repository.expectParked(index: 1, "seq2 on the wire")], timeout: 10)
        repository.resolveHeld(index: 1)
        await fulfillment(of: [newerFinished], timeout: 10)

        XCTAssertEqual(repository.completedMutations, [.add("9"), .remove("9")])
        // Only the newest outcome is applied to the UI.
        let publishedStates = recorder.notifications.compactMap {
            $0.userInfo?[FavoriteChangeUserInfoKey.isFavorite] as? Bool
        }
        XCTAssertEqual(publishedStates, [false])
    }

    // serviceUnavailable through the same real path: the ownership scope is
    // live but the engine has not adopted the account yet.
    func testServiceUnavailableEngineFallbackSerializesRapidGestures() async {
        let engine = makeSyncEngine(store: store, transport: transport, notificationCenter: center)
        // The gesture authority adopts the account synchronously (as the
        // runtime bridge does), but the engine's own async adoption has not
        // landed: enqueue reports `.serviceUnavailable`.
        engine.ownershipContext.adoptSession(isAuthenticated: true, userID: "user-1")
        let repository = HoldableFavoriteRepository()
        repository.holdMutations = true
        let milestones = await attachMilestoneWatcher(to: engine.directFallbackCoordinator)
        let viewModel = makeHomeGameListViewModel(repository: repository, librarySync: engine)
        let entityKey = LibrarySyncEntityKey.favorite(gameID: "11")

        let olderStarted = milestones.expectation(
            for: .started(entityKey: entityKey, sequence: 1),
            "seq1 fallback started"
        )
        viewModel.send(.didTapFavorite(gameId: 11))
        await fulfillment(of: [olderStarted], timeout: 10)

        let newerWaiting = milestones.expectation(
            for: .waiting(entityKey: entityKey, sequence: 2),
            "seq2 parked behind seq1"
        )
        viewModel.send(.didTapFavorite(gameId: 11))
        await fulfillment(of: [newerWaiting], timeout: 10)
        XCTAssertEqual(repository.startedMutations, [.add("11")])

        let newerFinished = milestones.expectation(
            for: .finished(entityKey: entityKey, sequence: 2),
            "seq2 finished last"
        )
        await fulfillment(of: [repository.expectParked(index: 0, "seq1 on the wire")], timeout: 10)
        repository.resolveHeld(index: 0)
        let newerStarted = milestones.expectation(
            for: .started(entityKey: entityKey, sequence: 2),
            "seq2 started after seq1"
        )
        await fulfillment(of: [newerStarted], timeout: 10)
        await fulfillment(of: [repository.expectParked(index: 1, "seq2 on the wire")], timeout: 10)
        repository.resolveHeld(index: 1)
        await fulfillment(of: [newerFinished], timeout: 10)

        XCTAssertEqual(repository.completedMutations, [.add("11"), .remove("11")])
    }

    // MARK: - Account lifecycle

    // Matrix 15: the scope ends after enqueue rejected the intent but
    // before the fallback constructs its request — nothing may be sent.
    func testLogoutBeforeRequestConstructionSuppressesTheFallback() async {
        let repository = HoldableFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .storageBlocked
        router.holdEnqueues = true
        let resolutions = attachResolutionWatcher(to: router)
        let viewModel = makeHomeGameListViewModel(repository: repository, librarySync: router)
        let entityKey = LibrarySyncEntityKey.favorite(gameID: "20")

        let parked = expectParkedEnqueues(router, count: 1)
        viewModel.send(.didTapFavorite(gameId: 20))
        await fulfillment(of: [parked], timeout: 10)

        // Logout lands while the submission is still parked in enqueue.
        router.ownershipIsCurrent = false

        let suppressed = resolutions.expectation(
            for: ResolutionEvent(entityKey: entityKey, sequence: 1, resolution: .suppressed),
            "fallback suppressed before request construction"
        )
        router.resolveHeldEnqueue(entityKey: entityKey, sequence: 1, with: .storageBlocked)
        await fulfillment(of: [suppressed], timeout: 10)

        XCTAssertTrue(repository.startedMutations.isEmpty, "a dead scope must never reach the network")
    }

    // Matrix 16, 19: account A → B while one fallback is on the wire and a
    // newer one is queued behind it. The in-flight request completes (not
    // retractable) but its completion is suppressed; the queued fallback
    // never starts; current UI stays untouched.
    func testAccountSwitchWhileFallbackQueuedSuppressesBothOldRequests() async {
        let engine = await makeStorageBlockedEngine(accountID: "user-a")
        let repository = HoldableFavoriteRepository()
        repository.holdMutations = true
        let milestones = await attachMilestoneWatcher(to: engine.directFallbackCoordinator)
        let viewModel = makeHomeGameListViewModel(repository: repository, librarySync: engine)
        let recorder = NotificationRecorder(center: .default, names: [.favoriteDidChange])
        let entityKey = LibrarySyncEntityKey.favorite(gameID: "30")

        let olderStarted = milestones.expectation(
            for: .started(entityKey: entityKey, sequence: 1),
            "seq1 on the wire"
        )
        viewModel.send(.didTapFavorite(gameId: 30))
        await fulfillment(of: [olderStarted], timeout: 10)

        let newerWaiting = milestones.expectation(
            for: .waiting(entityKey: entityKey, sequence: 2),
            "seq2 queued behind seq1"
        )
        viewModel.send(.didTapFavorite(gameId: 30))
        await fulfillment(of: [newerWaiting], timeout: 10)
        let stateBeforeSwitch = viewModel.state.wishlistedGameIDs

        // B replaces A while seq1 is in flight and seq2 is queued.
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-b")

        let olderSuppressed = milestones.expectation(
            for: .suppressed(entityKey: entityKey, sequence: 1),
            "seq1 completion suppressed"
        )
        let newerSuppressed = milestones.expectation(
            for: .suppressed(entityKey: entityKey, sequence: 2),
            "queued seq2 suppressed without networking"
        )
        await fulfillment(of: [repository.expectParked(index: 0, "seq1 on the wire")], timeout: 10)
        repository.resolveHeld(index: 0)
        await fulfillment(of: [olderSuppressed, newerSuppressed], timeout: 10)

        XCTAssertEqual(
            repository.startedMutations, [.add("30")],
            "the queued seq2 must never start under a dead scope"
        )
        XCTAssertEqual(recorder.count(of: .favoriteDidChange), 0, "a stale completion must not publish")
        XCTAssertEqual(
            viewModel.state.wishlistedGameIDs, stateBeforeSwitch,
            "a stale completion must not rewrite current UI"
        )
    }

    // Matrix 17: A → B → A mints a fresh scope; the old A entity state
    // (highest sequence 2) must not suppress the new scope's sequence 1.
    func testReloginAfterAccountSwitchDoesNotReviveTheOldScope() async {
        let engine = await makeStorageBlockedEngine(accountID: "user-a")
        let repository = HoldableFavoriteRepository()
        repository.holdMutations = true
        let milestones = await attachMilestoneWatcher(to: engine.directFallbackCoordinator)
        let viewModel = makeHomeGameListViewModel(repository: repository, librarySync: engine)
        let entityKey = LibrarySyncEntityKey.favorite(gameID: "40")

        // Old A scope: seq1 on the wire, seq2 queued.
        let olderStarted = milestones.expectation(
            for: .started(entityKey: entityKey, sequence: 1),
            "old-A seq1 on the wire"
        )
        viewModel.send(.didTapFavorite(gameId: 40))
        await fulfillment(of: [olderStarted], timeout: 10)
        let newerWaiting = milestones.expectation(
            for: .waiting(entityKey: entityKey, sequence: 2),
            "old-A seq2 queued"
        )
        viewModel.send(.didTapFavorite(gameId: 40))
        await fulfillment(of: [newerWaiting], timeout: 10)

        // A → B → A. The old A captures die permanently.
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-b")
        let oldSuppressed = milestones.expectation(
            for: .suppressed(entityKey: entityKey, sequence: 2),
            "old-A seq2 suppressed"
        )
        await fulfillment(of: [repository.expectParked(index: 0, "old-A seq1 on the wire")], timeout: 10)
        repository.resolveHeld(index: 0)
        await fulfillment(of: [oldSuppressed], timeout: 10)
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        // New A scope: sequences restart at 1 and must execute — the old
        // scope's higher sequence cannot revive to block them.
        repository.holdMutations = false
        let freshFinished = milestones.expectation(
            for: .finished(entityKey: entityKey, sequence: 1),
            "new-A seq1 executed"
        )
        viewModel.send(.didTapFavorite(gameId: 40))
        await fulfillment(of: [freshFinished], timeout: 10)

        XCTAssertEqual(repository.startedMutations.count, 2, "the fresh scope's gesture must reach the network")
    }

    // Matrix 18: a same-account credential refresh preserves the scope —
    // queued fallback ordering survives and both requests commit in order.
    func testSameAccountCredentialRefreshPreservesFallbackOrdering() async {
        let engine = await makeStorageBlockedEngine(accountID: "user-1")
        let repository = HoldableFavoriteRepository()
        repository.holdMutations = true
        let milestones = await attachMilestoneWatcher(to: engine.directFallbackCoordinator)
        let viewModel = makeHomeGameListViewModel(repository: repository, librarySync: engine)
        let entityKey = LibrarySyncEntityKey.favorite(gameID: "50")

        let olderStarted = milestones.expectation(
            for: .started(entityKey: entityKey, sequence: 1),
            "seq1 on the wire"
        )
        viewModel.send(.didTapFavorite(gameId: 50))
        await fulfillment(of: [olderStarted], timeout: 10)

        // Credential refresh for the SAME account mid-flight.
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-1")

        // A follow-up gesture continues the same scope's sequence stream
        // (2, not 1) and still serializes behind the in-flight request.
        let newerWaiting = milestones.expectation(
            for: .waiting(entityKey: entityKey, sequence: 2),
            "seq2 queued after the refresh"
        )
        viewModel.send(.didTapFavorite(gameId: 50))
        await fulfillment(of: [newerWaiting], timeout: 10)

        let newerStarted = milestones.expectation(
            for: .started(entityKey: entityKey, sequence: 2),
            "seq2 started after seq1"
        )
        await fulfillment(of: [repository.expectParked(index: 0, "seq1 on the wire")], timeout: 10)
        repository.resolveHeld(index: 0)
        await fulfillment(of: [newerStarted], timeout: 10)
        let newerFinished = milestones.expectation(
            for: .finished(entityKey: entityKey, sequence: 2),
            "seq2 finished"
        )
        await fulfillment(of: [repository.expectParked(index: 1, "seq2 on the wire")], timeout: 10)
        repository.resolveHeld(index: 1)
        await fulfillment(of: [newerFinished], timeout: 10)

        XCTAssertEqual(
            repository.completedMutations, [.add("50"), .remove("50")],
            "the refresh must not disturb gesture ordering or drop queued fallbacks"
        )
    }

    // Matrix 20: account deletion invalidates the in-flight completion and
    // the queued fallback.
    func testAccountDeletionInvalidatesQueuedFallback() async {
        let engine = await makeStorageBlockedEngine(accountID: "user-a")
        let repository = HoldableFavoriteRepository()
        repository.holdMutations = true
        let milestones = await attachMilestoneWatcher(to: engine.directFallbackCoordinator)
        let viewModel = makeHomeGameListViewModel(repository: repository, librarySync: engine)
        let recorder = NotificationRecorder(center: .default, names: [.favoriteDidChange])
        let entityKey = LibrarySyncEntityKey.favorite(gameID: "60")

        let olderStarted = milestones.expectation(
            for: .started(entityKey: entityKey, sequence: 1),
            "seq1 on the wire"
        )
        viewModel.send(.didTapFavorite(gameId: 60))
        await fulfillment(of: [olderStarted], timeout: 10)
        let newerWaiting = milestones.expectation(
            for: .waiting(entityKey: entityKey, sequence: 2),
            "seq2 queued"
        )
        viewModel.send(.didTapFavorite(gameId: 60))
        await fulfillment(of: [newerWaiting], timeout: 10)

        await engine.accountDidDelete(userID: "user-a")

        let olderSuppressed = milestones.expectation(
            for: .suppressed(entityKey: entityKey, sequence: 1),
            "seq1 completion suppressed after deletion"
        )
        let newerSuppressed = milestones.expectation(
            for: .suppressed(entityKey: entityKey, sequence: 2),
            "queued seq2 suppressed after deletion"
        )
        await fulfillment(of: [repository.expectParked(index: 0, "seq1 on the wire")], timeout: 10)
        repository.resolveHeld(index: 0)
        await fulfillment(of: [olderSuppressed, newerSuppressed], timeout: 10)

        XCTAssertEqual(repository.startedMutations, [.add("60")])
        XCTAssertEqual(recorder.count(of: .favoriteDidChange), 0)
    }

    // MARK: - Independence

    // Matrix 21: distinct entities never serialize against each other.
    func testDifferentEntitiesExecuteIndependently() async {
        let repository = HoldableFavoriteRepository()
        repository.holdMutations = true
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .storageBlocked
        let resolutions = attachResolutionWatcher(to: router)
        let milestones = await attachMilestoneWatcher(to: router.directFallbackCoordinator)
        let viewModel = makeHomeGameListViewModel(repository: repository, librarySync: router)

        // Entity 70's request parks on the wire…
        let firstStarted = milestones.expectation(
            for: .started(entityKey: LibrarySyncEntityKey.favorite(gameID: "70"), sequence: 1),
            "game 70 on the wire"
        )
        viewModel.send(.didTapFavorite(gameId: 70))
        await fulfillment(of: [firstStarted], timeout: 10)

        // …and entity 71 must start immediately, not queue behind it.
        let secondStarted = milestones.expectation(
            for: .started(entityKey: LibrarySyncEntityKey.favorite(gameID: "71"), sequence: 1),
            "game 71 started while game 70 is in flight"
        )
        viewModel.send(.didTapFavorite(gameId: 71))
        await fulfillment(of: [secondStarted], timeout: 10)
        XCTAssertEqual(repository.startedMutations, [.add("70"), .add("71")])

        let firstResolved = resolutions.expectation(
            for: ResolutionEvent(
                entityKey: LibrarySyncEntityKey.favorite(gameID: "70"),
                sequence: 1,
                resolution: .success
            ),
            "game 70 applied"
        )
        let secondResolved = resolutions.expectation(
            for: ResolutionEvent(
                entityKey: LibrarySyncEntityKey.favorite(gameID: "71"),
                sequence: 1,
                resolution: .success
            ),
            "game 71 applied"
        )
        await fulfillment(
            of: [
                repository.expectParked(index: 0, "game 70 on the wire"),
                repository.expectParked(index: 1, "game 71 on the wire")
            ],
            timeout: 10
        )
        repository.resolveHeld(index: 1)
        repository.resolveHeld(index: 0)
        await fulfillment(of: [firstResolved, secondResolved], timeout: 10)
        XCTAssertEqual(Set(repository.completedMutations), [.add("70"), .add("71")])
    }

    // Matrix 22: account B's fallback for the same entity is never blocked
    // by (or merged with) account A's dying in-flight request.
    func testDifferentAccountsNeverBlockOrOverwriteEachOther() async {
        let engine = await makeStorageBlockedEngine(accountID: "user-a")
        let repository = HoldableFavoriteRepository()
        repository.holdMutations = true
        let milestones = await attachMilestoneWatcher(to: engine.directFallbackCoordinator)
        let viewModel = makeHomeGameListViewModel(repository: repository, librarySync: engine)
        let recorder = NotificationRecorder(center: .default, names: [.favoriteDidChange])
        let entityKey = LibrarySyncEntityKey.favorite(gameID: "80")

        // A's request parks on the wire.
        let aStarted = milestones.expectation(
            for: .started(entityKey: entityKey, sequence: 1),
            "A seq1 on the wire"
        )
        viewModel.send(.didTapFavorite(gameId: 80))
        await fulfillment(of: [aStarted], timeout: 10)

        // B replaces A and gestures on the SAME entity. B's sequence 1 must
        // execute without waiting for A's held request.
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-b")
        let bOnWire = expectation(description: "B's request started while A's is still held")
        repository.onMutationStart = { index, _ in
            if index == 1 { bOnWire.fulfill() }
        }
        viewModel.send(.didTapFavorite(gameId: 80))
        await fulfillment(of: [bOnWire], timeout: 10)

        // B completes and applies; A's late completion is suppressed.
        let bFinished = milestones.expectation(
            for: .finished(entityKey: entityKey, sequence: 1),
            "B seq1 finished and applied"
        )
        repository.resolveHeld(index: 1)
        await fulfillment(of: [bFinished], timeout: 10)
        let aSuppressed = milestones.expectation(
            for: .suppressed(entityKey: entityKey, sequence: 1),
            "A's stale completion suppressed"
        )
        await fulfillment(of: [repository.expectParked(index: 0, "A seq1 on the wire")], timeout: 10)
        repository.resolveHeld(index: 0)
        await fulfillment(of: [aSuppressed], timeout: 10)

        XCTAssertEqual(repository.completedMutations.count, 2)
        // Only B's outcome was published; A could not overwrite it.
        let publishedStates = recorder.notifications.compactMap {
            $0.userInfo?[FavoriteChangeUserInfoKey.isFavorite] as? Bool
        }
        XCTAssertEqual(publishedStates.count, 1, "exactly one (B's) outcome may publish")
    }

    // MARK: - Deterministic inversion sweep

    // Matrix 23: 54 deterministic arrival permutations of three gestures
    // (nine full passes over all six orders), each on a fresh entity with a
    // real ownership context. Executed requests must always be the strictly
    // increasing running-max chain and the final commit must be seq3.
    func testFiftyFourDeterministicArrivalPermutationsConvergeToHighestSequence() async throws {
        let permutations: [[Int]] = [
            [0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]
        ]
        let context = LibraryMutationOwnershipContext()
        context.adoptSession(isAuthenticated: true, userID: "user-1")
        let coordinator = LibraryDirectMutationCoordinator(
            isScopeCurrent: { context.isScopeCurrent($0) }
        )

        for iteration in 0..<54 {
            let permutation = permutations[iteration % permutations.count]
            let entityKey = "favorite:inversion-\(iteration)"
            let ownerships: [LibraryMutationOwnership] = try (0..<3).map { index in
                try XCTUnwrap(
                    context.captureIntent(
                        entityKey: entityKey,
                        intendedState: .favorite(isFavorite: index.isMultiple(of: 2))
                    )
                )
            }

            let log = AppliedSequenceLog()
            let executed = ExecutedRequestLog()
            var runningMax: UInt64 = 0
            var expectedExecuted: [UInt64] = []
            for slot in permutation {
                let ownership = ownerships[slot]
                if ownership.sequence > runningMax {
                    runningMax = ownership.sequence
                    expectedExecuted.append(ownership.sequence)
                }
                await coordinator.run(
                    ownership: ownership,
                    operation: {
                        executed.record(ownership.sequence)
                        return ownership.sequence
                    },
                    apply: { outcome in
                        switch outcome {
                        case .success(let sequence):
                            log.recordApplied(sequence)
                        case .failure:
                            XCTFail("iteration \(iteration): unexpected failure")
                        case .suppressed:
                            log.recordSuppressed(ownership.sequence)
                        }
                    }
                )
            }

            XCTAssertEqual(
                executed.sequences, expectedExecuted,
                "iteration \(iteration) \(permutation): requests must be the running-max chain"
            )
            XCTAssertEqual(
                log.appliedSequences, expectedExecuted,
                "iteration \(iteration) \(permutation): applied outcomes must match executed requests"
            )
            XCTAssertEqual(
                executed.sequences.last, 3,
                "iteration \(iteration) \(permutation): the final commit must be the highest sequence"
            )
        }
    }

    /// Thread-safe record of which sequences actually opened a request.
    private final class ExecutedRequestLog: @unchecked Sendable {
        private let lock = NSLock()
        private var recorded: [UInt64] = []

        func record(_ sequence: UInt64) {
            lock.lock()
            recorded.append(sequence)
            lock.unlock()
        }

        var sequences: [UInt64] {
            lock.lock()
            defer { lock.unlock() }
            return recorded
        }
    }

    // MARK: - Failure semantics under coordination

    // A failed (thrown) request that still owns its entity applies as a
    // failure; a failed request that was superseded mid-flight is
    // suppressed and the newest intent still commits.
    func testFailureOutcomesRespectSequenceAuthority() async {
        let repository = HoldableFavoriteRepository()
        repository.holdMutations = true
        repository.errorBehavior = { index in index == 0 ? ScriptedRepositoryError() : nil }
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .storageBlocked
        router.holdEnqueues = true
        let resolutions = attachResolutionWatcher(to: router)
        let milestones = await attachMilestoneWatcher(to: router.directFallbackCoordinator)
        let viewModel = makeHomeGameListViewModel(repository: repository, librarySync: router)
        let entityKey = LibrarySyncEntityKey.favorite(gameID: "90")

        let parked = expectParkedEnqueues(router, count: 2)
        viewModel.send(.didTapFavorite(gameId: 90))
        viewModel.send(.didTapFavorite(gameId: 90))
        await fulfillment(of: [parked], timeout: 10)

        let olderStarted = milestones.expectation(
            for: .started(entityKey: entityKey, sequence: 1),
            "seq1 started"
        )
        router.resolveHeldEnqueue(entityKey: entityKey, sequence: 1, with: .storageBlocked)
        await fulfillment(of: [olderStarted], timeout: 10)

        let newerWaiting = milestones.expectation(
            for: .waiting(entityKey: entityKey, sequence: 2),
            "seq2 waiting"
        )
        router.resolveHeldEnqueue(entityKey: entityKey, sequence: 2, with: .storageBlocked)
        await fulfillment(of: [newerWaiting], timeout: 10)

        // seq1 throws while superseded: suppressed, not surfaced — the
        // newest intent owns the outcome and still commits.
        let olderSuppressed = resolutions.expectation(
            for: ResolutionEvent(entityKey: entityKey, sequence: 1, resolution: .suppressed),
            "superseded failure suppressed"
        )
        let newerResolved = resolutions.expectation(
            for: ResolutionEvent(entityKey: entityKey, sequence: 2, resolution: .success),
            "seq2 committed after the failed seq1"
        )
        await fulfillment(of: [repository.expectParked(index: 0, "seq1 on the wire")], timeout: 10)
        repository.resolveHeld(index: 0)
        let newerStarted = milestones.expectation(
            for: .started(entityKey: entityKey, sequence: 2),
            "seq2 started after seq1 failed"
        )
        await fulfillment(of: [olderSuppressed, newerStarted], timeout: 10)
        await fulfillment(of: [repository.expectParked(index: 1, "seq2 on the wire")], timeout: 10)
        repository.resolveHeld(index: 1)
        await fulfillment(of: [newerResolved], timeout: 10)

        XCTAssertEqual(repository.completedMutations, [.add("90"), .remove("90")])
    }
}
