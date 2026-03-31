import Foundation

struct NotificationResponseEnvelopeDTO<DataDTO: Decodable>: Decodable {
    let success: Bool
    let data: DataDTO
}

struct NotificationsResponseDataDTO: Decodable {
    let notifications: [NotificationItemDTO]
    let unreadCount: Int
    let meta: NotificationMetaDTO?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        notifications = (try? container.decodeLossyArray(NotificationItemDTO.self, forKey: .notifications)) ?? []
        unreadCount = (try? container.decodeLossyInt(forKey: .unreadCount)) ?? 0
        meta = try? container.decodeIfPresent(NotificationMetaDTO.self, forKey: .meta)
    }

    private enum CodingKeys: String, CodingKey {
        case notifications
        case unreadCount
        case meta
    }
}

struct NotificationItemDTO: Decodable {
    let id: String
    let type: String
    let title: String
    let message: String
    let relatedGameId: String?
    let relatedUserId: String?
    let isRead: Bool
    let readAt: Date?
    let createdAt: Date

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeLossyString(forKey: .id) ?? UUID().uuidString
        type = (try? container.decode(String.self, forKey: .type)) ?? "generic"
        title = (try? container.decode(String.self, forKey: .title)) ?? "알림"
        message = (try? container.decode(String.self, forKey: .message)) ?? ""
        relatedGameId = try container.decodeLossyStringIfPresent(forKey: .relatedGameId)
        relatedUserId = try container.decodeLossyStringIfPresent(forKey: .relatedUserId)
        isRead = (try? container.decode(Bool.self, forKey: .isRead)) ?? false
        readAt = try container.decodeDateIfPresent(forKey: .readAt)
        createdAt = (try container.decodeDateIfPresent(forKey: .createdAt)) ?? Date()
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case message
        case relatedGameId
        case relatedUserId
        case isRead
        case readAt
        case createdAt
    }
}

struct NotificationMetaDTO: Decodable {
    let page: Int
    let limit: Int
    let totalCount: Int
    let totalPages: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        page = (try? container.decodeLossyInt(forKey: .page)) ?? 1
        limit = (try? container.decodeLossyInt(forKey: .limit)) ?? 0
        totalCount = (try? container.decodeLossyInt(forKey: .totalCount)) ?? 0
        totalPages = (try? container.decodeLossyInt(forKey: .totalPages)) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case page
        case limit
        case totalCount
        case totalPages
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyInt(forKey key: K) throws -> Int? {
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? decode(String.self, forKey: key) {
            return Int(stringValue)
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        return nil
    }

    func decodeLossyString(forKey key: K) throws -> String? {
        if let stringValue = try? decode(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? decode(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return String(doubleValue)
        }
        return nil
    }

    func decodeLossyStringIfPresent(forKey key: K) throws -> String? {
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return String(doubleValue)
        }
        return nil
    }

    func decodeDateIfPresent(forKey key: K) throws -> Date? {
        if let date = try? decodeIfPresent(Date.self, forKey: key) {
            return date
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return NotificationDateParser.parse(stringValue)
        }
        return nil
    }

    func decodeLossyArray<Element: Decodable>(_ type: Element.Type, forKey key: K) throws -> [Element] {
        guard var container = try? nestedUnkeyedContainer(forKey: key) else {
            return []
        }

        var values: [Element] = []
        while !container.isAtEnd {
            if let value = try? container.decode(Element.self) {
                values.append(value)
            } else {
                _ = try? container.decode(DiscardableDecodable.self)
            }
        }
        return values
    }
}

private enum NotificationDateParser {
    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        iso8601WithFractionalSeconds.date(from: value)
            ?? iso8601.date(from: value)
    }
}

private struct DiscardableDecodable: Decodable {}
