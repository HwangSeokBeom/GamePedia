import Foundation

final class DefaultAIRecommendationRepository: AIRecommendationRepository {
    private let remoteDataSource: any AIRecommendationRemoteDataSource

    init(remoteDataSource: any AIRecommendationRemoteDataSource = DefaultAIRecommendationRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchRecommendations(request: AIRecommendationRequest) async throws -> AIRecommendationResult {
        do {
            let requestDTO = AIRecommendationRequestDTO(
                query: request.query,
                platforms: request.platforms,
                preferredGenres: request.preferredGenres,
                excludedGameIds: request.excludedGameIds,
                limit: request.limit
            )
            let responseDTO = try await remoteDataSource.fetchRecommendations(requestDTO: requestDTO)
            return AIRecommendationMapper.toEntity(responseDTO)
        } catch {
            throw AIRecommendationError.from(error: error)
        }
    }
}

