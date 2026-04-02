import Foundation

extension Notification.Name {
    static let currentUserProfileDidChange = Notification.Name("CurrentUserProfileDidChangeNotification")
}

enum ProfileChangeUserInfoKey {
    static let userId = "userId"
    static let selectedTitles = "selectedTitles"
    static let selectedTitleKey = "selectedTitleKey"
    static let selectedTitle = "selectedTitle"
}
