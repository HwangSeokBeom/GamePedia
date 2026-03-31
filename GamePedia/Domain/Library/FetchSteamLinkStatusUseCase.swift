import Foundation

struct FetchSteamLinkStatusUseCase {
    let libraryRepository: LibraryRepository

    func execute() async throws -> SteamLinkStatus {
        try await libraryRepository.fetchSteamLinkStatus()
    }
}
