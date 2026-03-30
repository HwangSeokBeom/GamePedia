import Foundation

final class DefaultLibraryRepository: LibraryRepository {
    private let libraryRemoteDataSource: any LibraryRemoteDataSource

    init(libraryRemoteDataSource: any LibraryRemoteDataSource = DefaultLibraryRemoteDataSource()) {
        self.libraryRemoteDataSource = libraryRemoteDataSource
    }

    func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverview {
        do {
            let data = try await libraryRemoteDataSource.fetchLibraryOverview(sort: sort)
            let steamLinkStatus = try await resolveSteamLinkStatus(from: data.steamLinkStatus)
            let recentlyPlayed = try (data.recentlyPlayed ?? []).map(LibraryMapper.toGameSummary)
            let playing = try (data.playing ?? []).map(LibraryMapper.toGameSummary)

            return LibraryOverview(
                steamLinkStatus: steamLinkStatus,
                recentlyPlayed: recentlyPlayed,
                playing: playing
            )
        } catch {
            throw LibraryError.from(error: error)
        }
    }

    func startSteamLink() async throws -> URL {
        do {
            let data = try await libraryRemoteDataSource.startSteamLink()
            return try LibraryMapper.toSteamLinkURL(data)
        } catch {
            throw LibraryError.from(error: error)
        }
    }

    func updateGameStatus(identifier: LibraryGameIdentifier, status: UserGameStatus) async throws -> LibraryGameStatusMutationResult {
        do {
            let data = try await libraryRemoteDataSource.updateGameStatus(
                requestDTO: UpdateLibraryStatusRequestDTO(
                    source: identifier.source.rawValue,
                    sourceId: identifier.sourceID,
                    status: status.rawValue
                )
            )
            return try LibraryMapper.toStatusMutationResult(data)
        } catch {
            throw LibraryError.from(error: error)
        }
    }

    private func resolveSteamLinkStatus(from dto: SteamLinkStatusDTO?) async throws -> SteamLinkStatus {
        if let dto {
            return LibraryMapper.toSteamLinkStatus(dto)
        }

        do {
            let steamLinkStatusDTO = try await libraryRemoteDataSource.fetchSteamLinkStatus()
            return LibraryMapper.toSteamLinkStatus(steamLinkStatusDTO)
        } catch let networkError as NetworkError {
            switch networkError {
            case .serverError(let statusCode, _, _):
                if statusCode == 404 {
                    return .notLinked
                }
            default:
                break
            }
            throw networkError
        } catch {
            throw error
        }
    }
}
