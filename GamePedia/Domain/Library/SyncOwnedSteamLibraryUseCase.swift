import Foundation

struct SyncOwnedSteamLibraryUseCase {
    let libraryRepository: any LibraryRepository

    func execute() async throws -> SteamOwnedLibrarySyncResult {
        try await libraryRepository.syncOwnedSteamLibrary()
    }
}
