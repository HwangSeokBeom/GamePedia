import Foundation

protocol LibraryRepository {
    func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverview
    func startSteamLink() async throws -> URL
    func syncOwnedSteamLibrary() async throws -> SteamOwnedLibrarySyncResult
    func updateGameStatus(request: LibraryGameStatusUpdateRequest) async throws -> LibraryGameStatusMutationResult
}
