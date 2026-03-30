import Foundation

struct UpdateLibraryGameStatusUseCase {
    let libraryRepository: any LibraryRepository

    func execute(request: LibraryGameStatusUpdateRequest) async throws -> LibraryGameStatusMutationResult {
        try await libraryRepository.updateGameStatus(request: request)
    }
}
