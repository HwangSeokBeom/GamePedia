import XCTest
@testable import GamePedia

// Activity Center screen behavior: load coalescing, degraded-source
// notices, offline last-known fallback, user-driven retry, and the
// mark-read side effect — all against deterministic fakes.
final class ActivityCenterViewModelTests: XCTestCase {

    // MARK: - Test doubles

    private struct StubError: Error {}

    private final class NotificationRepositoryFake: NotificationRepository, @unchecked Sendable {
        private let lock = NSLock()
        private var fetchCallCount = 0
        private var gatedContinuations: [CheckedContinuation<Void, Never>] = []
        private var gateRemaining = 0
        var pageResult: Result<AppNotificationPage, Error> = .success(
            AppNotificationPage(notifications: [], unreadCount: 0)
        )
        var onFetchStarted: ((Int) -> Void)?
        var onMarkAllRead: (() -> Void)?
        private(set) var markAllCallCount = 0

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
            return try pageResult.get()
        }

        func markAllNotificationsRead() async throws {
            lock.lock()
            markAllCallCount += 1
            let callback = onMarkAllRead
            lock.unlock()
            callback?()
        }
    }

    private final class FriendRepositoryFake: FriendRepository, @unchecked Sendable {
        var feedResult: Result<FriendActivityFeedPage, Error> = .success(
            FriendActivityFeedPage(activities: [], nextCursor: nil)
        )

        func fetchFriendActivityFeed(cursor: String?) async throws -> FriendActivityFeedPage {
            try feedResult.get()
        }

        func searchFriends(keyword: String) async throws -> [FriendUserSummary] { throw StubError() }
        func fetchReceivedFriendRequests() async throws -> [FriendRequest] { throw StubError() }
        func fetchSentFriendRequests() async throws -> [FriendRequest] { throw StubError() }
        func sendFriendRequest(userID: String) async throws { throw StubError() }
        func acceptFriendRequest(requestID: String) async throws { throw StubError() }
        func rejectFriendRequest(requestID: String) async throws { throw StubError() }
        func cancelFriendRequest(requestID: String) async throws { throw StubError() }
        func fetchFriends() async throws -> [FriendUserSummary] { throw StubError() }
        func fetchSteamFriends() async throws -> (friends: [SteamFriend], isAvailable: Bool, isLimitedByPrivacy: Bool, syncWarningCode: String?) { throw StubError() }
        func fetchFriendProfile(userID: String) async throws -> FriendProfile { throw StubError() }
        func fetchFriendRecommendations(userID: String) async throws -> [FriendRecommendation] { throw StubError() }
        func removeFriend(userID: String) async throws { throw StubError() }
        func blockUser(userID: String) async throws { throw StubError() }
        func fetchSocialPrivacySettings() async throws -> SocialPrivacySettings { throw StubError() }
        func updateSocialPrivacySettings(_ settings: SocialPrivacySettings) async throws -> SocialPrivacySettings { throw StubError() }
        func importSteamFriends() async throws { throw StubError() }
    }

    // MARK: - Fixtures

    private var directoryURL: URL!
    private var notificationRepository: NotificationRepositoryFake!
    private var friendRepository: FriendRepositoryFake!

    override func setUp() {
        super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("activity-center-vm-tests-\(UUID().uuidString)", isDirectory: true)
        notificationRepository = NotificationRepositoryFake()
        friendRepository = FriendRepositoryFake()
    }

    override func tearDown() {
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        super.tearDown()
    }

    private func makeViewModel(accountID: String? = "acct-1") -> ActivityCenterViewModel {
        let readStateStore = ActivityReadStateStore(directoryURL: directoryURL)
        let snapshotStore = FileActivityCenterSnapshotStore(directoryURL: directoryURL)
        return ActivityCenterViewModel(
            fetchActivityCenterUseCase: FetchActivityCenterUseCase(
                notificationRepository: notificationRepository,
                friendRepository: friendRepository,
                readStateStore: readStateStore,
                snapshotStore: snapshotStore,
                breadcrumbs: OperationBreadcrumbRecorder()
            ),
            markActivityCenterReadUseCase: MarkActivityCenterReadUseCase(
                notificationRepository: notificationRepository,
                readStateStore: readStateStore,
                breadcrumbs: OperationBreadcrumbRecorder()
            ),
            accountIDProvider: { accountID }
        )
    }

    private func makeNotification(id: String, isRead: Bool = true) -> AppNotification {
        AppNotification(
            id: id,
            type: "friend_review_created",
            title: "t",
            message: "m",
            relatedGameID: 7,
            relatedUserID: "u1",
            relatedReviewID: "r1",
            relatedCommentID: nil,
            isRead: isRead,
            createdAt: Date(timeIntervalSince1970: 9_000)
        )
    }

    private func waitForStateSettled(
        _ viewModel: ActivityCenterViewModel,
        until predicate: @escaping (ActivityCenterState) -> Bool
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
    func test_success_rendersMergedTimeline() async {
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1")],
            unreadCount: 0
        ))
        let viewModel = makeViewModel()

        let settled = waitForStateSettled(viewModel) { state in
            state.isLoading == false && state.items.count == 1
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [settled], timeout: 2)

        XCTAssertEqual(viewModel.state.items.first?.identity, "id:n1")
        XCTAssertNil(viewModel.state.errorMessage)
        XCTAssertNil(viewModel.state.degradedNoticeText)
        XCTAssertFalse(viewModel.state.isShowingLastKnown)
    }

    @MainActor
    func test_rapidRetries_coalesceToOneRequest_thenDrainOnce() async {
        notificationRepository.gateNextFetches(1)
        let viewModel = makeViewModel()

        let firstFetch = expectation(description: "first fetch started")
        notificationRepository.onFetchStarted = { count in
            if count == 1 { firstFetch.fulfill() }
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [firstFetch], timeout: 2)

        viewModel.send(.didTapRetry)
        viewModel.send(.didTapRetry)
        viewModel.send(.didTapRetry)
        XCTAssertEqual(
            notificationRepository.fetchCount, 1,
            "retries during an in-flight load must not issue new requests"
        )

        let secondFetch = expectation(description: "second fetch started")
        notificationRepository.onFetchStarted = { count in
            if count == 2 { secondFetch.fulfill() }
        }
        let settled = waitForStateSettled(viewModel) { [weak notificationRepository] state in
            state.isLoading == false && notificationRepository?.fetchCount == 2
        }
        notificationRepository.releaseGate()
        await fulfillment(of: [secondFetch, settled], timeout: 2)
        XCTAssertEqual(notificationRepository.fetchCount, 2)
    }

    @MainActor
    func test_partialSourceFailure_showsDegradedNotice_keepsListUsable() async {
        struct FeedDown: Error {}
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1")],
            unreadCount: 0
        ))
        friendRepository.feedResult = .failure(FeedDown())
        let viewModel = makeViewModel()

        let settled = waitForStateSettled(viewModel) { state in
            state.isLoading == false && state.items.isEmpty == false
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [settled], timeout: 2)

        XCTAssertEqual(viewModel.state.sourceHealth.friendActivity, .failed)
        XCTAssertNotNil(viewModel.state.degradedNoticeText)
        XCTAssertNil(viewModel.state.errorMessage, "partial failure must not hide the usable list")
    }

    @MainActor
    func test_totalFailure_withoutCache_rendersErrorState() async {
        notificationRepository.pageResult = .failure(StubError())
        friendRepository.feedResult = .failure(StubError())
        let viewModel = makeViewModel()

        let settled = waitForStateSettled(viewModel) { state in
            state.isLoading == false && state.errorMessage != nil
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [settled], timeout: 2)

        XCTAssertTrue(viewModel.state.items.isEmpty)
        XCTAssertEqual(notificationRepository.fetchCount, 1, "failure must not self-retry")
    }

    @MainActor
    func test_totalFailure_withCache_showsLastKnownState() async {
        // First load succeeds and persists the last-known snapshot.
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1")],
            unreadCount: 0
        ))
        let viewModel = makeViewModel()
        let firstLoad = waitForStateSettled(viewModel) { state in
            state.isLoading == false && state.items.count == 1
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [firstLoad], timeout: 2)

        // Everything goes dark; retry must degrade to the cached view.
        notificationRepository.pageResult = .failure(StubError())
        friendRepository.feedResult = .failure(StubError())
        let degraded = waitForStateSettled(viewModel) { state in
            state.isLoading == false && state.isShowingLastKnown
        }
        viewModel.send(.didTapRetry)
        await fulfillment(of: [degraded], timeout: 2)

        XCTAssertEqual(viewModel.state.items.count, 1)
        XCTAssertNotNil(viewModel.state.degradedNoticeText)
        XCTAssertNil(viewModel.state.errorMessage)
        XCTAssertNotNil(viewModel.state.lastKnownGeneratedAt)
    }

    @MainActor
    func test_freshLoadWithUnread_triggersMarkReadOnce() async {
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1", isRead: false)],
            unreadCount: 1
        ))
        let viewModel = makeViewModel()

        let marked = expectation(description: "mark all read requested")
        notificationRepository.onMarkAllRead = { marked.fulfill() }
        let settled = waitForStateSettled(viewModel) { state in
            state.isLoading == false && state.items.count == 1
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [settled, marked], timeout: 2)

        XCTAssertEqual(notificationRepository.markAllCallCount, 1)
    }

    @MainActor
    func test_readItems_doNotTriggerMarkRead() async {
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1", isRead: true)],
            unreadCount: 0
        ))
        let viewModel = makeViewModel()

        let settled = waitForStateSettled(viewModel) { state in
            state.isLoading == false && state.items.count == 1
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [settled], timeout: 2)

        XCTAssertEqual(notificationRepository.markAllCallCount, 0)
    }
}
