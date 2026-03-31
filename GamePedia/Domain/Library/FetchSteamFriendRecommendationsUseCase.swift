import Foundation

struct FetchSteamFriendRecommendationsUseCase {
    let libraryRepository: any LibraryRepository

    func execute() async throws -> [SteamFriendRecommendation] {
        try await libraryRepository.fetchSteamFriendRecommendations()
    }
}
