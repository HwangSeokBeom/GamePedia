import Foundation

final class DefaultNotificationRepository: NotificationRepository {
    private let remoteDataSource: any NotificationRemoteDataSource
    private let reviewCommentRepository: any ReviewCommentRepository

    init(
        remoteDataSource: any NotificationRemoteDataSource = DefaultNotificationRemoteDataSource(),
        reviewCommentRepository: any ReviewCommentRepository = DefaultReviewCommentRepository()
    ) {
        self.remoteDataSource = remoteDataSource
        self.reviewCommentRepository = reviewCommentRepository
    }

    func fetchNotifications(page: Int, limit: Int) async throws -> AppNotificationPage {
        let localNotifications = await reviewCommentRepository.fetchLocalNotifications()

        do {
            let data = try await remoteDataSource.fetchNotifications(page: page, limit: limit)
            let remoteNotifications = data.notifications.map { dto in
                AppNotification(
                    id: dto.id,
                    type: dto.type,
                    title: dto.title,
                    message: dto.message,
                    relatedGameID: Int(dto.relatedGameId ?? ""),
                    relatedUserID: dto.relatedUserId,
                    relatedReviewID: dto.relatedReviewId,
                    relatedCommentID: dto.relatedCommentId,
                    isRead: dto.isRead,
                    createdAt: dto.createdAt
                )
            }
            let notifications = (remoteNotifications + localNotifications)
                .sorted { $0.createdAt > $1.createdAt }
            print(
                "[Notifications] repository mappedItemCount=\(notifications.count) " +
                "unreadCount=\(data.unreadCount + localNotifications.filter { !$0.isRead }.count) totalCount=\(data.meta?.totalCount ?? notifications.count)"
            )
            return AppNotificationPage(
                notifications: notifications,
                unreadCount: data.unreadCount + localNotifications.filter { !$0.isRead }.count
            )
        } catch {
            guard !localNotifications.isEmpty else {
                throw error
            }
            return AppNotificationPage(
                notifications: localNotifications.sorted { $0.createdAt > $1.createdAt },
                unreadCount: localNotifications.filter { !$0.isRead }.count
            )
        }
    }

    func markAllNotificationsRead() async throws {
        var remoteError: Error?
        do {
            try await remoteDataSource.markAllNotificationsRead()
        } catch {
            remoteError = error
        }
        await reviewCommentRepository.markAllLocalNotificationsRead()
        if let remoteError {
            throw remoteError
        }
    }
}
