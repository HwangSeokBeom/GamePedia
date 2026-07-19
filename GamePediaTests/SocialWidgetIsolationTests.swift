import XCTest
@testable import GamePedia

// H6 — friend-feed / widget account isolation.
//
// Social widget payloads in the shared app group are stamped with a
// non-identifying session generation. Every account transition rotates the
// generation and clears the payloads; readers reject any stale, unstamped,
// or foreign-generation snapshot; delayed feed work from a previous session
// can never write over the current session's widget state; and no raw
// account identifier is ever persisted.
final class SocialWidgetIsolationTests: XCTestCase {

    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var store: SocialWidgetSnapshotStore!

    override func setUp() {
        super.setUp()
        suiteName = "social-widget-isolation-tests-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        store = SocialWidgetSnapshotStore(userDefaults: userDefaults)
    }

    override func tearDown() {
        if let suiteName {
            userDefaults?.removePersistentDomain(forName: suiteName)
        }
        super.tearDown()
    }

    private func makeSummary(id: String = "item-1", title: String = "Friend") -> FriendActivitySummaryWidgetData {
        FriendActivitySummaryWidgetData(
            generatedAt: Date(timeIntervalSince1970: 9_000),
            title: title,
            summary: "played something",
            items: [
                FriendActivitySummaryWidgetData.Item(
                    id: id,
                    title: title,
                    subtitle: "played something",
                    actorAvatarURL: nil,
                    gameCoverURL: nil,
                    timestampText: "now"
                )
            ]
        )
    }

    private let friendActivityKey = "gamepedia.social.widget.friend_activity"

    // MARK: - Store: generation scoping

    func test_saveAndLoad_roundTripWithinOneSession() {
        store.saveFriendActivitySummary(makeSummary())
        XCTAssertEqual(store.loadFriendActivitySummary()?.items.first?.id, "item-1")
    }

    func test_sessionTransition_clearsPayloadsAndRotatesGeneration() {
        store.saveFriendActivitySummary(makeSummary())
        store.saveRecommendedGame(RecommendedGameWidgetData(
            generatedAt: Date(timeIntervalSince1970: 9_000),
            gameID: 7,
            title: "Game",
            subtitle: "s",
            coverImageURL: nil,
            ratingText: nil
        ))
        let generationBefore = store.currentSessionGeneration

        store.handleSessionTransition()

        XCTAssertNil(store.loadFriendActivitySummary(), "social data must not survive a session transition")
        XCTAssertNil(store.loadRecommendedGame())
        XCTAssertNil(userDefaults.data(forKey: friendActivityKey), "the raw payload must be deleted, not just hidden")
        XCTAssertNotEqual(store.currentSessionGeneration, generationBefore)
    }

    func test_staleGenerationSnapshot_isRejectedAndDeleted() {
        // A payload stamped by a previous session generation lands in the
        // app group AFTER the rotation (the delayed-write race).
        store.saveFriendActivitySummary(makeSummary())
        let staleBlob = userDefaults.data(forKey: friendActivityKey)
        store.handleSessionTransition()
        userDefaults.set(staleBlob, forKey: friendActivityKey)

        XCTAssertNil(store.loadFriendActivitySummary(), "readers must reject a stale-generation snapshot")
        XCTAssertNil(userDefaults.data(forKey: friendActivityKey), "the rejected snapshot must be deleted")
    }

    func test_unstampedLegacyPayload_isRejectedAndDeleted() throws {
        // Pre-fix persisted format: the bare payload without a generation.
        let legacy = try JSONEncoder().encode(makeSummary())
        userDefaults.set(legacy, forKey: friendActivityKey)

        XCTAssertNil(store.loadFriendActivitySummary())
        XCTAssertNil(userDefaults.data(forKey: friendActivityKey))
    }

    func test_persistedWidgetDataContainsNoAccountIdentifier() throws {
        let accountID = "raw-account-uuid-1234"
        store.saveFriendActivitySummary(makeSummary())

        let blob = try XCTUnwrap(userDefaults.data(forKey: friendActivityKey))
        let text = String(decoding: blob, as: UTF8.self)
        XCTAssertFalse(text.contains(accountID))
        let generation = try XCTUnwrap(store.currentSessionGeneration)
        XCTAssertNotNil(UUID(uuidString: generation), "the generation must be a random, non-identifying token")
        XCTAssertFalse(generation.contains(accountID))
    }

    // MARK: - Runtime: transitions drive rotation

    private func makeRuntime(store: SocialWidgetSnapshotStore, center: NotificationCenter) -> LiveServiceRuntime {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("social-widget-runtime-\(UUID().uuidString)", isDirectory: true)
        return LiveServiceRuntime(
            featureFlags: AppConfig.featureFlags,
            notificationCenter: center,
            breadcrumbs: OperationBreadcrumbRecorder(),
            readStateStore: ActivityReadStateStore(directoryURL: directory),
            snapshotStore: FileActivityCenterSnapshotStore(directoryURL: directory),
            socialWidgetStore: store
        )
    }

    func test_accountScopeChanges_rotateGenerationAndClearData() {
        let runtime = makeRuntime(store: store, center: NotificationCenter())

        runtime.handleSessionChange(isAuthenticated: true, userID: "acct-a")
        let loginSession = runtime.currentSession
        store.saveFriendActivitySummary(makeSummary())

        // Same-account token refresh: session and widget data survive.
        runtime.handleSessionChange(isAuthenticated: true, userID: "acct-a")
        XCTAssertEqual(runtime.currentSession, loginSession)
        XCTAssertNotNil(store.loadFriendActivitySummary())

        // Switch: new generation, no surviving social data.
        runtime.handleSessionChange(isAuthenticated: true, userID: "acct-b")
        XCTAssertNotEqual(runtime.currentSession.generation, loginSession.generation)
        XCTAssertEqual(runtime.currentSession.accountID, "acct-b")
        XCTAssertNil(store.loadFriendActivitySummary())

        // Logout: another rotation.
        store.saveFriendActivitySummary(makeSummary())
        runtime.handleSessionChange(isAuthenticated: false, userID: nil)
        XCTAssertNil(runtime.currentSession.accountID)
        XCTAssertNil(store.loadFriendActivitySummary())
    }

    func test_accountDeletion_clearsWidgetStateAndBumpsGeneration() {
        let runtime = makeRuntime(store: store, center: NotificationCenter())
        runtime.handleSessionChange(isAuthenticated: true, userID: "acct-a")
        let before = runtime.currentSession
        store.saveFriendActivitySummary(makeSummary())

        runtime.handleAccountDeletionMarker(userID: "acct-a")

        XCTAssertNil(runtime.currentSession.accountID)
        XCTAssertNotEqual(runtime.currentSession.generation, before.generation)
        XCTAssertNil(store.loadFriendActivitySummary(), "widget social data must be cleared on account deletion")
    }

    func test_deletionOfDifferentAccount_keepsSessionAndData() {
        let runtime = makeRuntime(store: store, center: NotificationCenter())
        runtime.handleSessionChange(isAuthenticated: true, userID: "acct-a")
        let before = runtime.currentSession
        store.saveFriendActivitySummary(makeSummary())

        runtime.handleAccountDeletionMarker(userID: "acct-other")

        XCTAssertEqual(runtime.currentSession, before)
        XCTAssertNotNil(store.loadFriendActivitySummary())
    }

    // MARK: - Feed view model: session binding before widget writes

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

    private final class GatedFeedRepository: FriendRepository, @unchecked Sendable {
        private struct StubError: Error {}
        private let lock = NSLock()
        private var gatedContinuations: [CheckedContinuation<Void, Never>] = []
        private var gateRemaining = 0
        private(set) var fetchCallCount = 0
        var activities: [FriendActivityItem] = []
        var onFetchStarted: ((Int) -> Void)?

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
            let current = fetchCallCount
            let shouldGate = gateRemaining > 0
            if shouldGate { gateRemaining -= 1 }
            let callback = onFetchStarted
            let page = FriendActivityFeedPage(activities: activities, nextCursor: nil)
            lock.unlock()
            callback?(current)
            if shouldGate {
                await withCheckedContinuation { continuation in
                    lock.lock()
                    gatedContinuations.append(continuation)
                    lock.unlock()
                }
            }
            return page
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

    private func makeActivity(id: String, nickname: String) -> FriendActivityItem {
        FriendActivityItem(
            id: id,
            actor: FriendUserSummary(
                id: "actor-\(id)",
                nickname: nickname,
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

    private func makeFeedViewModel(
        repository: GatedFeedRepository,
        session: SessionBox
    ) -> FriendActivityFeedViewModel {
        FriendActivityFeedViewModel(
            fetchFriendActivityFeedUseCase: FetchFriendActivityFeedUseCase(repository: repository),
            widgetSnapshotStore: store,
            metricRecorder: PerformanceMetricRecorder(
                tracer: NoopSignpostTracer(),
                logsSamples: false
            ),
            realtimeInvalidationSource: nil,
            sessionProvider: { session.current }
        )
    }

    @MainActor
    func test_feedResponseAfterLogout_neverWritesWidgetData() async {
        let repository = GatedFeedRepository()
        repository.activities = [makeActivity(id: "a1", nickname: "friend-a")]
        repository.gateNextFetches(1)
        let session = SessionBox(accountID: "acct-a")
        let viewModel = makeFeedViewModel(repository: repository, session: session)

        let fetchStarted = expectation(description: "fetch started")
        repository.onFetchStarted = { count in
            if count == 1 { fetchStarted.fulfill() }
        }
        viewModel.send(.viewDidLoad)
        await fulfillment(of: [fetchStarted], timeout: 10)

        // Logout (and the app-side rotation) happen before the response.
        session.transition(to: nil)
        store.handleSessionTransition()
        repository.releaseGate()

        // Deterministic settle: an independent second view model under a
        // guest session (which never writes widget data) completes a load.
        let settleRepository = GatedFeedRepository()
        let settleSession = SessionBox(accountID: nil)
        let second = makeFeedViewModel(repository: settleRepository, session: settleSession)
        let settled = expectation(description: "second feed settled")
        second.onStateChanged = { state in
            if state.isLoading == false, state.isRefreshing == false { settled.fulfill() }
        }
        settled.assertForOverFulfill = false
        second.send(.viewDidLoad)
        await fulfillment(of: [settled], timeout: 10)

        XCTAssertNil(
            store.loadFriendActivitySummary(),
            "a stale session's feed response must never reach the widget store"
        )
        XCTAssertNil(userDefaults.data(forKey: friendActivityKey))
    }

    @MainActor
    func test_delayedAccountAResponse_cannotOverwriteAccountBWidgetState() async {
        let repositoryA = GatedFeedRepository()
        repositoryA.activities = [makeActivity(id: "a1", nickname: "friend-of-a")]
        repositoryA.gateNextFetches(1)
        let session = SessionBox(accountID: "acct-a")
        let viewModelA = makeFeedViewModel(repository: repositoryA, session: session)

        let fetchStarted = expectation(description: "A fetch started")
        repositoryA.onFetchStarted = { count in
            if count == 1 { fetchStarted.fulfill() }
        }
        viewModelA.send(.viewDidLoad)
        await fulfillment(of: [fetchStarted], timeout: 10)

        // B logs in: rotation clears the store, then B's feed writes.
        session.transition(to: "acct-b")
        store.handleSessionTransition()
        let repositoryB = GatedFeedRepository()
        repositoryB.activities = [makeActivity(id: "b1", nickname: "friend-of-b")]
        let viewModelB = makeFeedViewModel(repository: repositoryB, session: session)
        let bSettled = expectation(description: "B feed settled")
        viewModelB.onStateChanged = { state in
            if state.isLoading == false, state.items.isEmpty == false { bSettled.fulfill() }
        }
        bSettled.assertForOverFulfill = false
        viewModelB.send(.viewDidLoad)
        await fulfillment(of: [bSettled], timeout: 10)
        let bWidgetData = store.loadFriendActivitySummary()
        XCTAssertEqual(bWidgetData?.items.first?.title, "friend-of-b")

        // A's delayed response lands afterwards: it must change nothing.
        repositoryA.releaseGate()
        let settleRepository = GatedFeedRepository()
        let settleSession = SessionBox(accountID: nil)
        let settleViewModel = makeFeedViewModel(repository: settleRepository, session: settleSession)
        let settled = expectation(description: "settle load finished")
        settleViewModel.onStateChanged = { state in
            if state.isLoading == false { settled.fulfill() }
        }
        settled.assertForOverFulfill = false
        settleViewModel.send(.viewDidLoad)
        await fulfillment(of: [settled], timeout: 10)

        XCTAssertEqual(
            store.loadFriendActivitySummary()?.items.first?.title, "friend-of-b",
            "old account work must not overwrite the new account's widget state"
        )
    }
}
