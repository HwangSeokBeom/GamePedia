import Foundation

final class DefaultLibraryRepository: LibraryRepository {
    private let libraryRemoteDataSource: any LibraryRemoteDataSource

    init(libraryRemoteDataSource: any LibraryRemoteDataSource = DefaultLibraryRemoteDataSource()) {
        self.libraryRemoteDataSource = libraryRemoteDataSource
    }

    func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverview {
        do {
            let data = try await libraryRemoteDataSource.fetchLibraryOverview(sort: sort)
            print(
                "[Library] mapping overview " +
                "selectedTab=playing " +
                "steamConnected=\(data.steamConnected.map { String($0) } ?? "nil") " +
                "steamSyncStatus=\(data.steamSyncStatus ?? "nil") " +
                "steamSyncAvailable=\(data.steamSyncAvailable.map { String($0) } ?? "nil") " +
                "playingSummary.gameCount=\(data.playingSummary?.gameCount.map { String($0) } ?? "nil") " +
                "playingSummary.totalPlaytimeHours=\(data.playingSummary?.totalPlaytimeHours.map { String($0) } ?? "nil") " +
                "playingSummary.totalPlaytimeMinutes=\(data.playingSummary?.totalPlaytimeMinutes.map { String($0) } ?? "nil") " +
                "playingSummary.gameCountField=\(data.playingSummary?.gameCountSourceField ?? "nil") " +
                "playingSummary.totalPlaytimeHoursField=\(data.playingSummary?.totalPlaytimeHoursSourceField ?? "nil") " +
                "recentlyPlayedCount=\(data.recentlyPlayed?.count ?? 0) " +
                "playingCount=\(data.playing?.count ?? 0) " +
                "ownedCount=\(data.owned?.count ?? 0) " +
                "backlogCount=\(data.backlog?.count ?? 0)"
            )
            let steamLinkStatus = try await resolveSteamLinkStatus(
                from: data.steamLinkStatus,
                isConnected: data.steamConnected
            )
            let recentlyPlayed = try (data.recentlyPlayed ?? []).map(LibraryMapper.toGameSummary)
            let playing = try (data.playing ?? []).map(LibraryMapper.toGameSummary)
            let owned = try (data.owned ?? []).map(LibraryMapper.toGameSummary)
            let backlog = try (data.backlog ?? []).map(LibraryMapper.toGameSummary)

            let overview = LibraryOverview(
                steamLinkStatus: steamLinkStatus,
                steamSyncStatus: resolvedSteamSyncStatus(from: data.steamSyncStatus),
                isSteamSyncAvailable: data.steamSyncAvailable ?? true,
                steamSyncErrorCode: sanitized(data.steamSyncErrorCode),
                recentlyPlayed: recentlyPlayed,
                playing: playing,
                owned: owned,
                backlog: backlog,
                playingSummary: mapServerSummary(data.playingSummary),
                favoritesSummary: mapServerSummary(data.favoritesSummary),
                reviewedSummary: mapServerSummary(data.reviewedSummary)
            )
            print(
                "[Library] mapped overview " +
                "selectedTab=playing " +
                "playingSummary.gameCount=\(overview.playingSummary?.gameCount.map { String($0) } ?? "nil") " +
                "playingSummary.totalPlaytimeHours=\(overview.playingSummary?.totalPlaytimeHours.map { String($0) } ?? "nil") " +
                "playingSummary.gameCountField=\(overview.playingSummary?.gameCountSourceField ?? "nil") " +
                "playingSummary.totalPlaytimeHoursField=\(overview.playingSummary?.totalPlaytimeHoursSourceField ?? "nil") " +
                "recentlyPlayedCount=\(overview.recentlyPlayed.count) " +
                "playingCount=\(overview.playing.count) " +
                "ownedCount=\(overview.owned.count) " +
                "backlogCount=\(overview.backlog.count) " +
                "isSteamConnected=\(overview.steamLinkStatus.isLinked) " +
                "steamSyncStatus=\(overview.steamSyncStatus.rawValue) " +
                "isSteamSyncAvailable=\(overview.isSteamSyncAvailable)"
            )
            return overview
        } catch {
            print("[Library] mapping overview failed error=\(error.localizedDescription)")
            throw LibraryError.from(error: error)
        }
    }

    func fetchOwnedLibrary() async throws -> OwnedLibraryCollection {
        do {
            let data = try await libraryRemoteDataSource.fetchOwnedLibrary()
            let owned = try (data.owned ?? []).map(LibraryMapper.toGameSummary)
            let backlog = try (data.backlog ?? []).map(LibraryMapper.toGameSummary)
            return OwnedLibraryCollection(owned: owned, backlog: backlog)
        } catch {
            throw LibraryError.from(error: error)
        }
    }

    func fetchPlayingLibrary() async throws -> [LibraryGameSummary] {
        do {
            let data = try await libraryRemoteDataSource.fetchPlayingLibrary()
            return try (data.playing ?? []).map(LibraryMapper.toGameSummary)
        } catch {
            throw LibraryError.from(error: error)
        }
    }

    func fetchRecentlyPlayedLibrary() async throws -> [LibraryGameSummary] {
        do {
            let data = try await libraryRemoteDataSource.fetchRecentlyPlayedLibrary()
            return try (data.recentlyPlayed ?? []).map(LibraryMapper.toGameSummary)
        } catch {
            throw LibraryError.from(error: error)
        }
    }

    func fetchPlaytimeRecommendations() async throws -> [PlaytimeRecommendation] {
        do {
            let data = try await libraryRemoteDataSource.fetchPlaytimeRecommendations()
            let recommendations = try (data.recommendations ?? []).map { dto in
                PlaytimeRecommendation(
                    game: try LibraryMapper.toGameSummary(dto),
                    reason: sanitized(dto.reason)
                )
            }
            return recommendations
        } catch {
            throw LibraryError.from(error: error)
        }
    }

    func fetchInAppFriendRecommendations() async throws -> [SteamFriendRecommendation] {
        do {
            let data = try await libraryRemoteDataSource.fetchInAppFriendRecommendations()
            return try mapFriendRecommendations(from: data)
        } catch {
            throw LibraryError.from(error: error)
        }
    }

    func fetchSteamFriendRecommendations() async throws -> [SteamFriendRecommendation] {
        do {
            let data = try await libraryRemoteDataSource.fetchSteamFriendRecommendations()
            return try mapFriendRecommendations(from: data)
        } catch {
            throw LibraryError.from(error: error)
        }
    }

    func fetchSteamLinkStatus() async throws -> SteamLinkStatus {
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
            throw LibraryError.from(error: networkError)
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

    func unlinkSteamAccount() async throws -> SteamUnlinkResult {
        do {
            let data = try await libraryRemoteDataSource.unlinkSteamAccount()
            let steamLinkStatus = data.steamLinkStatus.map(LibraryMapper.toSteamLinkStatus) ?? .notLinked
            return SteamUnlinkResult(
                isUnlinked: data.unlinked,
                steamLinkStatus: steamLinkStatus
            )
        } catch {
            throw LibraryError.from(error: error)
        }
    }

    func syncOwnedSteamLibrary() async throws -> SteamOwnedLibrarySyncResult {
        do {
            let data = try await libraryRemoteDataSource.syncOwnedSteamLibrary()
            return SteamOwnedLibrarySyncResult(
                syncedCount: data.syncedCount,
                insertedCount: data.insertedCount,
                updatedCount: data.updatedCount,
                syncWarningCode: sanitized(data.syncWarningCode),
                igdbEnrichmentApplied: data.igdbEnrichmentApplied,
                igdbEnrichmentSkippedReason: sanitized(data.igdbEnrichmentSkippedReason)
            )
        } catch {
            throw LibraryError.from(error: error)
        }
    }

    func updateGameStatus(request: LibraryGameStatusUpdateRequest) async throws -> LibraryGameStatusMutationResult {
        do {
            let data = try await libraryRemoteDataSource.updateGameStatus(
                requestDTO: UpdateLibraryStatusRequestDTO(
                    gameSource: request.gameSource.rawValue,
                    externalGameId: request.externalGameId,
                    title: request.title,
                    coverUrl: request.coverImageURL?.absoluteString,
                    status: request.status.rawValue
                )
            )
            return try LibraryMapper.toStatusMutationResult(data)
        } catch {
            throw LibraryError.from(error: error)
        }
    }

    private func resolveSteamLinkStatus(from dto: SteamLinkStatusDTO?, isConnected: Bool?) async throws -> SteamLinkStatus {
        if let dto {
            return LibraryMapper.toSteamLinkStatus(dto)
        }

        if let isConnected {
            return SteamLinkStatus(
                connectionState: isConnected ? .linked : .notLinked,
                steamID: nil,
                displayName: nil,
                personaName: nil,
                profileURL: nil,
                canSync: isConnected,
                canDisconnect: isConnected,
                lastSteamSyncAt: nil
            )
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

    private func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func mapFriendRecommendations(
        from data: LibraryFriendRecommendationsResponseDataDTO
    ) throws -> [SteamFriendRecommendation] {
        try (data.recommendations ?? []).map { dto in
            SteamFriendRecommendation(
                game: try LibraryMapper.toGameSummary(dto),
                friendCount: max(dto.friendCount ?? 0, 0),
                reason: sanitized(dto.reason)
            )
        }
    }

    private func mapServerSummary(_ dto: LibraryTabSummaryDTO?) -> LibraryServerSummary? {
        guard let dto else { return nil }
        return LibraryServerSummary(
            totalPlaytimeHours: dto.totalPlaytimeHours,
            gameCount: dto.gameCount,
            averageRating: dto.averageRating,
            reviewCount: dto.reviewCount,
            totalPlaytimeHoursSourceField: dto.totalPlaytimeHoursSourceField,
            gameCountSourceField: dto.gameCountSourceField
        )
    }

    private func resolvedSteamSyncStatus(from rawValue: String?) -> SteamSyncStatus {
        guard let rawValue = sanitized(rawValue)?.lowercased() else {
            return .idle
        }

        return SteamSyncStatus(rawValue: rawValue) ?? .unknown
    }
}
