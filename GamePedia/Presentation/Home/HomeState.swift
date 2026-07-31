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

    /// The Product 2.2 Today feed, when it is available to this user. Nil
    /// means Today is not being shown at all — the feature is off, the user is
    /// signed out, or it has not loaded yet — and Home falls back to the
    /// legacy discovery experience on its own.
    var today: TodayDisplayModel? = nil
    /// True while the first Today load for this account is in flight.
    var isTodayLoading: Bool = false

    /// Sections the user asked to retry individually; used to show progress on
    /// exactly the one they tapped rather than the whole feed.
    var retryingTodaySections: Set<TodaySectionKey> = []

    var showsTodaySkeleton: Bool {
        isTodayLoading && today == nil
    }

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
