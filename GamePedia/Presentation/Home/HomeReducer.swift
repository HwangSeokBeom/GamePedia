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
        case .setSelectedFilter(let filter):
            state.selectedPlatformFilter = filter.platform
            state.selectedCategoryFilter = filter.category
            state.selectedGameModeFilter = filter.gameMode
        case .setToday(let today):
            state.today = today
            state.isTodayLoading = false
            state.retryingTodaySections = []
        case .setTodayLoading(let isLoading):
            state.isTodayLoading = isLoading
        case .setTodaySectionRetrying(let key, let isRetrying):
            if isRetrying {
                state.retryingTodaySections.insert(key)
            } else {
                state.retryingTodaySections.remove(key)
            }
        case .setUnreadNotificationCount(let unreadCount):
            state.unreadNotificationCount = max(unreadCount, 0)
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
