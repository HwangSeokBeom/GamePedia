import Foundation

final class DefaultAIReviewSummaryRepository: AIReviewSummaryRepository {
    private let remoteDataSource: AIReviewSummaryRemoteDataSource

    init(remoteDataSource: AIReviewSummaryRemoteDataSource = DefaultAIReviewSummaryRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchReviewSummary(gameId: Int) async throws -> AIReviewSummary {
        do {
            let responseDTO = try await remoteDataSource.fetchReviewSummary(gameId: gameId)
            return AIReviewSummaryMapper.toEntity(responseDTO)
        } catch {
            throw AIReviewSummaryError.from(error: error)
        }
    }
}
