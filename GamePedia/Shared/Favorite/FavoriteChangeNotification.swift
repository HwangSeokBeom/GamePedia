import Foundation

extension Notification.Name {
    static let favoriteDidChange = Notification.Name("FavoriteDidChangeNotification")
}

enum FavoriteChangeUserInfoKey {
    static let gameId = "gameId"
    static let isFavorite = "isFavorite"
    static let action = "action"
}

enum FavoriteChangeAction: String {
    case added
    case removed
}
