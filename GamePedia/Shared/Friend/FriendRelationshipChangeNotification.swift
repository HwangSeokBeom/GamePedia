import Foundation

extension Notification.Name {
    static let friendRelationshipDidChange = Notification.Name("FriendRelationshipDidChangeNotification")
}

enum FriendRelationshipChangeUserInfoKey {
    static let userID = "userID"
    static let action = "action"
}

enum FriendRelationshipChangeAction: String {
    case removed
    case blocked
}
