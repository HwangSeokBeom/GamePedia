import Foundation

final class MarkAllNotificationsReadUseCase {
    private let notificationRepository: any NotificationRepository

    init(notificationRepository: any NotificationRepository) {
        self.notificationRepository = notificationRepository
    }

    func execute() async throws {
        try await notificationRepository.markAllNotificationsRead()
    }
}
