import Foundation

protocol LibraryRepository {
    func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverview
    func fetchOwnedLibrary() async throws -> OwnedLibraryCollection
    func fetchPlaytimeRecommendations() async throws -> [PlaytimeRecommendation]
    func fetchSteamFriendRecommendations() async throws -> [SteamFriendRecommendation]
    func fetchSteamLinkStatus() async throws -> SteamLinkStatus
    func startSteamLink() async throws -> URL
    func unlinkSteamAccount() async throws -> SteamUnlinkResult
    func syncOwnedSteamLibrary() async throws -> SteamOwnedLibrarySyncResult
    func updateGameStatus(request: LibraryGameStatusUpdateRequest) async throws -> LibraryGameStatusMutationResult
}
