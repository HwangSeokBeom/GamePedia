import Foundation

// MARK: - GameDetailMutation

enum GameDetailMutation {
    case setLoading(Bool)
    case setGame(GameDetail)
    case setReviewFeed(GameReviewFeed)
    case setFavorite(Bool)
    case setFavoriteLoading(Bool)
    case setError(String)
    case setTranslatedFields(title: String?, summary: String?, storyline: String?)
}
