import Foundation

extension Notification.Name {
    static let currentUserProfileDidChange = Notification.Name("CurrentUserProfileDidChangeNotification")
}

enum ProfileChangeUserInfoKey {
    static let userId = "userId"
}
