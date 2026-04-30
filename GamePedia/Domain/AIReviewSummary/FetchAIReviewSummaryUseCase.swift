import Foundation

protocol FetchAIReviewSummaryUseCase {
    func execute(gameId: Int) async throws -> AIReviewSummary
}

struct DefaultFetchAIReviewSummaryUseCase: FetchAIReviewSummaryUseCase {
    private let repository: AIReviewSummaryRepository

    init(repository: AIReviewSummaryRepository = DefaultAIReviewSummaryRepository()) {
        self.repository = repository
    }

    func execute(gameId: Int) async throws -> AIReviewSummary {
        try await repository.fetchReviewSummary(gameId: gameId)
    }
}
