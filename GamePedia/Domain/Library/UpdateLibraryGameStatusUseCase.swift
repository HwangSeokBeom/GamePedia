import Foundation

// Direct-path mutation use case; see `ToggleFavoriteUseCase` for the
// guest/kill-switch authorization contract.
struct UpdateLibraryGameStatusUseCase {
    let libraryRepository: any LibraryRepository

    func execute(
        request: LibraryGameStatusUpdateRequest,
        authorization: RequestAuthorization = .guestOnly
    ) async throws -> LibraryGameStatusMutationResult {
        try await libraryRepository.updateGameStatus(request: request, authorization: authorization)
    }
}
