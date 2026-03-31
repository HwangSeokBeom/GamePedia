import Foundation

extension Notification.Name {
    static let appNotificationsDidChange = Notification.Name("AppNotificationsDidChangeNotification")
}

enum AppNotificationChangeUserInfoKey {
    static let unreadCount = "unreadCount"
}
