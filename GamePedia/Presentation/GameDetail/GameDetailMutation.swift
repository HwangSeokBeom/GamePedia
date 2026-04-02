import Foundation

// MARK: - GameDetailMutation

enum GameDetailMutation {
    case setLoading(Bool)
    case setGame(GameDetail)
    case setReviewFeed(GameReviewFeed)
    case setFavorite(Bool)
    case setFavoriteLoading(Bool)
    case setError(String)
    case setTranslatedFields(summary: String?, storyline: String?)
    case setTranslationLoading(Bool)
    case setTranslationRequest(TranslationBatchRequest?)
    case setShowingTranslated(Bool)
}
