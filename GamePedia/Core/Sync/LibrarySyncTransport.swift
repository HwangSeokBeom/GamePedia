import Foundation

// MARK: - Library sync transport
//
// The single boundary through which queued operations reach the network.
// Production replays operations through the existing repositories (and thus
// the existing endpoints, DTO mapping, and error-code mapping) — the sync
// layer invents no new remote contract. Tests substitute deterministic
// fakes at this protocol.

protocol LibrarySyncTransporting: Sendable {
    /// Performs one operation against the server. Called at most once
    /// concurrently per entity key. Throws typed repository errors
    /// (`FavoriteError`, `LibraryError`) or `LibrarySyncFailure`.
    func perform(_ operation: LibrarySyncOperation) async throws -> LibrarySyncOutcome
}

// @unchecked: the repository protocols predate Sendable annotations; the
// default implementations are stateless request builders over the shared
// APIClient and are safe to call from the engine's executor.
struct RESTLibrarySyncTransport: LibrarySyncTransporting, @unchecked Sendable {
    let favoriteRepository: FavoriteRepository
    let libraryRepository: LibraryRepository

    init(
        favoriteRepository: FavoriteRepository = DefaultFavoriteRepository(),
        libraryRepository: LibraryRepository = DefaultLibraryRepository()
    ) {
        self.favoriteRepository = favoriteRepository
        self.libraryRepository = libraryRepository
    }

    func perform(_ operation: LibrarySyncOperation) async throws -> LibrarySyncOutcome {
        switch operation.kind {
        case .setFavorite(let gameID, let isFavorite):
            if isFavorite {
                return .favorite(try await favoriteRepository.addFavorite(gameId: gameID))
            } else {
                return .favorite(try await favoriteRepository.removeFavorite(gameId: gameID))
            }
        case .setLibraryStatus(let payload):
            return .libraryStatus(
                try await libraryRepository.updateGameStatus(request: payload.domainRequest)
            )
        }
    }
}
