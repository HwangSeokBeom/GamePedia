import Foundation

extension Notification.Name {
    static let reviewDidChange = Notification.Name("ReviewDidChangeNotification")
}

enum ReviewChangeUserInfoKey {
    static let gameId = "gameId"
    static let reviewId = "reviewId"
    static let action = "action"
}

enum ReviewChangeAction: String {
    case created
    case updated
    case deleted
}

enum ReviewChangeNotificationParser {
    static func gameId(from notification: Notification) -> Int? {
        let value = notification.userInfo?[ReviewChangeUserInfoKey.gameId]
        if let gameId = value as? Int {
            return gameId
        }
        if let gameId = value as? String {
            return Int(gameId.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}
