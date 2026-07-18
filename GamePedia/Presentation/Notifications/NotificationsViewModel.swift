import Combine
import Foundation

enum NotificationsIntent {
    case viewDidLoad
    case didTapRetry
}

final class NotificationsViewModel {
    private(set) var state = NotificationsState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((NotificationsState) -> Void)?

    private let fetchNotificationsUseCase: FetchNotificationsUseCase
    private let markAllNotificationsReadUseCase: MarkAllNotificationsReadUseCase
    private var hasLoaded = false
    // Single-flight + stale-completion decisions come from the shared
    // machine: rapid retry taps coalesce into the one in-flight request,
    // and an older completion can never overwrite a newer one. This list
    // is a single page by contract (the repository merges local
    // notifications into every fetch), so `nextToken` is always nil.
    private var pagination = PaginationStateMachine<Int>()
    private var hasPendingReload = false
    private var cancellables = Set<AnyCancellable>()

    init(
        fetchNotificationsUseCase: FetchNotificationsUseCase = FetchNotificationsUseCase(
            notificationRepository: DefaultNotificationRepository()
        ),
        markAllNotificationsReadUseCase: MarkAllNotificationsReadUseCase = MarkAllNotificationsReadUseCase(
            notificationRepository: DefaultNotificationRepository()
        )
    ) {
        self.fetchNotificationsUseCase = fetchNotificationsUseCase
        self.markAllNotificationsReadUseCase = markAllNotificationsReadUseCase
        ReviewCommentSyncCenter.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.hasLoaded else { return }
                self.loadNotifications()
            }
            .store(in: &cancellables)
    }

    func send(_ intent: NotificationsIntent) {
        switch intent {
        case .viewDidLoad:
            guard !hasLoaded else {
                onStateChanged?(state)
                return
            }
            hasLoaded = true
            loadNotifications()
        case .didTapRetry:
            loadNotifications()
        }
    }

    private func loadNotifications() {
        guard let load = pagination.beginRefresh() else {
            // A load is already in flight: coalesce instead of duplicating
            // the request, but reconcile once more afterwards so an event
            // that arrived mid-load is not lost.
            hasPendingReload = true
            print("[Notifications] loadCoalesced reason=inFlight")
            return
        }

        state.isLoading = true
        state.errorMessage = nil
        print("[Notifications] loadNotifications page=1 limit=30")

        Task {
            do {
                let page = try await fetchNotificationsUseCase.execute(page: 1, limit: 30)
                await MainActor.run {
                    guard self.pagination.completeLoad(load, nextToken: nil) else { return }
                    self.state.notifications = page.notifications
                    self.state.isLoading = false
                    self.state.errorMessage = nil
                    NotificationCenter.default.post(
                        name: .appNotificationsDidChange,
                        object: nil,
                        userInfo: [AppNotificationChangeUserInfoKey.unreadCount: page.unreadCount]
                    )
                    print(
                        "[Notifications] stateUpdated success itemCount=\(page.notifications.count) " +
                        "unreadCount=\(page.unreadCount)"
                    )
                    self.drainPendingReloadIfNeeded()
                }

                guard page.unreadCount > 0 else { return }

                do {
                    try await markAllNotificationsReadUseCase.execute()
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: .appNotificationsDidChange,
                            object: nil,
                            userInfo: [AppNotificationChangeUserInfoKey.unreadCount: 0]
                        )
                    }
                } catch {
                    print("[Notifications] markAllRead failed error=\(error.localizedDescription)")
                }
            } catch {
                await MainActor.run {
                    guard self.pagination.failLoad(load) else { return }
                    self.state.isLoading = false
                    self.state.notifications = []
                    self.state.errorMessage = L10n.tr("Localizable", "notifications.loadFailed")
                    print("[Notifications] stateUpdated failure error=\(error)")
                    // No pending drain on failure: retry stays user-driven,
                    // mirroring the friend activity feed's policy.
                    self.hasPendingReload = false
                }
            }
        }
    }

    private func drainPendingReloadIfNeeded() {
        guard hasPendingReload else { return }
        hasPendingReload = false
        loadNotifications()
    }
}
