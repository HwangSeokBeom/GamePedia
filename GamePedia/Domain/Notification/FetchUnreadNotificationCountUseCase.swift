import Foundation

final class FetchUnreadNotificationCountUseCase {
    private let notificationRepository: any NotificationRepository

    init(notificationRepository: any NotificationRepository) {
        self.notificationRepository = notificationRepository
    }

    func execute() async throws -> Int {
        let page = try await notificationRepository.fetchNotifications(page: 1, limit: 1)
        return page.unreadCount
    }
}
