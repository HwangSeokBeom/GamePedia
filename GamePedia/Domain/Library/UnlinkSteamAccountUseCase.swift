import Foundation

struct UnlinkSteamAccountUseCase {
    let libraryRepository: any LibraryRepository

    func execute() async throws -> SteamUnlinkResult {
        try await libraryRepository.unlinkSteamAccount()
    }
}
