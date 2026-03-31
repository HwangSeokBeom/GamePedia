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
        state.isLoading = true
        state.errorMessage = nil

        Task {
            do {
                let page = try await fetchNotificationsUseCase.execute(page: 1, limit: 30)
                await MainActor.run {
                    self.state.notifications = page.notifications
                    self.state.isLoading = false
                    self.state.errorMessage = nil
                    NotificationCenter.default.post(
                        name: .appNotificationsDidChange,
                        object: nil,
                        userInfo: [AppNotificationChangeUserInfoKey.unreadCount: page.unreadCount]
                    )
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
                    self.state.isLoading = false
                    self.state.errorMessage = "알림을 불러오지 못했어요."
                }
            }
        }
    }
}
