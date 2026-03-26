import Foundation

protocol UserActivityRepository {
    func loadActivity() async -> UserActivity
    func recordViewed(game: Game) async
    func recordLiked(game: Game) async
    func recordRecommendationExposure(ids: [Int], at: Date) async
}
