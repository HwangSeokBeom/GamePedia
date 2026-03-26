import Foundation

// MARK: - HomeReducer

enum HomeReducer {
    static func reduce(_ state: HomeState, _ mutation: HomeMutation) -> HomeState {
        var state = state
        switch mutation {
        case .setLoading(let isLoading):
            state.isLoading = isLoading
        case .setHomeFeed(let feed):
            state.highlights = feed.highlights
            state.todayRecommendations = feed.todayRecommendations
            state.popularGames = feed.popularGames
            state.trendingGames = feed.trendingGames
            state.errorMessage = nil
            state.translatedTitles = [:]
        case .setWishlistedGameIDs(let ids):
            state.wishlistedGameIDs = ids
        case .setError(let message):
            state.errorMessage = message
            state.isLoading = false
        case .clearError:
            state.errorMessage = nil
        case .setTranslatedTitles(let titles):
            state.translatedTitles.merge(titles) { _, new in new }
        }
        return state
    }
}
