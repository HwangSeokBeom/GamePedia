import Combine
import Foundation

enum ActivityCenterIntent {
    case viewDidLoad
    case didTapRetry
}

// MARK: - ActivityCenterViewModel
//
// Unified Activity Center (2.4): one merged, deduplicated timeline over
// the notification inbox and the friend activity feed, with degraded-mode
// and offline last-known fallbacks.
//
// Load coalescing reuses the shared PaginationStateMachine exactly like
// the legacy Notifications screen: rapid retries share one in-flight
// request and stale completions can never overwrite newer state.

final class ActivityCenterViewModel {
    private(set) var state = ActivityCenterState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((ActivityCenterState) -> Void)?

    private let fetchActivityCenterUseCase: FetchActivityCenterUseCase
    private let markActivityCenterReadUseCase: MarkActivityCenterReadUseCase
    private let accountIDProvider: () -> String?
    private var hasLoaded = false
    private var pagination = PaginationStateMachine<Int>()
    private var hasPendingReload = false
    private var cancellables = Set<AnyCancellable>()

    init(
        fetchActivityCenterUseCase: FetchActivityCenterUseCase = FetchActivityCenterUseCase(
            notificationRepository: DefaultNotificationRepository(),
            friendRepository: DefaultFriendRepository(),
            readStateStore: LiveServiceRuntime.shared.readStateStore,
            snapshotStore: LiveServiceRuntime.shared.snapshotStore
        ),
        markActivityCenterReadUseCase: MarkActivityCenterReadUseCase = MarkActivityCenterReadUseCase(
            notificationRepository: DefaultNotificationRepository(),
            readStateStore: LiveServiceRuntime.shared.readStateStore
        ),
        accountIDProvider: @escaping () -> String? = { LiveServiceRuntime.shared.currentAccountID }
    ) {
        self.fetchActivityCenterUseCase = fetchActivityCenterUseCase
        self.markActivityCenterReadUseCase = markActivityCenterReadUseCase
        self.accountIDProvider = accountIDProvider
        ReviewCommentSyncCenter.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.hasLoaded else { return }
                self.load()
            }
            .store(in: &cancellables)
    }

    func send(_ intent: ActivityCenterIntent) {
        switch intent {
        case .viewDidLoad:
            guard !hasLoaded else {
                onStateChanged?(state)
                return
            }
            hasLoaded = true
            load()
        case .didTapRetry:
            load()
        }
    }

    private func load() {
        guard let load = pagination.beginRefresh() else {
            hasPendingReload = true
            print("[ActivityCenter] loadCoalesced reason=inFlight")
            return
        }

        state.isLoading = true
        state.errorMessage = nil
        let accountID = accountIDProvider()
        print("[ActivityCenter] load hasAccount=\(accountID != nil)")

        Task {
            do {
                let outcome = try await fetchActivityCenterUseCase.execute(accountID: accountID)
                await MainActor.run {
                    guard self.pagination.completeLoad(load, nextToken: nil) else { return }
                    self.state.items = outcome.snapshot.items
                    self.state.sourceHealth = outcome.snapshot.sourceHealth
                    self.state.isShowingLastKnown = outcome.isFromCache
                    self.state.lastKnownGeneratedAt = outcome.isFromCache
                        ? outcome.snapshot.generatedAt
                        : nil
                    self.state.isLoading = false
                    self.state.errorMessage = nil
                    // Badge updates only reflect fresh server-backed
                    // counts; a cached fallback never rewrites the badge.
                    if outcome.isFromCache == false {
                        NotificationCenter.default.post(
                            name: .appNotificationsDidChange,
                            object: nil,
                            userInfo: [
                                AppNotificationChangeUserInfoKey.unreadCount: outcome.snapshot.unreadCount
                            ]
                        )
                    }
                    print(
                        "[ActivityCenter] stateUpdated itemCount=\(outcome.snapshot.items.count) " +
                        "unreadCount=\(outcome.snapshot.unreadCount) fromCache=\(outcome.isFromCache) " +
                        "inbox=\(outcome.snapshot.sourceHealth.notificationInbox.rawValue) " +
                        "friendActivity=\(outcome.snapshot.sourceHealth.friendActivity.rawValue)"
                    )
                    self.drainPendingReloadIfNeeded()
                }

                guard outcome.isFromCache == false, outcome.snapshot.unreadCount > 0 else { return }
                await markActivityCenterReadUseCase.execute(
                    accountID: accountID,
                    snapshot: outcome.snapshot
                )
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .appNotificationsDidChange,
                        object: nil,
                        userInfo: [AppNotificationChangeUserInfoKey.unreadCount: 0]
                    )
                }
            } catch {
                await MainActor.run {
                    guard self.pagination.failLoad(load) else { return }
                    self.state.isLoading = false
                    self.state.items = []
                    self.state.isShowingLastKnown = false
                    self.state.lastKnownGeneratedAt = nil
                    self.state.errorMessage = L10n.tr("Localizable", "activityCenter.loadFailed")
                    print("[ActivityCenter] stateUpdated failure code=ALL_SOURCES_UNAVAILABLE")
                    // Retry stays user-driven on total failure.
                    self.hasPendingReload = false
                }
            }
        }
    }

    private func drainPendingReloadIfNeeded() {
        guard hasPendingReload else { return }
        hasPendingReload = false
        load()
    }
}
