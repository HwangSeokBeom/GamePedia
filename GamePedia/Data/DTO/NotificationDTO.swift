import Foundation

struct NotificationResponseEnvelopeDTO<DataDTO: Decodable>: Decodable {
    let success: Bool
    let data: DataDTO
}

struct NotificationsResponseDataDTO: Decodable {
    let notifications: [NotificationItemDTO]
    let unreadCount: Int
    let meta: NotificationMetaDTO?
}

struct NotificationItemDTO: Decodable {
    let id: String
    let type: String
    let title: String
    let message: String
    let relatedGameId: String?
    let isRead: Bool
    let createdAt: Date
}

struct NotificationMetaDTO: Decodable {
    let page: Int
    let limit: Int
    let totalCount: Int
    let totalPages: Int
}
