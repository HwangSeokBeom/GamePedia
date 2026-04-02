import Foundation

struct FetchOwnedLibraryUseCase {
    let libraryRepository: any LibraryRepository

    func execute() async throws -> OwnedLibraryCollection {
        try await libraryRepository.fetchOwnedLibrary()
    }
}
