import Foundation

protocol LibraryCuratorRepository {
    func fetchCuratorResult(request: LibraryCuratorRequest) async throws -> LibraryCuratorResult
}
