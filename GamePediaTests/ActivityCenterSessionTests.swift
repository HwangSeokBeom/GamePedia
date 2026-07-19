import XCTest
@testable import GamePedia

// H4 + H5 — Activity Center session ownership, freshness, and badge.
//
// Every load binds to the LiveServiceSession that started it; superseded
// work can neither render, persist, post badge changes, nor invoke
// mark-read. The global badge is written only from a fresh authoritative
// inbox response or a confirmed remote mark-read; friend activity, cached
// fallbacks, and failed remote marks never touch it.
final class ActivityCenterSessionTests: XCTestCase {

    private struct StubError: Error {}

    /// Thread-safe mutable session used as the VM's session provider.
    private final class SessionBox: @unchecked Sendable {
        private let lock = NSLock()
        private var session: LiveServiceSession

        init(accountID: String?) {
            session = LiveServiceSession(accountID: accountID, generation: 1)
        }

        var current: LiveServiceSession {
            lock.lock()
            defer { lock.unlock() }
            return session
        }

        func transition(to accountID: String?) {
            lock.lock()
            session = LiveServiceSession(accountID: accountID, generation: session.generation &+ 1)
            lock.unlock()
        }
    }

    private final class NotificationRepositoryFake: NotificationRepository, @unchecked Sendable {
        private let lock = NSLock()
        private var gatedFetchContinuations: [CheckedContinuation<Void, Never>] = []
        private var fetchGateRemaining = 0
        private var gatedMarkContinuations: [CheckedContinuation<Void, Never>] = []
        private var markGateRemaining = 0
        private(set) var fetchCallCount = 0
        private(set) var markAllCallCount = 0
        var pageResult: Result<AppNotificationPage, Error> = .success(
            AppNotificationPage(notifications: [], unreadCount: 0)
        )
        var markAllResult: Result<Void, Error> = .success(())
        var onFetchStarted: ((Int) -> Void)?
        var onMarkStarted: ((Int) -> Void)?

        func gateNextFetches(_ count: Int) {
            lock.lock()
            fetchGateRemaining = count
            lock.unlock()
        }

        func releaseFetchGate() {
            lock.lock()
            let continuations = gatedFetchContinuations
            gatedFetchContinuations.removeAll()
            lock.unlock()
            continuations.forEach { $0.resume() }
        }

        func gateNextMarks(_ count: Int) {
            lock.lock()
            markGateRemaining = count
            lock.unlock()
        }

        func releaseMarkGate() {
            lock.lock()
            let continuations = gatedMarkContinuations
            gatedMarkContinuations.removeAll()
            lock.unlock()
            continuations.forEach { $0.resume() }
        }

        func fetchNotifications(page: Int, limit: Int) async throws -> AppNotificationPage {
            lock.lock()
            fetchCallCount += 1
            let current = fetchCallCount
            let shouldGate = fetchGateRemaining > 0
            if shouldGate { fetchGateRemaining -= 1 }
            let callback = onFetchStarted
            lock.unlock()
            callback?(current)
            if shouldGate {
                await withCheckedContinuation { continuation in
                    lock.lock()
                    gatedFetchContinuations.append(continuation)
                    lock.unlock()
                }
            }
            return try pageResult.get()
        }

        func markAllNotificationsRead() async throws {
            lock.lock()
            markAllCallCount += 1
            let current = markAllCallCount
            let shouldGate = markGateRemaining > 0
            if shouldGate { markGateRemaining -= 1 }
            let callback = onMarkStarted
            lock.unlock()
            callback?(current)
            if shouldGate {
                await withCheckedContinuation { continuation in
                    lock.lock()
                    gatedMarkContinuations.append(continuation)
                    lock.unlock()
                }
            }
            try markAllResult.get()
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
    private var snapshotStore: FileActivityCenterSnapshotStore!
    private var readStateStore: ActivityReadStateStore!

    override func setUp() {
        super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("activity-center-session-tests-\(UUID().uuidString)", isDirectory: true)
        notificationRepository = NotificationRepositoryFake()
        friendRepository = FriendRepositoryFake()
        snapshotStore = FileActivityCenterSnapshotStore(directoryURL: directoryURL)
        readStateStore = ActivityReadStateStore(directoryURL: directoryURL)
    }

    override func tearDown() {
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        super.tearDown()
    }

    private func makeViewModel(session: SessionBox) -> ActivityCenterViewModel {
        ActivityCenterViewModel(
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
            sessionProvider: { session.current }
        )
    }

    private func makeNotification(id: String, isRead: Bool) -> AppNotification {
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

    private func makeFriendActivity(id: String) -> FriendActivityItem {
        FriendActivityItem(
            id: id,
            actor: FriendUserSummary(
                id: "u1",
                nickname: "friend",
                bio: nil,
                profileImageURL: nil,
                relationshipStatus: .friends,
                recentPlayTitle: nil,
                presence: nil
            ),
            type: .reviewCreated,
            game: Game(
                id: 7,
                title: "Game",
                translatedTitle: nil,
                summary: nil,
                translatedSummary: nil,
                genre: "RPG",
                category: "RPG",
                developer: "",
                platform: "",
                releaseDate: nil,
                releaseYear: 0,
                coverImageURL: nil,
                rating: 0,
                reviewCount: 0,
                popularity: 0,
                isTrending: false,
                formattedRating: "—",
                formattedReviewCount: "0"
            ),
            createdAt: Date(timeIntervalSince1970: 8_000),
            messageOverride: nil,
            metadata: nil
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

    /// Mirrors production: the session scope changes AND the auth-session
    /// notification the view model observes fires.
    private func transitionSession(_ box: SessionBox, to accountID: String?) {
        box.transition(to: accountID)
        var userInfo: [String: Any] = [
            AuthSessionChangeUserInfoKey.isAuthenticated: accountID != nil
        ]
        if let accountID {
            userInfo[AuthSessionChangeUserInfoKey.userId] = accountID
        }
        NotificationCenter.default.post(name: .authSessionDidChange, object: nil, userInfo: userInfo)
    }

    // MARK: - H4: session ownership

    @MainActor
    func test_staleLoadAfterLogout_cannotRenderPersistBadgeOrMarkRead() async {
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1", isRead: false)],
            unreadCount: 3
        ))
        notificationRepository.gateNextFetches(1)
        let session = SessionBox(accountID: "acct-1")
        let viewModel = makeViewModel(session: session)
        let badgeRecorder = NotificationRecorder(center: .default, names: [.appNotificationsDidChange])

        let fetchStarted = expectation(description: "fetch started")
        notificationRepository.onFetchStarted = { count in
            if count == 1 { fetchStarted.fulfill() }
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [fetchStarted], timeout: 10)

        // Logout while the load is in flight, then let it complete.
        transitionSession(session, to: nil)
        notificationRepository.releaseFetchGate()

        // Deterministic settle: a fresh session's own load completes (the
        // session-change reload path).
        notificationRepository.pageResult = .success(AppNotificationPage(notifications: [], unreadCount: 0))
        let settled = waitForStateSettled(viewModel) { state in
            state.isLoading == false && state.items.isEmpty
        }
        transitionSession(session, to: "acct-2")
        await fulfillment(of: [settled], timeout: 10)

        XCTAssertFalse(
            viewModel.state.items.contains { $0.identity == "id:n1" },
            "the stale session's items must never render"
        )
        XCTAssertEqual(notificationRepository.markAllCallCount, 0, "stale work must not invoke mark-read")
        let unreadPosts = badgeRecorder.notifications.compactMap {
            $0.userInfo?[AppNotificationChangeUserInfoKey.unreadCount] as? Int
        }
        XCTAssertFalse(unreadPosts.contains(3), "the stale load's unread count must never reach the badge")
        let persisted = await snapshotStore.loadSnapshot(accountID: "acct-1")
        XCTAssertNil(persisted, "stale work must not persist a snapshot")
    }

    @MainActor
    func test_accountALoadCompletingAfterBLogin_isDiscarded() async {
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "a-item", isRead: true)],
            unreadCount: 0
        ))
        notificationRepository.gateNextFetches(1)
        let session = SessionBox(accountID: "acct-a")
        let viewModel = makeViewModel(session: session)

        let fetchStarted = expectation(description: "fetch started")
        notificationRepository.onFetchStarted = { count in
            if count == 1 { fetchStarted.fulfill() }
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [fetchStarted], timeout: 10)

        // B logs in; A's response arrives afterwards.
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "b-item", isRead: true)],
            unreadCount: 0
        ))
        let settled = waitForStateSettled(viewModel) { state in
            state.isLoading == false && state.items.contains { $0.identity == "id:b-item" }
        }
        transitionSession(session, to: "acct-b")
        notificationRepository.releaseFetchGate()
        await fulfillment(of: [settled], timeout: 10)

        XCTAssertFalse(
            viewModel.state.items.contains { $0.identity == "id:a-item" },
            "account A's late response must not render into B's session"
        )
        let persistedForA = await snapshotStore.loadSnapshot(accountID: "acct-a")
        XCTAssertNil(persistedForA, "account A's snapshot file must not receive session-B-era data")
    }

    @MainActor
    func test_staleSession_cannotDriveMarkRead_midFlight() async {
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1", isRead: false)],
            unreadCount: 2
        ))
        notificationRepository.gateNextMarks(1)
        let session = SessionBox(accountID: "acct-1")
        let viewModel = makeViewModel(session: session)
        let badgeRecorder = NotificationRecorder(center: .default, names: [.appNotificationsDidChange])

        let markStarted = expectation(description: "mark started")
        notificationRepository.onMarkStarted = { count in
            if count == 1 { markStarted.fulfill() }
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [markStarted], timeout: 10)

        // The session ends while mark-all-read is in flight; even a remote
        // success may not publish zero for a superseded session.
        transitionSession(session, to: nil)
        notificationRepository.releaseMarkGate()

        // Deterministic settle: the next session's reload runs with a
        // failed inbox (no badge writes) and settles the state machine.
        notificationRepository.pageResult = .failure(StubError())
        let settled = waitForStateSettled(viewModel) { state in state.isLoading == false }
        transitionSession(session, to: "acct-2")
        await fulfillment(of: [settled], timeout: 10)

        let unreadPosts = badgeRecorder.notifications.compactMap {
            $0.userInfo?[AppNotificationChangeUserInfoKey.unreadCount] as? Int
        }
        XCTAssertFalse(
            unreadPosts.contains(0),
            "a mark-read completion from a superseded session must never publish zero"
        )
    }

    @MainActor
    func test_deinit_doesNotCrashOrPostAfterRelease() async {
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1", isRead: false)],
            unreadCount: 5
        ))
        notificationRepository.gateNextFetches(1)
        let session = SessionBox(accountID: "acct-1")
        var viewModel: ActivityCenterViewModel? = makeViewModel(session: session)
        let badgeRecorder = NotificationRecorder(center: .default, names: [.appNotificationsDidChange])

        let fetchStarted = expectation(description: "fetch started")
        notificationRepository.onFetchStarted = { count in
            if count == 1 { fetchStarted.fulfill() }
        }
        viewModel?.send(.viewDidLoad)
        await fulfillment(of: [fetchStarted], timeout: 10)

        viewModel = nil
        notificationRepository.releaseFetchGate()

        // Deterministic settle: an unrelated fetch on a fresh view model.
        notificationRepository.pageResult = .success(AppNotificationPage(notifications: [], unreadCount: 0))
        let second = makeViewModel(session: session)
        let settled = waitForStateSettled(second) { state in state.isLoading == false }
        second.send(.viewDidLoad)
        await fulfillment(of: [settled], timeout: 10)

        let unreadPosts = badgeRecorder.notifications.compactMap {
            $0.userInfo?[AppNotificationChangeUserInfoKey.unreadCount] as? Int
        }
        XCTAssertFalse(unreadPosts.contains(5), "a released view model must not publish its stale load")
    }

    // MARK: - H5: freshness and badge

    @MainActor
    func test_inboxFails_feedSucceeds_noBadgeWrite_degradedNoticeShown() async {
        notificationRepository.pageResult = .failure(StubError())
        friendRepository.feedResult = .success(FriendActivityFeedPage(
            activities: [makeFriendActivity(id: "f1")],
            nextCursor: nil
        ))
        let session = SessionBox(accountID: "acct-1")
        let viewModel = makeViewModel(session: session)
        let badgeRecorder = NotificationRecorder(center: .default, names: [.appNotificationsDidChange])

        let settled = waitForStateSettled(viewModel) { state in
            state.isLoading == false && state.items.isEmpty == false
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [settled], timeout: 10)

        XCTAssertEqual(
            badgeRecorder.count(of: .appNotificationsDidChange), 0,
            "friend activity alone must never write the notification badge"
        )
        XCTAssertNotNil(viewModel.state.degradedNoticeText, "degraded content needs an honest notice")
        XCTAssertEqual(
            notificationRepository.markAllCallCount, 0,
            "unread-looking friend items must not trigger remote mark-read"
        )
    }

    @MainActor
    func test_bothRemoteSourcesFail_cachedSnapshotNeverTouchesBadge() async {
        // Seed a persisted snapshot via one fresh successful load.
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1", isRead: true)],
            unreadCount: 0
        ))
        let session = SessionBox(accountID: "acct-1")
        let viewModel = makeViewModel(session: session)
        let firstLoad = waitForStateSettled(viewModel) { state in
            state.isLoading == false && state.items.count == 1
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [firstLoad], timeout: 10)

        notificationRepository.pageResult = .failure(StubError())
        friendRepository.feedResult = .failure(StubError())
        let badgeRecorder = NotificationRecorder(center: .default, names: [.appNotificationsDidChange])
        let degraded = waitForStateSettled(viewModel) { state in
            state.isLoading == false && state.isShowingLastKnown
        }
        viewModel.send(.didTapRetry)
        await fulfillment(of: [degraded], timeout: 10)

        XCTAssertEqual(
            badgeRecorder.count(of: .appNotificationsDidChange), 0,
            "a cached fallback must never erase or rewrite the known server unread count"
        )
    }

    @MainActor
    func test_failedRemoteMarkAllRead_neverPublishesZero() async {
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1", isRead: false)],
            unreadCount: 4
        ))
        notificationRepository.markAllResult = .failure(StubError())
        let session = SessionBox(accountID: "acct-1")
        let viewModel = makeViewModel(session: session)
        let badgeRecorder = NotificationRecorder(center: .default, names: [.appNotificationsDidChange])

        let markAttempted = expectation(description: "remote mark attempted")
        notificationRepository.onMarkStarted = { count in
            if count == 1 { markAttempted.fulfill() }
        }
        let settled = waitForStateSettled(viewModel) { state in
            state.isLoading == false && state.items.count == 1
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [settled, markAttempted], timeout: 10)

        // Deterministic settle for the post-mark phase: run a second load
        // whose mark also fails, then inspect every badge write.
        let second = waitForStateSettled(viewModel) { state in state.isLoading == false }
        viewModel.send(.didTapRetry)
        await fulfillment(of: [second], timeout: 10)

        let unreadPosts = badgeRecorder.notifications.compactMap {
            $0.userInfo?[AppNotificationChangeUserInfoKey.unreadCount] as? Int
        }
        XCTAssertTrue(unreadPosts.allSatisfy { $0 == 4 }, "posts: \(unreadPosts)")
        XCTAssertFalse(unreadPosts.contains(0), "a failed remote mark must never publish zero")
    }

    @MainActor
    func test_confirmedRemoteMark_publishesAuthoritativeSequence() async {
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1", isRead: false)],
            unreadCount: 4
        ))
        let session = SessionBox(accountID: "acct-1")
        let viewModel = makeViewModel(session: session)
        let badgeRecorder = NotificationRecorder(center: .default, names: [.appNotificationsDidChange])

        let zeroPublished = XCTNSNotificationExpectation(
            name: .appNotificationsDidChange,
            object: nil,
            notificationCenter: .default
        )
        zeroPublished.handler = { notification in
            (notification.userInfo?[AppNotificationChangeUserInfoKey.unreadCount] as? Int) == 0
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [zeroPublished], timeout: 10)

        let unreadPosts = badgeRecorder.notifications.compactMap {
            $0.userInfo?[AppNotificationChangeUserInfoKey.unreadCount] as? Int
        }
        XCTAssertEqual(
            unreadPosts, [4, 0],
            "the badge sequence must be: fresh authoritative count, then confirmed zero"
        )
        XCTAssertEqual(notificationRepository.markAllCallCount, 1)
    }

    @MainActor
    func test_serverUnreadBeyondFirstPage_stillMarksRemotely() async {
        // All visible page-1 items are read, but the server reports unread
        // items beyond the page. The old merged-count logic would have
        // skipped the remote mark AND published a false zero.
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1", isRead: true)],
            unreadCount: 7
        ))
        let session = SessionBox(accountID: "acct-1")
        let viewModel = makeViewModel(session: session)
        let badgeRecorder = NotificationRecorder(center: .default, names: [.appNotificationsDidChange])

        let zeroPublished = XCTNSNotificationExpectation(
            name: .appNotificationsDidChange,
            object: nil,
            notificationCenter: .default
        )
        zeroPublished.handler = { notification in
            (notification.userInfo?[AppNotificationChangeUserInfoKey.unreadCount] as? Int) == 0
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [zeroPublished], timeout: 10)

        XCTAssertEqual(notificationRepository.markAllCallCount, 1)
        let unreadPosts = badgeRecorder.notifications.compactMap {
            $0.userInfo?[AppNotificationChangeUserInfoKey.unreadCount] as? Int
        }
        XCTAssertEqual(unreadPosts, [7, 0])
    }
}
