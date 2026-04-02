import Foundation

struct FetchPlayingLibraryUseCase {
    let libraryRepository: any LibraryRepository

    func execute() async throws -> [LibraryGameSummary] {
        try await libraryRepository.fetchPlayingLibrary()
    }
}
