import Foundation

protocol FetchLibraryCuratorUseCase {
    func execute(request: LibraryCuratorRequest) async throws -> LibraryCuratorResult
}

struct DefaultFetchLibraryCuratorUseCase: FetchLibraryCuratorUseCase {
    private let repository: any LibraryCuratorRepository

    init(repository: any LibraryCuratorRepository = DefaultLibraryCuratorRepository()) {
        self.repository = repository
    }

    func execute(request: LibraryCuratorRequest) async throws -> LibraryCuratorResult {
        try await repository.fetchCuratorResult(request: request)
    }
}
