import Foundation

protocol LibraryRepository {
    func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverview
    func updateGameStatus(identifier: LibraryGameIdentifier, status: UserGameStatus) async throws -> LibraryGameStatusMutationResult
}
