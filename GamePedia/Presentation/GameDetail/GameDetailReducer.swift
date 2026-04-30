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
            state.errorMessage = nil
            state.blockingLoadErrorMessage = nil
            state.inlineNoticeMessage = nil
            state.translatedSummary = nil
            state.translatedStoryline = nil
            state.isTranslationLoading = false
            state.isShowingTranslated = false
            state.translationRequest = nil
        case .setReviewFeed(let reviewFeed):
            state.reviews = reviewFeed.reviews
            state.reviewSummary = reviewFeed.summary
        case .setFavorite(let v):
            state.isFavorite = v
        case .setFavoriteLoading(let isFavoriteLoading):
            state.isFavoriteLoading = isFavoriteLoading
        case .setError(let msg):
            state.errorMessage = msg
            state.isLoading = false
        case .clearError:
            state.errorMessage = nil
        case .setBlockingLoadError(let message):
            state.blockingLoadErrorMessage = message
            state.isLoading = false
        case .setInlineNotice(let message):
            state.inlineNoticeMessage = message
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
        case .setAIReviewSummaryLoading:
            state.aiReviewSummarySectionState = .loading
        case .setAIReviewSummaryLoaded(let viewState):
            state.aiReviewSummarySectionState = .loaded(viewState)
        case .setAIReviewSummaryUnavailable(let message):
            state.aiReviewSummarySectionState = .unavailable(message)
        case .setAIReviewSummaryError(let message):
            state.aiReviewSummarySectionState = .error(message)
        case .setAIReviewSummaryExpanded(let isExpanded):
            guard case .loaded(let viewState) = state.aiReviewSummarySectionState else { break }
            state.aiReviewSummarySectionState = .loaded(viewState.settingExpanded(isExpanded))
        }
        return state
    }
}
