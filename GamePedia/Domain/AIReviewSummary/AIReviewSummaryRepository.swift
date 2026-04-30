import Foundation

protocol AIReviewSummaryRepository {
    func fetchReviewSummary(gameId: Int) async throws -> AIReviewSummary
}
