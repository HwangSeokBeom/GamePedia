import Foundation

// MARK: - HomeIntent

enum HomeIntent {
    case viewDidLoad
    case didTapGame(Game)
    case didTapFavorite(gameId: Int)
    case didTapHomeFilter
    case didTapApplyHomeFilters(HomeContentFilter)
    case didTapSeeMore(section: HomeSection)
    case didTapNotification
}

enum HomeSection: Equatable {
    case todayRecommendation
    case popular
    case trending

    var headerTitle: String {
        switch self {
        case .todayRecommendation:
            return L10n.Home.Section.todayRecommendation
        case .popular:
            return L10n.Home.Section.popular
        case .trending:
            return L10n.Home.Section.trending
        }
    }

    var listTitle: String {
        switch self {
        case .todayRecommendation:
            return L10n.Home.List.recommendation
        case .popular:
            return L10n.Home.List.popular
        case .trending:
            return L10n.Home.List.trending
        }
    }

    var systemImageName: String {
        switch self {
        case .todayRecommendation:
            return "sparkles"
        case .popular:
            return "flame.fill"
        case .trending:
            return "bolt.fill"
        }
    }

    var emptyMessage: String {
        switch self {
        case .todayRecommendation:
            return L10n.Home.Empty.recommendation
        case .popular:
            return L10n.Home.Empty.popular
        case .trending:
            return L10n.Home.Empty.trending
        }
    }
}

enum HomeRoute {
    case presentHomeFilterSheet(HomeContentFilter)
    case showGameList(section: HomeSection, games: [Game], wishlistedGameIDs: Set<Int>)
    case showNotifications
}
