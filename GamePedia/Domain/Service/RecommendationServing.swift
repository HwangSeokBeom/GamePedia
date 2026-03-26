import Foundation

protocol RecommendationServing {
    func recommend(
        from candidates: [Game],
        activity: UserActivity,
        limit: Int,
        config: RecommendationConfig,
        now: Date
    ) -> [TodayRecommendation]
}
