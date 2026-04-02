import Foundation

// MARK: - GameDetailReducer

enum GameDetailReducer {
    static func reduce(_ state: GameDetailState, _ mutation: GameDetailMutation) -> GameDetailState {
        var state = state
        switch mutation {
        case .setLoading(let v):
            state.isLoading = v
        case .setGame(let game):
            state.game = game
            state.isLoading = false
            state.translatedSummary = nil
            state.translatedStoryline = nil
            state.isTranslationLoading = false
            state.isShowingTranslated = false
            state.translationRequest = nil
        case .setReviewFeed(let reviewFeed):
            state.reviews = reviewFeed.reviews
            state.reviewSummary = reviewFeed.summary
            state.myReview = reviewFeed.myReview
        case .setFavorite(let v):
            state.isFavorite = v
        case .setFavoriteLoading(let isFavoriteLoading):
            state.isFavoriteLoading = isFavoriteLoading
        case .setError(let msg):
            state.errorMessage = msg
            state.isLoading = false
        case .setTranslatedFields(let summary, let storyline):
            if let summary {
                state.translatedSummary = summary
                print("[Translation] reducer applied translatedSummary")
            }
            if let storyline {
                state.translatedStoryline = storyline
                print("[Translation] reducer applied translatedStoryline")
            }
        case .setTranslationLoading(let isTranslationLoading):
            state.isTranslationLoading = isTranslationLoading
        case .setTranslationRequest(let translationRequest):
            state.translationRequest = translationRequest
        case .setShowingTranslated(let isShowingTranslated):
            state.isShowingTranslated = isShowingTranslated
        }
        return state
    }
}
