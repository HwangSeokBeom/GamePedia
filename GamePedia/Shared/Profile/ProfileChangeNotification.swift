import Foundation

extension Notification.Name {
    static let currentUserProfileDidChange = Notification.Name("CurrentUserProfileDidChangeNotification")
    static let authSessionDidChange = Notification.Name("AuthSessionDidChangeNotification")
    /// Posted after a successful server-side account deletion, in addition
    /// to the unauthenticated `authSessionDidChange`. Carries the deleted
    /// user's id so account-scoped local state can be purged.
    static let authAccountDidDelete = Notification.Name("AuthAccountDidDeleteNotification")
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
