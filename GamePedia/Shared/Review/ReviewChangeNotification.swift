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
