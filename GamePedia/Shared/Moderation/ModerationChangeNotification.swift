import Foundation

extension Notification.Name {
    static let moderationDidChange = Notification.Name("ModerationDidChangeNotification")
}

enum ModerationChangeUserInfoKey {
    static let targetType = "targetType"
    static let targetId = "targetId"
    static let blockedUserId = "blockedUserId"
    static let action = "action"
}

enum ModerationChangeAction: String {
    case reported
    case blocked
}
