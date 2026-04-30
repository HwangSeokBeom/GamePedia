import Foundation

protocol AISearchAssistRepository {
    func fetchSearchAssist(request: AISearchAssistRequest) async throws -> AISearchAssistResult
}

struct AISearchAssistRequest: Equatable {
    let query: String
    let platforms: [String]
    let genres: [String]
    let limit: Int
}

protocol FetchAISearchAssistUseCase {
    func execute(query: String, platforms: [String], genres: [String]) async throws -> AISearchAssistResult
}

struct DefaultFetchAISearchAssistUseCase: FetchAISearchAssistUseCase {
    private let repository: any AISearchAssistRepository
    private let limit: Int

    init(
        repository: any AISearchAssistRepository = DefaultAISearchAssistRepository(),
        limit: Int = 10
    ) {
        self.repository = repository
        self.limit = limit
    }

    func execute(query: String, platforms: [String] = [], genres: [String] = []) async throws -> AISearchAssistResult {
        let request = AISearchAssistRequest(
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            platforms: platforms,
            genres: genres,
            limit: limit
        )
        return try await repository.fetchSearchAssist(request: request)
    }
}
