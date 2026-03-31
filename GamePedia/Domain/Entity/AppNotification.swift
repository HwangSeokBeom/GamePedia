import Foundation

struct AppNotification: Hashable {
    let id: String
    let type: String
    let title: String
    let message: String
    let relatedGameID: Int?
    let isRead: Bool
    let createdAt: Date

    var relativeCreatedAtText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

struct AppNotificationPage: Hashable {
    let notifications: [AppNotification]
    let unreadCount: Int
}
