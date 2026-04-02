import Foundation

protocol NotificationRepository {
    func fetchNotifications(page: Int, limit: Int) async throws -> AppNotificationPage
    func markAllNotificationsRead() async throws
}
