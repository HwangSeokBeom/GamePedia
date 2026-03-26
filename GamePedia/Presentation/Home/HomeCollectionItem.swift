import Foundation

enum HomeCollectionItem: Hashable {
    case todayRecommendation(TodayRecommendation)
    case popular(Game)
    case trending(Game)
    case todayRecommendationSkeleton(Int)
    case popularSkeleton(Int)
    case trendingSkeleton(Int)

    var selectedGame: Game? {
        switch self {
        case .popular(let game), .trending(let game):
            return game
        case .todayRecommendation(let recommendation):
            return recommendation.game
        case .todayRecommendationSkeleton, .popularSkeleton, .trendingSkeleton:
            return nil
        }
    }
}
