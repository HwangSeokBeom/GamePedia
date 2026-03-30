import Foundation

protocol LibraryRepository {
    func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverview
    func startSteamLink() async throws -> URL
    func updateGameStatus(identifier: LibraryGameIdentifier, status: UserGameStatus) async throws -> LibraryGameStatusMutationResult
}
