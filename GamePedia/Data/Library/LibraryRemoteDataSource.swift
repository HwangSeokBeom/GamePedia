import Foundation

protocol LibraryRemoteDataSource {
    func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverviewResponseDataDTO
    func fetchOwnedLibrary() async throws -> LibraryOverviewResponseDataDTO
    func fetchPlayingLibrary() async throws -> LibraryOverviewResponseDataDTO
    func fetchRecentlyPlayedLibrary() async throws -> LibraryOverviewResponseDataDTO
    func fetchPlaytimeRecommendations() async throws -> PlaytimeRecommendationsResponseDataDTO
    func fetchInAppFriendRecommendations() async throws -> LibraryFriendRecommendationsResponseDataDTO
    func fetchSteamFriendRecommendations() async throws -> SteamFriendRecommendationsResponseDataDTO
    func fetchSteamLinkStatus() async throws -> SteamLinkStatusDTO
    func startSteamLink() async throws -> SteamLinkStartResponseDataDTO
    func unlinkSteamAccount() async throws -> SteamUnlinkResponseDataDTO
    func syncOwnedSteamLibrary() async throws -> SyncOwnedSteamLibraryResponseDataDTO
    func updateGameStatus(requestDTO: UpdateLibraryStatusRequestDTO) async throws -> LibraryStatusMutationResponseDataDTO
}

final class DefaultLibraryRemoteDataSource: LibraryRemoteDataSource {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverviewResponseDataDTO {
        print("[Library] request endpoint=GET /users/me/library sort=\(sort?.rawValue ?? "nil")")
        let response = try await apiClient.request(
            .myLibrary(sort: sort?.rawValue),
            as: LibraryResponseEnvelopeDTO<LibraryOverviewResponseDataDTO>.self
        )
        let data = response.data
        let likedCount = data.liked?.count ?? data.wishlist?.count ?? 0
        let reviewItems = data.reviews ?? data.reviewed ?? []
        let reviewsCount = reviewItems.count
        let reviewRatings = reviewItems.compactMap(\.rating).filter(\.isFinite)
        let reviewAverageRating = reviewRatings.isEmpty
            ? nil
            : reviewRatings.reduce(0, +) / Double(reviewRatings.count)
        let steamConnectedText = data.steamConnected.map { String($0) } ?? "nil"
        let steamSyncAvailableText = data.steamSyncAvailable.map { String($0) } ?? "nil"
        let playingSummaryGameCountText = data.playingSummary?.gameCount.map { String($0) } ?? "nil"
        let playingSummaryTotalPlaytimeHoursText = data.playingSummary?.totalPlaytimeHours.map { String($0) } ?? "nil"
        let playingSummaryTotalPlaytimeMinutesText = data.playingSummary?.totalPlaytimeMinutes.map { String($0) } ?? "nil"
        let playingSummaryGameCountFieldText = data.playingSummary?.gameCountSourceField ?? "nil"
        let playingSummaryTotalPlaytimeHoursFieldText = data.playingSummary?.totalPlaytimeHoursSourceField ?? "nil"
        let reviewAverageRatingText = reviewAverageRating.map { String(format: "%.2f", $0) } ?? "nil"
        print(
            "[Library] response endpoint=GET /users/me/library " +
            "selectedTab=playing " +
            "steamConnected=\(steamConnectedText) " +
            "steamSyncStatus=\(data.steamSyncStatus ?? "nil") " +
            "steamSyncAvailable=\(steamSyncAvailableText) " +
            "playingSummary.gameCount=\(playingSummaryGameCountText) " +
            "playingSummary.totalPlaytimeHours=\(playingSummaryTotalPlaytimeHoursText) " +
            "playingSummary.totalPlaytimeMinutes=\(playingSummaryTotalPlaytimeMinutesText) " +
            "playingSummary.gameCountField=\(playingSummaryGameCountFieldText) " +
            "playingSummary.totalPlaytimeHoursField=\(playingSummaryTotalPlaytimeHoursFieldText) " +
            "recentlyPlayedCount=\(data.recentlyPlayed?.count ?? 0) " +
            "playingCount=\(data.playing?.count ?? 0) " +
            "likedCount=\(likedCount) " +
            "reviewsCount=\(reviewsCount) " +
            "reviewAverageRating=\(reviewAverageRatingText)"
        )
        logRecentPlayDecode(screen: "Library.overview", items: data.recentlyPlayed ?? [])
        return data
    }

    func fetchOwnedLibrary() async throws -> LibraryOverviewResponseDataDTO {
        print("[Library] request endpoint=GET /users/me/library/owned")
        let response = try await apiClient.request(
            .myOwnedLibrary,
            as: LibraryResponseEnvelopeDTO<LibraryOverviewResponseDataDTO>.self
        )
        print(
            "[Library] response endpoint=GET /users/me/library/owned " +
            "steamConnected=\(response.data.steamConnected.map(String.init) ?? "nil") " +
            "ownedCount=\(response.data.owned?.count ?? 0) " +
            "backlogCount=\(response.data.backlog?.count ?? 0)"
        )
        return response.data
    }

    func fetchPlayingLibrary() async throws -> LibraryOverviewResponseDataDTO {
        print("[Library] request endpoint=GET /users/me/library/playing")
        let response = try await apiClient.request(
            .myPlayingLibrary,
            as: LibraryResponseEnvelopeDTO<LibraryOverviewResponseDataDTO>.self
        )
        print(
            "[Library] response endpoint=GET /users/me/library/playing " +
            "playingCount=\(response.data.playing?.count ?? 0)"
        )
        return response.data
    }

    func fetchRecentlyPlayedLibrary() async throws -> LibraryOverviewResponseDataDTO {
        print("[Library] request endpoint=GET /users/me/library/recently-played")
        let response = try await apiClient.request(
            .myRecentlyPlayedLibrary,
            as: LibraryResponseEnvelopeDTO<LibraryOverviewResponseDataDTO>.self
        )
        print(
            "[Library] response endpoint=GET /users/me/library/recently-played " +
            "steamConnected=\(response.data.steamConnected.map(String.init) ?? "nil") " +
            "steamSyncStatus=\(response.data.steamSyncStatus ?? "nil") " +
            "recentlyPlayedCount=\(response.data.recentlyPlayed?.count ?? 0)"
        )
        logRecentPlayDecode(screen: "Library.recentlyPlayedEndpoint", items: response.data.recentlyPlayed ?? [])
        return response.data
    }

    func fetchPlaytimeRecommendations() async throws -> PlaytimeRecommendationsResponseDataDTO {
        print("[Library] request endpoint=GET /users/me/recommendations/playtime-based")
        let response = try await apiClient.request(
            .myPlaytimeRecommendations,
            as: LibraryResponseEnvelopeDTO<PlaytimeRecommendationsResponseDataDTO>.self
        )
        print(
            "[Library] response endpoint=GET /users/me/recommendations/playtime-based " +
            "recommendationCount=\(response.data.recommendations?.count ?? 0)"
        )
        return response.data
    }

    func fetchInAppFriendRecommendations() async throws -> LibraryFriendRecommendationsResponseDataDTO {
        print("[Library] request endpoint=GET /users/me/recommendations/friends")
        let response = try await apiClient.request(
            .myInAppFriendRecommendations,
            as: LibraryResponseEnvelopeDTO<LibraryFriendRecommendationsResponseDataDTO>.self
        )
        print(
            "[Library] response endpoint=GET /users/me/recommendations/friends " +
            "recommendationCount=\(response.data.recommendations?.count ?? 0)"
        )
        return response.data
    }

    func fetchSteamFriendRecommendations() async throws -> SteamFriendRecommendationsResponseDataDTO {
        print("[Library] request endpoint=GET /users/me/recommendations/steam-friends")
        let response = try await apiClient.request(
            .mySteamFriendRecommendations,
            as: LibraryResponseEnvelopeDTO<SteamFriendRecommendationsResponseDataDTO>.self
        )
        print(
            "[Library] response endpoint=GET /users/me/recommendations/steam-friends " +
            "recommendationCount=\(response.data.recommendations?.count ?? 0)"
        )
        return response.data
    }

    func fetchSteamLinkStatus() async throws -> SteamLinkStatusDTO {
        print("[SteamLink] request endpoint=GET /users/me/steam")
        let response = try await apiClient.request(
            .mySteamLinkStatus,
            as: LibraryResponseEnvelopeDTO<SteamLinkStatusDTO>.self
        )
        print(
            "[SteamLink] response endpoint=GET /users/me/steam " +
            "isLinked=\(response.data.isLinked) " +
            "steamId=\(response.data.steamId ?? "nil")"
        )
        return response.data
    }

    func startSteamLink() async throws -> SteamLinkStartResponseDataDTO {
        print("[SteamLink] request endpoint=POST /users/me/library/steam/link")
        let response = try await apiClient.request(
            .startSteamLink,
            as: LibraryResponseEnvelopeDTO<SteamLinkStartResponseDataDTO>.self
        )
        print("[SteamLink] response authUrl=\(response.data.steamLink.authUrl ?? "nil")")
        return response.data
    }

    func unlinkSteamAccount() async throws -> SteamUnlinkResponseDataDTO {
        print("[SteamLink] request endpoint=DELETE /users/me/library/steam/link")
        let response = try await apiClient.request(
            .unlinkSteamLink,
            as: LibraryResponseEnvelopeDTO<SteamUnlinkResponseDataDTO>.self
        )
        let isLinkedDescription = response.data.steamLinkStatus?.isLinked.description ?? "nil"
        print(
            "[SteamLink] response endpoint=DELETE /users/me/library/steam/link " +
            "unlinked=\(response.data.unlinked) " +
            "isLinked=\(isLinkedDescription)"
        )
        return response.data
    }

    func syncOwnedSteamLibrary() async throws -> SyncOwnedSteamLibraryResponseDataDTO {
        print("[Library] request endpoint=POST /users/me/library/steam/sync-owned")
        let response = try await apiClient.request(
            .syncOwnedSteamLibrary,
            as: LibraryResponseEnvelopeDTO<SyncOwnedSteamLibraryResponseDataDTO>.self
        )
        print(
            "[Library] response endpoint=POST /users/me/library/steam/sync-owned " +
            "syncedCount=\(response.data.syncedCount) " +
            "insertedCount=\(response.data.insertedCount) " +
            "updatedCount=\(response.data.updatedCount) " +
            "syncWarningCode=\(response.data.syncWarningCode ?? "nil") " +
            "igdbEnrichmentApplied=\(response.data.igdbEnrichmentApplied.map(String.init) ?? "nil") " +
            "igdbEnrichmentSkippedReason=\(response.data.igdbEnrichmentSkippedReason ?? "nil")"
        )
        return response.data
    }

    func updateGameStatus(requestDTO: UpdateLibraryStatusRequestDTO) async throws -> LibraryStatusMutationResponseDataDTO {
        print(
            "[Library] request endpoint=POST /users/me/library/status " +
            "externalGameId=\(requestDTO.externalGameId) " +
            "title=\(requestDTO.title) " +
            "gameSource=\(requestDTO.gameSource.uppercased()) " +
            "status=\(requestDTO.status)"
        )
        let response = try await apiClient.request(
            .updateLibraryStatus(body: requestDTO),
            as: LibraryResponseEnvelopeDTO<LibraryStatusMutationResponseEnvelopeDataDTO>.self
        )
        print(
            "[Library] response endpoint=POST /users/me/library/status " +
            "externalGameId=\(response.data.libraryEntry.externalGameId ?? "nil") " +
            "status=\(response.data.libraryEntry.status)"
        )
        return response.data.libraryEntry
    }

    private func logRecentPlayDecode(screen: String, items: [LibraryGameItemDTO]) {
        items.forEach { item in
            let title = item.originalTitle ?? item.originalName ?? item.gameName ?? item.title ?? item.name ?? "이름 없는 게임"
            print(
                "[RecentPlayDecode] " +
                "screen=\(screen) " +
                "title=\(title) " +
                "recentPlaytimeMinutes=\(item.recentPlaytimeMinutes.map(String.init) ?? "nil") " +
                "lastPlayedAt=\(item.lastPlayedAt ?? "nil") " +
                "hasReliableLastPlayedAt=\(item.hasReliableLastPlayedAt.map(String.init) ?? "nil") " +
                "lastPlayedAtSource=\(item.lastPlayedAtSource ?? "nil") " +
                "fallbackReason=\(item.fallbackReason ?? "nil")"
            )
        }
    }
}
