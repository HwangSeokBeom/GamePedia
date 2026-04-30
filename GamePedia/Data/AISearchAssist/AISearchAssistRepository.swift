import Foundation

final class DefaultAISearchAssistRepository: AISearchAssistRepository {
    private let remoteDataSource: any AISearchAssistRemoteDataSource

    init(remoteDataSource: any AISearchAssistRemoteDataSource = DefaultAISearchAssistRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchSearchAssist(request: AISearchAssistRequest) async throws -> AISearchAssistResult {
        do {
            let requestDTO = AISearchAssistRequestDTO(
                query: request.query,
                platforms: request.platforms,
                genres: request.genres,
                limit: request.limit
            )
            let responseDTO = try await remoteDataSource.fetchSearchAssist(requestDTO: requestDTO)
            return AISearchAssistMapper.toEntity(responseDTO)
        } catch {
            throw AISearchAssistError.from(error: error)
        }
    }
}
