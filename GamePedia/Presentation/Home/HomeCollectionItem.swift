import Foundation

enum HomeCollectionItem: Hashable {
    // Product 2.2 Today
    case todayNotice(message: String)
    case todayItem(key: TodaySectionKey, item: TodayDisplayModel.Item)
    /// A section with no items. `retryTitle` is nil for a disabled section,
    /// which must never be offered a retry.
    case todayStatus(key: TodaySectionKey, message: String, retryTitle: String?)
    case todaySkeleton(key: TodaySectionKey, index: Int)

    // Legacy discovery
    case todayRecommendation(TodayRecommendation)
    case popular(Game)
    case trending(Game)
    case todayRecommendationSkeleton(Int)
    case popularSkeleton(Int)
    case trendingSkeleton(Int)

    /// The legacy IGDB game a tap should open, when there is one. A Today item
    /// is addressed by canonical UUID instead and routes through
    /// `TodayDisplayModel.Item.action`, so it deliberately yields nil here —
    /// the two identifier spaces never meet.
    var selectedGame: Game? {
        switch self {
        case .popular(let game), .trending(let game):
            return game
        case .todayRecommendation(let recommendation):
            return recommendation.game
        case .todayNotice, .todayItem, .todayStatus, .todaySkeleton,
             .todayRecommendationSkeleton, .popularSkeleton, .trendingSkeleton:
            return nil
        }
    }

    /// The Product 2.2 route a tap should take, if any.
    var todayAction: TodayDisplayModel.Item.Action? {
        if case .todayItem(_, let item) = self { return item.action }
        return nil
    }
}
