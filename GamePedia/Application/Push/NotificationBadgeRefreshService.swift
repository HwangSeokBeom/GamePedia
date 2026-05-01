import Foundation
import UIKit
import UserNotifications

final class NotificationBadgeRefreshService: @unchecked Sendable {
    static let shared = NotificationBadgeRefreshService()

    private let notificationRepository: any NotificationRepository
    private let throttleInterval: TimeInterval
    private let queue = DispatchQueue(label: "com.gamepedia.notificationBadgeRefresh")
    private var lastRefreshAt: Date?
    private var isRefreshing = false

    init(
        notificationRepository: any NotificationRepository = DefaultNotificationRepository(),
        throttleInterval: TimeInterval = 60
    ) {
        self.notificationRepository = notificationRepository
        self.throttleInterval = throttleInterval
    }

    func applyPayloadBadgeIfPresent(_ badge: Int?) {
        guard let badge else { return }
        Task { @MainActor [weak self] in
            self?.setApplicationBadgeCount(max(badge, 0))
            NotificationCenter.default.post(
                name: .appNotificationsDidChange,
                object: nil,
                userInfo: [AppNotificationChangeUserInfoKey.unreadCount: max(badge, 0)]
            )
        }
    }

    func refresh(reason: String, force: Bool = false) {
        queue.async { [weak self] in
            guard let self else { return }
            guard APIClient.shared.userAuthToken != nil else {
                print("[Notifications] count refresh skipped reason=authUnavailable source=\(reason)")
                return
            }

            let now = Date()
            if !force,
               let lastRefreshAt,
               now.timeIntervalSince(lastRefreshAt) < throttleInterval {
                print("[Notifications] count refresh skipped reason=throttled source=\(reason)")
                return
            }

            if isRefreshing {
                print("[Notifications] count refresh skipped reason=inFlight source=\(reason)")
                return
            }

            isRefreshing = true
            lastRefreshAt = now

            Task { [weak self] in
                guard let self else { return }
                defer {
                    self.queue.async {
                        self.isRefreshing = false
                    }
                }

                do {
                    let page = try await self.notificationRepository.fetchNotifications(page: 1, limit: 1)
                    await MainActor.run {
                        self.setApplicationBadgeCount(page.unreadCount)
                        NotificationCenter.default.post(
                            name: .appNotificationsDidChange,
                            object: nil,
                            userInfo: [AppNotificationChangeUserInfoKey.unreadCount: page.unreadCount]
                        )
                    }
                    print("[Notifications] count refresh completed reason=\(reason) unreadCount=\(page.unreadCount)")
                } catch let networkError as NetworkError {
                    if case .unauthorized = networkError {
                        print("[Notifications] count refresh skipped reason=authUnavailable source=\(reason)")
                    } else {
                        print("[Notifications] count refresh failed reason=\(reason) error=\(networkError.localizedDescription)")
                    }
                } catch {
                    print("[Notifications] count refresh failed reason=\(reason) error=\(error.localizedDescription)")
                }
            }
        }
    }

    @MainActor
    private func setApplicationBadgeCount(_ count: Int) {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(max(count, 0)) { error in
                if let error {
                    print("[Notifications] badge update failed error=\(error.localizedDescription)")
                }
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = max(count, 0)
        }
    }
}
