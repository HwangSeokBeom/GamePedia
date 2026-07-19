import Foundation

protocol LibraryRepository {
    func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverview
    func fetchOwnedLibrary() async throws -> OwnedLibraryCollection
    func fetchPlayingLibrary() async throws -> [LibraryGameSummary]
    func fetchRecentlyPlayedLibrary() async throws -> [LibraryGameSummary]
    func fetchPlaytimeRecommendations() async throws -> [PlaytimeRecommendation]
    func fetchInAppFriendRecommendations() async throws -> [SteamFriendRecommendation]
    func fetchSteamFriendRecommendations() async throws -> [SteamFriendRecommendation]
    func fetchSteamLinkStatus() async throws -> SteamLinkStatus
    func startSteamLink() async throws -> URL
    func unlinkSteamAccount() async throws -> SteamUnlinkResult
    func syncOwnedSteamLibrary() async throws -> SteamOwnedLibrarySyncResult
    /// Status mutations carry an explicit authorization mode so account
    /// ownership and credential selection bind atomically at the network
    /// boundary — see `FavoriteRepository` for the mode contract.
    func updateGameStatus(
        request: LibraryGameStatusUpdateRequest,
        authorization: RequestAuthorization
    ) async throws -> LibraryGameStatusMutationResult
}
