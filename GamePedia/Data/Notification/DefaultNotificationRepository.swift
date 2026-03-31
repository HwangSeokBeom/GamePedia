import Foundation

final class DefaultNotificationRepository: NotificationRepository {
    private let remoteDataSource: any NotificationRemoteDataSource

    init(remoteDataSource: any NotificationRemoteDataSource = DefaultNotificationRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchNotifications(page: Int, limit: Int) async throws -> AppNotificationPage {
        do {
            let data = try await remoteDataSource.fetchNotifications(page: page, limit: limit)
            let notifications = data.notifications.map { dto in
                AppNotification(
                    id: dto.id,
                    type: dto.type,
                    title: dto.title,
                    message: dto.message,
                    relatedGameID: Int(dto.relatedGameId ?? ""),
                    relatedUserID: dto.relatedUserId,
                    isRead: dto.isRead,
                    createdAt: dto.createdAt
                )
            }
            print(
                "[Notifications] repository mappedItemCount=\(notifications.count) " +
                "unreadCount=\(data.unreadCount) totalCount=\(data.meta?.totalCount ?? notifications.count)"
            )
            return AppNotificationPage(
                notifications: notifications,
                unreadCount: data.unreadCount
            )
        } catch {
            throw error
        }
    }

    func markAllNotificationsRead() async throws {
        try await remoteDataSource.markAllNotificationsRead()
    }
}
