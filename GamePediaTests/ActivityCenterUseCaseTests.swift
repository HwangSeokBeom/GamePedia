import XCTest
@testable import GamePedia

// The 2.4 merge pipeline: REST-only source of truth, cross-source
// dedup, degraded-source health, last-known fallback, and local read
// watermark on top of the mark-all-read server contract.
final class ActivityCenterUseCaseTests: XCTestCase {

    // MARK: - Test doubles

    private struct StubError: Error {}

    private final class NotificationRepositoryFake: NotificationRepository, @unchecked Sendable {
        private let lock = NSLock()
        var pageResult: Result<AppNotificationPage, Error> = .success(
            AppNotificationPage(notifications: [], unreadCount: 0)
        )
        var markAllResult: Result<Void, Error> = .success(())
        private(set) var markAllCallCount = 0

        func fetchNotifications(page: Int, limit: Int) async throws -> AppNotificationPage {
            try pageResult.get()
        }

        func markAllNotificationsRead() async throws {
            lock.lock()
            markAllCallCount += 1
            lock.unlock()
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

        // Unused surface.
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
    private var readStateStore: ActivityReadStateStore!
    private var snapshotStore: FileActivityCenterSnapshotStore!

    override func setUp() {
        super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("activity-center-tests-\(UUID().uuidString)", isDirectory: true)
        notificationRepository = NotificationRepositoryFake()
        friendRepository = FriendRepositoryFake()
        readStateStore = ActivityReadStateStore(directoryURL: directoryURL)
        snapshotStore = FileActivityCenterSnapshotStore(directoryURL: directoryURL)
    }

    override func tearDown() {
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        super.tearDown()
    }

    private func makeUseCase() -> FetchActivityCenterUseCase {
        FetchActivityCenterUseCase(
            notificationRepository: notificationRepository,
            friendRepository: friendRepository,
            readStateStore: readStateStore,
            snapshotStore: snapshotStore,
            breadcrumbs: OperationBreadcrumbRecorder(),
            dateProvider: { Date(timeIntervalSince1970: 10_000) }
        )
    }

    private func makeNotification(
        id: String,
        type: String = "friend_review_created",
        userID: String? = "u1",
        gameID: Int? = 7,
        reviewID: String? = "r1",
        isRead: Bool = false,
        createdAt: Date
    ) -> AppNotification {
        AppNotification(
            id: id,
            type: type,
            title: "title-\(id)",
            message: "message-\(id)",
            relatedGameID: gameID,
            relatedUserID: userID,
            relatedReviewID: reviewID,
            relatedCommentID: nil,
            isRead: isRead,
            createdAt: createdAt
        )
    }

    private func makeGame(id: Int = 7) -> Game {
        Game(
            id: id,
            title: "Game \(id)",
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
        )
    }

    private func makeFriendActivity(
        id: String,
        type: FriendActivityItem.ActivityType = .reviewCreated,
        actorID: String = "u1",
        gameID: Int = 7,
        reviewID: String? = "r1",
        createdAt: Date?
    ) -> FriendActivityItem {
        FriendActivityItem(
            id: id,
            actor: FriendUserSummary(
                id: actorID,
                nickname: "friend-\(actorID)",
                bio: nil,
                profileImageURL: nil,
                relationshipStatus: .friends,
                recentPlayTitle: nil,
                presence: nil
            ),
            type: type,
            game: makeGame(id: gameID),
            createdAt: createdAt,
            messageOverride: nil,
            metadata: FriendActivityMetadata(
                reviewID: reviewID,
                previousRating: nil,
                updatedRating: nil,
                previousPlayStatus: nil,
                updatedPlayStatus: nil,
                note: nil
            )
        )
    }

    // MARK: - Merge

    func test_merge_collapsesCrossSourceTwins_preferringInbox() async throws {
        let occurredAt = Date(timeIntervalSince1970: 9_000)
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1", createdAt: occurredAt)],
            unreadCount: 1
        ))
        friendRepository.feedResult = .success(FriendActivityFeedPage(
            activities: [makeFriendActivity(id: "f1", createdAt: occurredAt.addingTimeInterval(30))],
            nextCursor: nil
        ))

        let outcome = try await makeUseCase().execute(accountID: "acct-1")

        XCTAssertEqual(outcome.snapshot.items.count, 1, "one logical activity must appear once")
        XCTAssertEqual(outcome.snapshot.items[0].source, .notificationInbox)
        XCTAssertEqual(outcome.snapshot.items[0].identity, "id:n1")
    }

    func test_merge_keepsDistinctEventsOutsideCollapseWindow() async throws {
        let first = Date(timeIntervalSince1970: 9_000)
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1", createdAt: first)],
            unreadCount: 1
        ))
        friendRepository.feedResult = .success(FriendActivityFeedPage(
            activities: [
                makeFriendActivity(
                    id: "f1",
                    createdAt: first.addingTimeInterval(FetchActivityCenterUseCase.crossSourceCollapseWindow + 1)
                )
            ],
            nextCursor: nil
        ))

        let outcome = try await makeUseCase().execute(accountID: "acct-1")
        XCTAssertEqual(outcome.snapshot.items.count, 2, "repeated same-facet events must stay distinct")
    }

    func test_merge_dropsExactDuplicates_andSortsNewestFirst() async throws {
        let older = Date(timeIntervalSince1970: 8_000)
        let newer = Date(timeIntervalSince1970: 9_000)
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [
                makeNotification(id: "n1", type: "generic", userID: nil, gameID: 1, reviewID: nil, createdAt: older),
                makeNotification(id: "n1", type: "generic", userID: nil, gameID: 1, reviewID: nil, createdAt: older),
                makeNotification(id: "n2", type: "friend_request_received", userID: "u9", gameID: nil, reviewID: nil, createdAt: newer)
            ],
            unreadCount: 3
        ))

        let outcome = try await makeUseCase().execute(accountID: "acct-1")

        XCTAssertEqual(outcome.snapshot.items.map(\.identity), ["id:n2", "id:n1"])
    }

    func test_merge_isDeterministic_forEqualTimestamps() {
        let occurredAt = Date(timeIntervalSince1970: 9_000)
        let a = ActivityCenterItem(
            notification: makeNotification(id: "a", type: "generic", userID: nil, gameID: 1, reviewID: nil, createdAt: occurredAt)
        )
        let b = ActivityCenterItem(
            notification: makeNotification(id: "b", type: "friend_request_received", userID: "u2", gameID: nil, reviewID: nil, createdAt: occurredAt)
        )
        let firstOrder = FetchActivityCenterUseCase.merge(inboxItems: [a, b], friendItems: [])
        let secondOrder = FetchActivityCenterUseCase.merge(inboxItems: [b, a], friendItems: [])
        XCTAssertEqual(firstOrder.map(\.identity), secondOrder.map(\.identity))
    }

    // MARK: - Degraded sources

    func test_inboxFailure_returnsPartialSnapshot_withFailedHealth() async throws {
        notificationRepository.pageResult = .failure(StubError())
        friendRepository.feedResult = .success(FriendActivityFeedPage(
            activities: [makeFriendActivity(id: "f1", createdAt: Date(timeIntervalSince1970: 9_000))],
            nextCursor: nil
        ))

        let outcome = try await makeUseCase().execute(accountID: "acct-1")

        XCTAssertEqual(outcome.snapshot.sourceHealth.notificationInbox, .failed)
        XCTAssertEqual(outcome.snapshot.sourceHealth.friendActivity, .fresh)
        XCTAssertFalse(outcome.isFromCache)
        XCTAssertEqual(outcome.snapshot.items.count, 1)
    }

    func test_friendFeedFailure_returnsPartialSnapshot() async throws {
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1", createdAt: Date(timeIntervalSince1970: 9_000))],
            unreadCount: 1
        ))
        friendRepository.feedResult = .failure(StubError())

        let outcome = try await makeUseCase().execute(accountID: "acct-1")

        XCTAssertEqual(outcome.snapshot.sourceHealth.friendActivity, .failed)
        XCTAssertEqual(outcome.snapshot.items.count, 1)
    }

    // MARK: - Last-known fallback

    func test_totalFailure_fallsBackToPersistedSnapshot() async throws {
        // Seed the last-known snapshot with a successful load.
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1", createdAt: Date(timeIntervalSince1970: 9_000))],
            unreadCount: 1
        ))
        _ = try await makeUseCase().execute(accountID: "acct-1")

        notificationRepository.pageResult = .failure(StubError())
        friendRepository.feedResult = .failure(StubError())

        let outcome = try await makeUseCase().execute(accountID: "acct-1")

        XCTAssertTrue(outcome.isFromCache)
        XCTAssertTrue(outcome.snapshot.sourceHealth.isFullyFailed)
        XCTAssertEqual(outcome.snapshot.items.map(\.identity), ["id:n1"])
    }

    func test_totalFailure_withoutCache_throws() async {
        notificationRepository.pageResult = .failure(StubError())
        friendRepository.feedResult = .failure(StubError())

        do {
            _ = try await makeUseCase().execute(accountID: "acct-1")
            XCTFail("expected allSourcesUnavailable")
        } catch let error as ActivityCenterError {
            XCTAssertEqual(error, .allSourcesUnavailable)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func test_guestSession_neverTouchesPersistence() async throws {
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1", createdAt: Date(timeIntervalSince1970: 9_000))],
            unreadCount: 1
        ))
        _ = try await makeUseCase().execute(accountID: nil)

        notificationRepository.pageResult = .failure(StubError())
        friendRepository.feedResult = .failure(StubError())
        do {
            _ = try await makeUseCase().execute(accountID: nil)
            XCTFail("guest total failure must throw: no account-scoped cache may exist")
        } catch let error as ActivityCenterError {
            XCTAssertEqual(error, .allSourcesUnavailable)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func test_accountSwitch_cannotSeePreviousAccountsSnapshot() async throws {
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1", createdAt: Date(timeIntervalSince1970: 9_000))],
            unreadCount: 1
        ))
        _ = try await makeUseCase().execute(accountID: "acct-1")

        notificationRepository.pageResult = .failure(StubError())
        friendRepository.feedResult = .failure(StubError())

        do {
            _ = try await makeUseCase().execute(accountID: "acct-2")
            XCTFail("the previous account's last-known state must be invisible")
        } catch let error as ActivityCenterError {
            XCTAssertEqual(error, .allSourcesUnavailable)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    // MARK: - Read state

    func test_readWatermark_overlaysUnreadItems_afterRestartShapedReload() async throws {
        let occurredAt = Date(timeIntervalSince1970: 9_000)
        notificationRepository.pageResult = .success(AppNotificationPage(
            notifications: [makeNotification(id: "n1", isRead: false, createdAt: occurredAt)],
            unreadCount: 1
        ))

        let first = try await makeUseCase().execute(accountID: "acct-1")
        XCTAssertEqual(first.snapshot.unreadCount, 1)

        _ = await MarkActivityCenterReadUseCase(
            notificationRepository: notificationRepository,
            readStateStore: readStateStore,
            breadcrumbs: OperationBreadcrumbRecorder()
        ).execute(
            accountID: "acct-1",
            snapshot: first.snapshot,
            serverInboxUnreadCount: first.serverInboxUnreadCount
        )

        // Server still reports the item unread (no per-item contract);
        // a fresh store instance simulates process restart.
        let restartedStore = ActivityReadStateStore(directoryURL: directoryURL)
        let second = try await FetchActivityCenterUseCase(
            notificationRepository: notificationRepository,
            friendRepository: friendRepository,
            readStateStore: restartedStore,
            snapshotStore: snapshotStore,
            breadcrumbs: OperationBreadcrumbRecorder(),
            dateProvider: { Date(timeIntervalSince1970: 10_000) }
        ).execute(accountID: "acct-1")

        XCTAssertEqual(second.snapshot.unreadCount, 0, "read state must survive restart")
        XCTAssertTrue(second.snapshot.items.allSatisfy(\.isRead))
    }

    func test_watermark_neverUnreads_serverReadItems() async throws {
        let items = [
            ActivityCenterItem(notification: makeNotification(
                id: "n1", isRead: true, createdAt: Date(timeIntervalSince1970: 9_500)
            ))
        ]
        let overlaid = FetchActivityCenterUseCase.applying(
            readState: ActivityReadState(readWatermark: Date(timeIntervalSince1970: 9_000)),
            to: items
        )
        XCTAssertTrue(overlaid[0].isRead)
    }

    func test_watermark_leavesNewerItemsUnread() {
        let items = [
            ActivityCenterItem(notification: makeNotification(
                id: "n-new", isRead: false, createdAt: Date(timeIntervalSince1970: 9_500)
            ))
        ]
        let overlaid = FetchActivityCenterUseCase.applying(
            readState: ActivityReadState(readWatermark: Date(timeIntervalSince1970: 9_000)),
            to: items
        )
        XCTAssertFalse(overlaid[0].isRead, "activity newer than the watermark must stay unread")
    }

    // MARK: - Mark read

    func test_markRead_callsServer_onlyWhenInboxHasUnread() async throws {
        let snapshotWithFriendUnread = ActivityCenterSnapshot(
            items: [ActivityCenterItem(friendActivity: makeFriendActivity(
                id: "f1", createdAt: Date(timeIntervalSince1970: 9_000)
            ))],
            sourceHealth: .allFresh,
            generatedAt: Date(timeIntervalSince1970: 10_000)
        )
        let useCase = MarkActivityCenterReadUseCase(
            notificationRepository: notificationRepository,
            readStateStore: readStateStore,
            breadcrumbs: OperationBreadcrumbRecorder()
        )

        let result = await useCase.execute(
            accountID: "acct-1",
            snapshot: snapshotWithFriendUnread,
            serverInboxUnreadCount: 0
        )
        XCTAssertEqual(
            notificationRepository.markAllCallCount, 0,
            "mark-all-read must not fire when the server reports nothing unread"
        )
        XCTAssertEqual(result, .localOnly)

        let state = await readStateStore.readState(accountID: "acct-1")
        XCTAssertEqual(state.readWatermark, Date(timeIntervalSince1970: 9_000))
    }

    func test_markRead_remoteFailure_stillAdvancesLocalWatermark() async {
        notificationRepository.markAllResult = .failure(StubError())
        let snapshot = ActivityCenterSnapshot(
            items: [ActivityCenterItem(notification: makeNotification(
                id: "n1", isRead: false, createdAt: Date(timeIntervalSince1970: 9_000)
            ))],
            sourceHealth: .allFresh,
            generatedAt: Date(timeIntervalSince1970: 10_000)
        )

        let result = await MarkActivityCenterReadUseCase(
            notificationRepository: notificationRepository,
            readStateStore: readStateStore,
            breadcrumbs: OperationBreadcrumbRecorder()
        ).execute(accountID: "acct-1", snapshot: snapshot, serverInboxUnreadCount: 1)

        XCTAssertEqual(notificationRepository.markAllCallCount, 1)
        XCTAssertEqual(
            result, .remoteFailed,
            "a failed remote mark must be reported so the badge never publishes zero from it"
        )
        let state = await readStateStore.readState(accountID: "acct-1")
        XCTAssertEqual(state.readWatermark, Date(timeIntervalSince1970: 9_000))
    }

    func test_markRead_isNoOp_whenNothingUnread() async {
        let snapshot = ActivityCenterSnapshot(
            items: [ActivityCenterItem(notification: makeNotification(
                id: "n1", isRead: true, createdAt: Date(timeIntervalSince1970: 9_000)
            ))],
            sourceHealth: .allFresh,
            generatedAt: Date(timeIntervalSince1970: 10_000)
        )

        let result = await MarkActivityCenterReadUseCase(
            notificationRepository: notificationRepository,
            readStateStore: readStateStore,
            breadcrumbs: OperationBreadcrumbRecorder()
        ).execute(accountID: "acct-1", snapshot: snapshot, serverInboxUnreadCount: 0)

        XCTAssertEqual(notificationRepository.markAllCallCount, 0)
        XCTAssertEqual(result, .localOnly)
        let state = await readStateStore.readState(accountID: "acct-1")
        XCTAssertNil(state.readWatermark)
    }

    // MARK: - Persisted snapshot round trip

    func test_persistedSnapshot_roundTripsRoutes() {
        let notification = makeNotification(id: "n1", createdAt: Date(timeIntervalSince1970: 9_000))
        let friendActivity = makeFriendActivity(id: "f9", type: .likedGameAdded, gameID: 42, reviewID: nil, createdAt: Date(timeIntervalSince1970: 8_000))
        let snapshot = ActivityCenterSnapshot(
            items: [
                ActivityCenterItem(notification: notification),
                ActivityCenterItem(friendActivity: friendActivity)
            ],
            sourceHealth: .allFresh,
            generatedAt: Date(timeIntervalSince1970: 10_000)
        )

        let restored = PersistedActivityCenterSnapshot(snapshot: snapshot).makeSnapshot()

        XCTAssertEqual(restored.items.count, 2)
        XCTAssertEqual(restored.items[0].route, snapshot.items[0].route)
        XCTAssertEqual(restored.items[1].route, .gameDetail(42))
        XCTAssertEqual(restored.items.map(\.identity), snapshot.items.map(\.identity))
        XCTAssertTrue(restored.sourceHealth.isFullyFailed, "restored snapshots always represent stale data")
    }

    // MARK: - Mapping

    func test_mapping_recommendationTypes_getRecommendationKind() {
        let item = ActivityCenterItem(notification: makeNotification(
            id: "n1",
            type: "library_curator",
            userID: nil,
            gameID: 5,
            reviewID: nil,
            createdAt: Date(timeIntervalSince1970: 9_000)
        ))
        XCTAssertEqual(item.kindCode, "recommendation")
        XCTAssertEqual(item.route, .gameDetail(5))
    }

    func test_mapping_undatedFriendActivity_isTreatedAsRead() {
        let item = ActivityCenterItem(friendActivity: makeFriendActivity(id: "f1", createdAt: nil))
        XCTAssertTrue(item.isRead, "undated items cannot participate in the watermark")
    }
}
