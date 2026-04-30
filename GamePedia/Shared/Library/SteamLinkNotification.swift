import Foundation

extension Notification.Name {
    static let steamLinkDidComplete = Notification.Name("SteamLinkDidCompleteNotification")
    static let steamLinkStateDidChange = Notification.Name("SteamLinkStateDidChangeNotification")
    static let libraryDidChange = Notification.Name("LibraryDidChangeNotification")
}

enum SteamLinkChangeUserInfoKey {
    static let result = "result"
}

enum SteamLinkStateChangeUserInfoKey {
    static let isLinked = "isLinked"
}

enum LibraryChangeUserInfoKey {
    static let source = "source"
}
