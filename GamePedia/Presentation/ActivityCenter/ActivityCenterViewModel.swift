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
//
// Session ownership: every load is bound to the LiveServiceSession captured
// when it starts and revalidates it after every await. Work from a
// superseded session (logout, login, account switch, account deletion)
// cannot render, persist, post badge changes, or invoke mark-read; a
// session transition also cancels the in-flight load and resets the
// pagination machine so its stale completions are structurally rejected.
//
// Badge policy: the global notification badge is updated only from a fresh
// authoritative inbox response (`serverInboxUnreadCount`) or a confirmed
// remote mark-read. Friend activity, cached fallbacks, and failed remote
// marks never touch the badge.

final class ActivityCenterViewModel {
    private(set) var state = ActivityCenterState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((ActivityCenterState) -> Void)?

    private let fetchActivityCenterUseCase: FetchActivityCenterUseCase
    private let markActivityCenterReadUseCase: MarkActivityCenterReadUseCase
    private let sessionProvider: () -> LiveServiceSession
    private var hasLoaded = false
    private var pagination = PaginationStateMachine<Int>()
    private var hasPendingReload = false
    private var loadTask: Task<Void, Never>?
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
        sessionProvider: @escaping () -> LiveServiceSession = { LiveServiceRuntime.shared.currentSession }
    ) {
        self.fetchActivityCenterUseCase = fetchActivityCenterUseCase
        self.markActivityCenterReadUseCase = markActivityCenterReadUseCase
        self.sessionProvider = sessionProvider
        ReviewCommentSyncCenter.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.hasLoaded else { return }
                self.load()
            }
            .store(in: &cancellables)
        observeSessionTransitions()
    }

    deinit {
        loadTask?.cancel()
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

    // MARK: - Session transitions

    private func observeSessionTransitions() {
        let names: [Notification.Name] = [.authSessionDidChange, .authAccountDidDelete]
        for name in names {
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.handleSessionTransitionIfNeeded()
                }
                .store(in: &cancellables)
        }
    }

    private var lastKnownSession: LiveServiceSession?

    private func handleSessionTransitionIfNeeded() {
        let session = sessionProvider()
        guard session != lastKnownSession else { return }
        lastKnownSession = session
        // Invalidate everything owned by the previous session: the task is
        // cancelled, and a fresh pagination machine structurally rejects
        // completions of loads it never began.
        loadTask?.cancel()
        loadTask = nil
        pagination = PaginationStateMachine<Int>()
        hasPendingReload = false
        guard hasLoaded else { return }
        state = ActivityCenterState()
        if session.accountID != nil {
            load()
        }
    }

    // MARK: - Load

    private func load() {
        guard let load = pagination.beginRefresh() else {
            hasPendingReload = true
            print("[ActivityCenter] loadCoalesced reason=inFlight")
            return
        }

        state.isLoading = true
        state.errorMessage = nil
        let session = sessionProvider()
        lastKnownSession = session
        let sessionProvider = self.sessionProvider
        let isSessionStillCurrent: @Sendable () -> Bool = { sessionProvider() == session }
        print("[ActivityCenter] load hasAccount=\(session.accountID != nil)")

        let fetchUseCase = fetchActivityCenterUseCase
        let markUseCase = markActivityCenterReadUseCase
        loadTask = Task { [weak self] in
            do {
                let outcome = try await fetchUseCase.execute(
                    accountID: session.accountID,
                    isSessionStillCurrent: isSessionStillCurrent
                )
                await MainActor.run {
                    // Session first: a stale load may not even complete the
                    // (already replaced) pagination machine, let alone render.
                    guard let self, isSessionStillCurrent() else { return }
                    guard self.pagination.completeLoad(load, nextToken: nil) else { return }
                    self.state.items = outcome.snapshot.items
                    self.state.sourceHealth = outcome.snapshot.sourceHealth
                    self.state.isShowingLastKnown = outcome.isFromCache
                    self.state.lastKnownGeneratedAt = outcome.isFromCache
                        ? outcome.snapshot.generatedAt
                        : nil
                    self.state.isLoading = false
                    self.state.errorMessage = nil
                    // Badge authority: only the fresh remote inbox's own
                    // unread count. Friend activity, local fallbacks, and
                    // cached snapshots never rewrite the badge.
                    if let serverUnread = outcome.serverInboxUnreadCount {
                        NotificationCenter.default.post(
                            name: .appNotificationsDidChange,
                            object: nil,
                            userInfo: [
                                AppNotificationChangeUserInfoKey.unreadCount: serverUnread
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

                guard outcome.isFromCache == false,
                      outcome.snapshot.unreadCount > 0 || (outcome.serverInboxUnreadCount ?? 0) > 0,
                      isSessionStillCurrent() else { return }
                let markResult = await markUseCase.execute(
                    accountID: session.accountID,
                    snapshot: outcome.snapshot,
                    serverInboxUnreadCount: outcome.serverInboxUnreadCount,
                    isSessionStillCurrent: isSessionStillCurrent
                )
                // Zero is published only when the server confirmed the mark
                // AND the session is still the one that requested it. A
                // failed remote mark leaves the known unread count standing.
                guard markResult == .remoteConfirmed else { return }
                await MainActor.run {
                    guard self != nil, isSessionStillCurrent() else { return }
                    NotificationCenter.default.post(
                        name: .appNotificationsDidChange,
                        object: nil,
                        userInfo: [AppNotificationChangeUserInfoKey.unreadCount: 0]
                    )
                }
            } catch {
                await MainActor.run {
                    guard let self, isSessionStillCurrent() else { return }
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
