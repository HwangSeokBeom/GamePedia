import Foundation

// MARK: - HomeState

struct HomeState {
    var isLoading: Bool = false
    var highlights: [HomeHighlightItem] = []
    var todayRecommendations: [TodayRecommendation] = []
    var popularGames: [Game] = []
    var trendingGames: [Game] = []
    var wishlistedGameIDs: Set<Int> = []
    var errorMessage: String? = nil
    var translatedTitles: [Int: String] = [:]
    var selectedPlatformFilter: HomePlatformFilter = .all
    var selectedCategoryFilter: HomeCategoryFilter = .all
    var selectedGameModeFilter: HomeGameModeFilter = .all
    var unreadNotificationCount: Int = 0

    var showsSkeleton: Bool {
        isLoading
            && highlights.isEmpty
            && todayRecommendations.isEmpty
            && popularGames.isEmpty
            && trendingGames.isEmpty
    }

    var selectedFilter: HomeContentFilter {
        HomeContentFilter(
            platform: selectedPlatformFilter,
            category: selectedCategoryFilter,
            gameMode: selectedGameModeFilter
        )
    }

    var hasActiveFilters: Bool {
        selectedFilter.hasActiveSelection
    }

    func resolvedTitle(for game: Game) -> String {
        game.title
    }

    func resolvedSupportingText(for highlight: HomeHighlightItem) -> String {
        let fallbackText = highlight.supportingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let summary = highlight.game.resolvedSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty else {
            return fallbackText
        }

        let singleLine = summary.replacingOccurrences(of: "\n", with: " ")
        if singleLine.count <= 76 { return singleLine }
        let index = singleLine.index(singleLine.startIndex, offsetBy: 76)
        return "\(singleLine[..<index])..."
    }

    var resolvedHighlights: [HomeHighlightItem] {
        highlights.map {
            HomeHighlightItem(
                game: $0.game,
                badgeText: $0.badgeText,
                titleText: resolvedTitle(for: $0.game),
                metaText: $0.metaText,
                supportingText: resolvedSupportingText(for: $0)
            )
        }
    }
}
