import Foundation

protocol LibraryRepository {
    func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverview
    func fetchOwnedLibrary() async throws -> OwnedLibraryCollection
    func startSteamLink() async throws -> URL
    func unlinkSteamAccount() async throws -> SteamUnlinkResult
    func syncOwnedSteamLibrary() async throws -> SteamOwnedLibrarySyncResult
    func updateGameStatus(request: LibraryGameStatusUpdateRequest) async throws -> LibraryGameStatusMutationResult
}
