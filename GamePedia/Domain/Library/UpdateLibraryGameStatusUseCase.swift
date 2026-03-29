import Foundation

struct UpdateLibraryGameStatusUseCase {
    let libraryRepository: any LibraryRepository

    func execute(identifier: LibraryGameIdentifier, status: UserGameStatus) async throws -> LibraryGameStatusMutationResult {
        try await libraryRepository.updateGameStatus(identifier: identifier, status: status)
    }
}
