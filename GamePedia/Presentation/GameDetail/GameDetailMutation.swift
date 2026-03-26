import Foundation

// MARK: - GameDetailMutation

enum GameDetailMutation {
    case setLoading(Bool)
    case setGame(GameDetail)
    case setReviews([Review])
    case setOwned(Bool)
    case setError(String)
    case setTranslatedFields(title: String?, summary: String?, storyline: String?)
}
