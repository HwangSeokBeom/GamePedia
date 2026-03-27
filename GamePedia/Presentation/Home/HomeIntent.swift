import Foundation

// MARK: - HomeIntent

enum HomeIntent {
    case viewDidLoad
    case didTapGame(Game)
    case didTapFavorite(gameId: Int)
    case didTapSeeMore(section: HomeSection)
    case didTapNotification
}

enum HomeSection {
    case todayRecommendation
    case popular
    case trending

    var headerTitle: String {
        switch self {
        case .todayRecommendation:
            return "오늘의 추천"
        case .popular:
            return "인기 게임"
        case .trending:
            return "지금 뜨는 게임"
        }
    }

    var listTitle: String {
        switch self {
        case .todayRecommendation:
            return "추천 게임"
        case .popular:
            return "인기 게임"
        case .trending:
            return "트렌딩 게임"
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
            return "추천할 게임을 준비 중이에요."
        case .popular:
            return "인기 게임 목록을 불러오지 못했어요."
        case .trending:
            return "트렌딩 게임 목록을 불러오지 못했어요."
        }
    }
}

enum HomeRoute {
    case showGameList(section: HomeSection, games: [Game], wishlistedGameIDs: Set<Int>)
}
