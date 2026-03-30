import Foundation

protocol LibraryRepository {
    func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverview
    func startSteamLink() async throws -> URL
    func updateGameStatus(request: LibraryGameStatusUpdateRequest) async throws -> LibraryGameStatusMutationResult
}
