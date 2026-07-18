import XCTest
@testable import GamePedia

// Guards two things at once:
// 1. The existing REST Friend Activity Feed behavior is unchanged when
//    realtime is absent (the production state — flag off, no backend contract).
// 2. When a realtime invalidation source IS injected (tests/mocks only), its
//    signals only ever trigger REST reconciliation — payloads are never
//    rendered and REST stays authoritative.
final class FriendActivityFeedRealtimeTests: XCTestCase {

    // MARK: - Test doubles

    private final class ActivityFeedRepositoryStub: FriendRepository {
        private let lock = NSLock()
        private var fetchCallCount = 0
        private var recordedCursors: [String?] = []
        private var gatedContinuations: [CheckedContinuation<Void, Never>] = []
        private var gateRemaining = 0

        var onFetchStarted: ((Int) -> Void)?

        var fetchCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return fetchCallCount
        }

        var cursors: [String?] {
            lock.lock()
            defer { lock.unlock() }
            return recordedCursors
        }

        /// The next `count` fetches will park until releaseGate() is called.
        func gateNextFetches(_ count: Int) {
            lock.lock()
            gateRemaining = count
            lock.unlock()
        }

        func releaseGate() {
            lock.lock()
            let continuations = gatedContinuations
            gatedContinuations.removeAll()
            lock.unlock()
            continuations.forEach { $0.resume() }
        }

        func fetchFriendActivityFeed(cursor: String?) async throws -> FriendActivityFeedPage {
            lock.lock()
            fetchCallCount += 1
            recordedCursors.append(cursor)
            let currentCount = fetchCallCount
            let shouldGate = gateRemaining > 0
            if shouldGate { gateRemaining -= 1 }
            let callback = onFetchStarted
            lock.unlock()

            callback?(currentCount)
            if shouldGate {
                await withCheckedContinuation { continuation in
                    lock.lock()
                    gatedContinuations.append(continuation)
                    lock.unlock()
                }
            }
            return FriendActivityFeedPage(activities: [], nextCursor: nil)
        }

        // Unused protocol requirements.
        func searchFriends(keyword: String) async throws -> [FriendUserSummary] { fatalError() }
        func fetchReceivedFriendRequests() async throws -> [FriendRequest] { fatalError() }
        func fetchSentFriendRequests() async throws -> [FriendRequest] { fatalError() }
        func sendFriendRequest(userID: String) async throws { fatalError() }
        func acceptFriendRequest(requestID: String) async throws { fatalError() }
        func rejectFriendRequest(requestID: String) async throws { fatalError() }
        func cancelFriendRequest(requestID: String) async throws { fatalError() }
        func fetchFriends() async throws -> [FriendUserSummary] { fatalError() }
        func fetchSteamFriends() async throws -> (friends: [SteamFriend], isAvailable: Bool, isLimitedByPrivacy: Bool, syncWarningCode: String?) { fatalError() }
        func fetchFriendProfile(userID: String) async throws -> FriendProfile { fatalError() }
        func fetchFriendRecommendations(userID: String) async throws -> [FriendRecommendation] { fatalError() }
        func removeFriend(userID: String) async throws { fatalError() }
        func blockUser(userID: String) async throws { fatalError() }
        func fetchSocialPrivacySettings() async throws -> SocialPrivacySettings { fatalError() }
        func updateSocialPrivacySettings(_ settings: SocialPrivacySettings) async throws -> SocialPrivacySettings { fatalError() }
        func importSteamFriends() async throws { fatalError() }
    }

    private final class ControlledInvalidationSource: ActivityFeedInvalidationSignaling {
        private let lock = NSLock()
        private var continuation: AsyncStream<Void>.Continuation?
        private var bufferedSignalCount = 0

        func signals() -> AsyncStream<Void> {
            AsyncStream { continuation in
                lock.lock()
                self.continuation = continuation
                let buffered = bufferedSignalCount
                bufferedSignalCount = 0
                lock.unlock()
                for _ in 0..<buffered { continuation.yield(()) }
            }
        }

        func send() {
            lock.lock()
            if let continuation {
                lock.unlock()
                continuation.yield(())
            } else {
                bufferedSignalCount += 1
                lock.unlock()
            }
        }
    }

    private func makeViewModel(
        repository: ActivityFeedRepositoryStub,
        invalidationSource: ActivityFeedInvalidationSignaling?
    ) -> FriendActivityFeedViewModel {
        FriendActivityFeedViewModel(
            fetchFriendActivityFeedUseCase: FetchFriendActivityFeedUseCase(repository: repository),
            widgetSnapshotStore: SocialWidgetSnapshotStore(userDefaults: nil),
            metricRecorder: PerformanceMetricRecorder(
                tracer: NoopSignpostTracer(),
                logsSamples: false
            ),
            realtimeInvalidationSource: invalidationSource
        )
    }

    private func waitForFetch(
        _ count: Int,
        on repository: ActivityFeedRepositoryStub
    ) -> XCTestExpectation {
        let fetchExpectation = expectation(description: "fetch #\(count) started")
        repository.onFetchStarted = { current in
            if current == count { fetchExpectation.fulfill() }
        }
        return fetchExpectation
    }

    // MARK: - Existing behavior unchanged (realtime absent — production state)

    func testViewDidLoadLoadsExactlyOnceWithoutRealtime() async {
        let repository = ActivityFeedRepositoryStub()
        let viewModel = makeViewModel(repository: repository, invalidationSource: nil)

        let firstFetch = waitForFetch(1, on: repository)
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [firstFetch], timeout: 10)

        // Second viewDidLoad keeps the existing single-load guard.
        viewModel.send(.viewDidLoad)
        XCTAssertEqual(repository.fetchCount, 1)
        XCTAssertEqual(repository.cursors, [nil])
    }

    func testPullToRefreshBehaviorUnchangedWithoutRealtime() async {
        let repository = ActivityFeedRepositoryStub()
        let viewModel = makeViewModel(repository: repository, invalidationSource: nil)

        let firstFetch = waitForFetch(1, on: repository)
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [firstFetch], timeout: 10)

        let secondFetch = waitForFetch(2, on: repository)
        viewModel.send(.didPullToRefresh)
        await fulfillment(of: [secondFetch], timeout: 10)

        XCTAssertEqual(repository.cursors, [nil, nil])
    }

    func testDefaultInvalidationSourceIsNilWhileRealtimeDisabled() {
        XCTAssertFalse(RealtimeRuntime.shared.isRealtimeEnabled)
        XCTAssertNil(
            FriendActivityFeedViewModel.makeDefaultInvalidationSource(),
            "With the flag off (production state), the feed must not attach any realtime source"
        )
    }

    // MARK: - Realtime signals trigger REST reconciliation only

    func testInvalidationSignalTriggersRestReconciliation() async {
        let repository = ActivityFeedRepositoryStub()
        let source = ControlledInvalidationSource()
        let viewModel = makeViewModel(repository: repository, invalidationSource: source)

        let firstFetch = waitForFetch(1, on: repository)
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [firstFetch], timeout: 10)
        // Deterministically wait until the first load fully completed
        // (hasLoadedOnce set) before signalling.
        await waitUntilNotLoading(viewModel)

        let reconciliationFetch = waitForFetch(2, on: repository)
        source.send()
        await fulfillment(of: [reconciliationFetch], timeout: 10)

        XCTAssertEqual(
            repository.cursors, [nil, nil],
            "Reconciliation is a reset REST load — pagination is untouched and no payload is rendered"
        )
    }

    func testSignalBeforeFirstLoadCompletedIsIgnored() async {
        let repository = ActivityFeedRepositoryStub()
        repository.gateNextFetches(1)
        let source = ControlledInvalidationSource()
        let viewModel = makeViewModel(repository: repository, invalidationSource: source)

        let firstFetch = waitForFetch(1, on: repository)
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [firstFetch], timeout: 10)

        // Feed has never completed a load: the signal must be dropped, not
        // queued. Wait for the handler to fully evaluate the signal before
        // releasing the gate so the assertion is deterministic.
        let signalHandled = expectation(description: "signal evaluated")
        viewModel.onRealtimeInvalidationHandled = { signalHandled.fulfill() }
        source.send()
        await fulfillment(of: [signalHandled], timeout: 10)
        viewModel.onRealtimeInvalidationHandled = nil

        repository.releaseGate()
        await waitUntilNotLoading(viewModel)

        XCTAssertEqual(repository.fetchCount, 1)
    }

    func testSignalsDuringInFlightLoadCoalesceIntoOneReconciliation() async {
        let repository = ActivityFeedRepositoryStub()
        let source = ControlledInvalidationSource()
        let viewModel = makeViewModel(repository: repository, invalidationSource: source)

        let firstFetch = waitForFetch(1, on: repository)
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [firstFetch], timeout: 10)
        await waitUntilNotLoading(viewModel)

        // Second load parks; three signals arrive while it is in flight.
        repository.gateNextFetches(1)
        let secondFetch = waitForFetch(2, on: repository)
        source.send()
        await fulfillment(of: [secondFetch], timeout: 10)

        // Both extra signals must be fully evaluated (coalesced) before the
        // gate opens, or the assertion would race the handler.
        let extraSignalsHandled = expectation(description: "extra signals evaluated")
        extraSignalsHandled.expectedFulfillmentCount = 2
        viewModel.onRealtimeInvalidationHandled = { extraSignalsHandled.fulfill() }
        source.send()
        source.send()
        await fulfillment(of: [extraSignalsHandled], timeout: 10)
        viewModel.onRealtimeInvalidationHandled = nil

        let thirdFetch = waitForFetch(3, on: repository)
        repository.releaseGate()
        await fulfillment(of: [thirdFetch], timeout: 10)
        await waitUntilNotLoading(viewModel)

        XCTAssertEqual(repository.fetchCount, 3, "Coalesced: in-flight + exactly one follow-up")
    }

    // MARK: - Helpers

    private func waitUntilNotLoading(_ viewModel: FriendActivityFeedViewModel) async {
        // The view model mutates state inside MainActor.run, so checking and
        // installing the observer on the main queue is race-free.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                let state = viewModel.state
                if !state.isLoading && !state.isRefreshing && !state.isLoadingMore {
                    continuation.resume()
                    return
                }
                viewModel.onStateChanged = { state in
                    if !state.isLoading && !state.isRefreshing && !state.isLoadingMore {
                        viewModel.onStateChanged = nil
                        continuation.resume()
                    }
                }
            }
        }
    }
}
