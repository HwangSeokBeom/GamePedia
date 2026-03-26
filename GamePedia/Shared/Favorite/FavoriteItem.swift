import Foundation

struct FavoriteItem: Equatable, Hashable {
    let gameId: Int
    let createdAt: Date?
}

struct FavoriteStatus: Equatable {
    let isFavorite: Bool
}

struct FavoriteMutationResult: Equatable {
    let gameId: Int
    let isFavorite: Bool
}

enum FavoriteSortOption: String, CaseIterable {
    case latest
    case oldest
}

struct FavoriteGameEntry: Hashable {
    let favorite: FavoriteItem
    let game: Game
}
