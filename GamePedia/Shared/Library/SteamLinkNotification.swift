import Foundation

extension Notification.Name {
    static let steamLinkDidComplete = Notification.Name("SteamLinkDidCompleteNotification")
    static let steamLinkStateDidChange = Notification.Name("SteamLinkStateDidChangeNotification")
}

enum SteamLinkChangeUserInfoKey {
    static let result = "result"
}

enum SteamLinkStateChangeUserInfoKey {
    static let isLinked = "isLinked"
}
