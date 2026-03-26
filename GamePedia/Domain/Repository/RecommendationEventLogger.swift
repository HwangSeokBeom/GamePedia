import Foundation

protocol RecommendationEventLogger {
    func logImpression(items: [TodayRecommendation], source: RecommendationSource, at: Date) async
}
