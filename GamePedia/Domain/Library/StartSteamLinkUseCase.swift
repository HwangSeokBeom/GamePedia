import Foundation

struct StartSteamLinkUseCase {
    let libraryRepository: any LibraryRepository

    func execute() async throws -> URL {
        try await libraryRepository.startSteamLink()
    }
}
