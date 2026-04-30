import Foundation

extension Notification.Name {
    static let currentUserProfileDidChange = Notification.Name("CurrentUserProfileDidChangeNotification")
    static let authSessionDidChange = Notification.Name("AuthSessionDidChangeNotification")
}

enum ProfileChangeUserInfoKey {
    static let userId = "userId"
    static let selectedTitles = "selectedTitles"
    static let selectedTitleKey = "selectedTitleKey"
    static let selectedTitle = "selectedTitle"
}

enum AuthSessionChangeUserInfoKey {
    static let isAuthenticated = "isAuthenticated"
    static let userId = "userId"
}
