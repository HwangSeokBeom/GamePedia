import Foundation

final class FetchNotificationsUseCase {
    private let notificationRepository: any NotificationRepository

    init(notificationRepository: any NotificationRepository) {
        self.notificationRepository = notificationRepository
    }

    func execute(page: Int = 1, limit: Int = 20) async throws -> AppNotificationPage {
        try await notificationRepository.fetchNotifications(page: page, limit: limit)
    }
}
