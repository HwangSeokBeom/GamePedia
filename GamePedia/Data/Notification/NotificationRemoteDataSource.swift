import Foundation

protocol NotificationRemoteDataSource {
    func fetchNotifications(page: Int, limit: Int) async throws -> NotificationsResponseDataDTO
    func markAllNotificationsRead() async throws
}

final class DefaultNotificationRemoteDataSource: NotificationRemoteDataSource {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchNotifications(page: Int, limit: Int) async throws -> NotificationsResponseDataDTO {
        print("[Notifications] request endpoint=GET /users/me/notifications page=\(page) limit=\(limit)")
        do {
            let response = try await apiClient.request(
                .myNotifications(page: page, limit: limit),
                as: NotificationResponseEnvelopeDTO<NotificationsResponseDataDTO>.self
            )
            print(
                "[Notifications] response endpoint=GET /users/me/notifications decodeSuccess " +
                "count=\(response.data.notifications.count) unreadCount=\(response.data.unreadCount) " +
                "totalCount=\(response.data.meta?.totalCount ?? response.data.notifications.count)"
            )
            return response.data
        } catch {
            print("[Notifications] response endpoint=GET /users/me/notifications decodeFailure error=\(error.localizedDescription)")
            throw error
        }
    }

    func markAllNotificationsRead() async throws {
        print("[Notifications] request endpoint=PATCH /users/me/notifications/read-all")
        try await apiClient.requestVoid(.markAllNotificationsRead)
        print("[Notifications] response endpoint=PATCH /users/me/notifications/read-all status=success")
    }
}
