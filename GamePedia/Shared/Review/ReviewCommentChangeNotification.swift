import Foundation

extension Notification.Name {
    static let reviewCommentsDidChange = Notification.Name("ReviewCommentsDidChangeNotification")
}

enum ReviewCommentChangeUserInfoKey {
    static let reviewId = "reviewId"
    static let commentId = "commentId"
    static let gameId = "gameId"
    static let action = "action"
}

enum ReviewCommentChangeAction: String {
    case created
    case updated
    case deleted
    case reacted
}
