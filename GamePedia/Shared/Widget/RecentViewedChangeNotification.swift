import Foundation

extension Notification.Name {
    static let recentViewedDidChange = Notification.Name("RecentViewedDidChangeNotification")
}

enum RecentViewedChangeUserInfoKey {
    static let gameId = "gameId"
}
