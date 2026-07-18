import XCTest
@testable import GamePedia

// Deterministic coverage of the 2.3 notifications load coalescing:
// rapid retries share one in-flight request, a mid-load reload request
// is drained exactly once afterwards, and failures render the error
// state without a retry loop.
final class NotificationsViewModelTests: XCTestCase {

    // MARK: - Test double

    private final class NotificationRepositoryStub: NotificationRepository {
        private let lock = NSLock()
        private var fetchCallCount = 0
        private var gatedContinuations: [CheckedContinuation<Void, Never>] = []
        private var gateRemaining = 0
        var result: Result<AppNotificationPage, Error> = .success(
            AppNotificationPage(notifications: [], unreadCount: 0)
        )

        var onFetchStarted: ((Int) -> Void)?

        var fetchCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return fetchCallCount
        }

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

        func fetchNotifications(page: Int, limit: Int) async throws -> AppNotificationPage {
            lock.lock()
            fetchCallCount += 1
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
            return try result.get()
        }

        func markAllNotificationsRead() async throws {}
    }

    private func makeViewModel(
        repository: NotificationRepositoryStub
    ) -> NotificationsViewModel {
        NotificationsViewModel(
            fetchNotificationsUseCase: FetchNotificationsUseCase(
                notificationRepository: repository
            ),
            markAllNotificationsReadUseCase: MarkAllNotificationsReadUseCase(
                notificationRepository: repository
            )
        )
    }

    private func waitForFetch(
        _ count: Int,
        on repository: NotificationRepositoryStub
    ) -> XCTestExpectation {
        let fetchExpectation = expectation(description: "fetch #\(count) started")
        repository.onFetchStarted = { current in
            if current == count { fetchExpectation.fulfill() }
        }
        return fetchExpectation
    }

    private func waitForStateSettled(
        _ viewModel: NotificationsViewModel,
        until predicate: @escaping (NotificationsState) -> Bool
    ) -> XCTestExpectation {
        let settled = expectation(description: "state settled")
        settled.assertForOverFulfill = false
        viewModel.onStateChanged = { state in
            if predicate(state) { settled.fulfill() }
        }
        return settled
    }

    // MARK: - Tests

    @MainActor
    func test_rapidRetries_coalesceToOneRequest_thenDrainOnce() async {
        let repository = NotificationRepositoryStub()
        repository.gateNextFetches(1)
        let viewModel = makeViewModel(repository: repository)

        let firstFetch = waitForFetch(1, on: repository)
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [firstFetch], timeout: 2)

        // Three retry taps while the first request is parked.
        viewModel.send(.didTapRetry)
        viewModel.send(.didTapRetry)
        viewModel.send(.didTapRetry)
        XCTAssertEqual(repository.fetchCount, 1, "retries during an in-flight load must not issue new requests")

        // Completing the flight drains exactly one pending reload. Both
        // observers are installed before the release so the settle event
        // cannot fire before we start waiting for it.
        let secondFetch = waitForFetch(2, on: repository)
        let settled = waitForStateSettled(viewModel) { [weak repository] state in
            state.isLoading == false && repository?.fetchCount == 2
        }
        repository.releaseGate()
        await fulfillment(of: [secondFetch, settled], timeout: 2)
        XCTAssertEqual(repository.fetchCount, 2, "coalesced retries must drain into exactly one follow-up request")
    }

    @MainActor
    func test_success_rendersNotifications() async {
        let repository = NotificationRepositoryStub()
        repository.result = .success(
            AppNotificationPage(
                notifications: [
                    AppNotification(
                        id: "n1",
                        type: "generic",
                        title: "t",
                        message: "m",
                        relatedGameID: nil,
                        relatedUserID: nil,
                        relatedReviewID: nil,
                        relatedCommentID: nil,
                        isRead: true,
                        createdAt: Date(timeIntervalSince1970: 1)
                    )
                ],
                unreadCount: 0
            )
        )
        let viewModel = makeViewModel(repository: repository)

        let settled = waitForStateSettled(viewModel) { state in
            state.isLoading == false && state.notifications.count == 1
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [settled], timeout: 2)

        XCTAssertEqual(viewModel.state.notifications.first?.id, "n1")
        XCTAssertNil(viewModel.state.errorMessage)
    }

    @MainActor
    func test_failure_rendersErrorState_withoutRetryLoop() async {
        struct TestFailure: Error {}
        let repository = NotificationRepositoryStub()
        repository.result = .failure(TestFailure())
        let viewModel = makeViewModel(repository: repository)

        let settled = waitForStateSettled(viewModel) { state in
            state.isLoading == false && state.errorMessage != nil
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [settled], timeout: 2)

        XCTAssertTrue(viewModel.state.notifications.isEmpty)
        XCTAssertEqual(repository.fetchCount, 1, "failure must not self-retry")

        // Explicit retry issues a fresh request.
        repository.result = .success(AppNotificationPage(notifications: [], unreadCount: 0))
        let recovered = waitForStateSettled(viewModel) { state in
            state.isLoading == false && state.errorMessage == nil
        }
        viewModel.send(.didTapRetry)
        await fulfillment(of: [recovered], timeout: 2)
        XCTAssertEqual(repository.fetchCount, 2)
    }
}
