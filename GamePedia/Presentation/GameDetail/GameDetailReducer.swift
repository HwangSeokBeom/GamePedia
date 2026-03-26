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
            state.translatedTitle = nil
            state.translatedSummary = nil
            state.translatedStoryline = nil
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
        case .setTranslatedFields(let title, let summary, let storyline):
            if let title {
                state.translatedTitle = title
                print("[Translation] reducer applied translatedTitle")
            }
            if let summary {
                state.translatedSummary = summary
                print("[Translation] reducer applied translatedSummary")
            }
            if let storyline {
                state.translatedStoryline = storyline
                print("[Translation] reducer applied translatedStoryline")
            }
        }
        return state
    }
}
