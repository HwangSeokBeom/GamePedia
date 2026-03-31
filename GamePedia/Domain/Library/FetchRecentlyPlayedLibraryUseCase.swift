import Foundation

struct FetchRecentlyPlayedLibraryUseCase {
    let libraryRepository: any LibraryRepository

    func execute() async throws -> [LibraryGameSummary] {
        try await libraryRepository.fetchRecentlyPlayedLibrary()
    }
}
