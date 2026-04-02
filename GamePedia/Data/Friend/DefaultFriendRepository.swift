import Foundation

final class DefaultFriendRepository: FriendRepository {
    private let remoteDataSource: any FriendRemoteDataSource

    init(remoteDataSource: any FriendRemoteDataSource = DefaultFriendRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func searchFriends(keyword: String) async throws -> [FriendUserSummary] {
        let data = try await remoteDataSource.searchFriends(keyword: keyword)
        return data.users.map(mapUser)
    }

    func fetchReceivedFriendRequests() async throws -> [FriendRequest] {
        let data = try await remoteDataSource.fetchFriendRequests(kind: .received)
        return data.requests.map { mapRequest($0, kind: .received) }
    }

    func fetchSentFriendRequests() async throws -> [FriendRequest] {
        let data = try await remoteDataSource.fetchFriendRequests(kind: .sent)
        return data.requests.map { mapRequest($0, kind: .sent) }
    }

    func sendFriendRequest(userID: String) async throws {
        try await remoteDataSource.sendFriendRequest(userID: userID)
    }

    func acceptFriendRequest(requestID: String) async throws {
        try await remoteDataSource.acceptFriendRequest(requestID: requestID)
    }

    func rejectFriendRequest(requestID: String) async throws {
        try await remoteDataSource.rejectFriendRequest(requestID: requestID)
    }

    func cancelFriendRequest(requestID: String) async throws {
        try await remoteDataSource.cancelFriendRequest(requestID: requestID)
    }

    func fetchFriends() async throws -> [FriendUserSummary] {
        let data = try await remoteDataSource.fetchFriends()
        return data.friends.map { mapUser($0.user) }
    }

    func fetchSteamFriends() async throws -> (friends: [SteamFriend], isAvailable: Bool, isLimitedByPrivacy: Bool, syncWarningCode: String?) {
        let data = try await remoteDataSource.fetchSteamFriends()
        return (
            friends: data.friends.map(mapSteamFriend),
            isAvailable: data.steamFriendsAvailable ?? false,
            isLimitedByPrivacy: data.steamFriendsLimitedByPrivacy ?? false,
            syncWarningCode: sanitized(data.syncWarningCode)
        )
    }

    func fetchFriendProfile(userID: String) async throws -> FriendProfile {
        let data = try await remoteDataSource.fetchFriendProfile(userID: userID)
        return FriendProfile(
            user: mapUser(data.user),
            tasteSimilarity: mapTasteSimilarity(data.tasteSimilarity),
            tasteProfile: mapTasteProfile(data.tasteProfile),
            sharedGames: (data.sharedGames ?? []).compactMap(mapSharedGame),
            commonLikedGames: (data.commonLikedGames ?? []).map { GameMapper.toEntity($0) },
            commonInterestGames: (data.commonInterestGames ?? []).map { GameMapper.toEntity($0) },
            commonHighlyRatedGames: (data.commonHighlyRatedGames ?? []).map { GameMapper.toEntity($0) },
            recentlyPlayed: (data.recentlyPlayed ?? []).map(UserProfileMapper.toRecentGameEntity),
            likedGames: (data.likedGames ?? []).map { GameMapper.toEntity($0) },
            writtenReviews: (data.writtenReviews ?? []).map { reviewDTO in
                FriendProfileReview(
                    id: reviewDTO.id,
                    gameID: Int(reviewDTO.gameId ?? ""),
                    gameTitle: sanitized(reviewDTO.gameTitle) ?? L10n.Friend.Fallback.game,
                    content: reviewDTO.content,
                    ratingText: reviewDTO.rating.map(LocalizedNumberFormatter.oneFraction),
                    createdAtText: reviewDTO.createdAt.toRelativeDateString()
                )
            },
            friendRecommendations: (data.friendRecommendations ?? []).map { recommendationDTO in
                FriendRecommendation(
                    game: GameMapper.toEntity(recommendationDTO.game),
                    reasonText: sanitized(recommendationDTO.reason) ?? L10n.Friend.Recommendation.similarFriendNoticed
                )
            },
            steamFriendsContext: mapSteamFriendsContext(data.steamFriendsContext)
        )
    }

    func fetchFriendActivityFeed(cursor: String?) async throws -> FriendActivityFeedPage {
        let data = try await remoteDataSource.fetchFriendActivityFeed(cursor: cursor)
        let items = data.activities.map { dto in
            FriendActivityItem(
                id: dto.id,
                actor: mapUser(dto.actor),
                type: resolvedActivityType(dto.activityType),
                game: mapFriendActivityGame(dto.game),
                createdAt: dto.createdAt,
                messageOverride: sanitized(dto.message),
                metadata: FriendActivityMetadata(
                    reviewID: sanitized(dto.reviewId),
                    previousRating: dto.previousRating,
                    updatedRating: dto.updatedRating,
                    previousPlayStatus: sanitized(dto.previousPlayStatus).flatMap(UserGameStatus.init(rawValue:)),
                    updatedPlayStatus: sanitized(dto.updatedPlayStatus).flatMap(UserGameStatus.init(rawValue:)),
                    note: sanitized(dto.message)
                )
            )
        }
        print("[FriendActivity] mappedCount=\(items.count) nextCursor=\(data.nextCursor ?? "nil")")
        return FriendActivityFeedPage(
            activities: items,
            nextCursor: sanitized(data.nextCursor)
        )
    }

    func fetchFriendRecommendations(userID: String) async throws -> [FriendRecommendation] {
        let data = try await remoteDataSource.fetchFriendRecommendations(userID: userID)
        return data.recommendations.map { recommendationDTO in
            FriendRecommendation(
                game: GameMapper.toEntity(recommendationDTO.game),
                reasonText: sanitized(recommendationDTO.reason) ?? L10n.Friend.Recommendation.similarFriendHighlyRated
            )
        }
    }

    func removeFriend(userID: String) async throws {
        try await remoteDataSource.removeFriend(userID: userID)
    }

    func blockUser(userID: String) async throws {
        try await remoteDataSource.blockUser(userID: userID)
    }

    func fetchSocialPrivacySettings() async throws -> SocialPrivacySettings {
        do {
            let data = try await remoteDataSource.fetchSocialPrivacySettings()
            return mapSocialPrivacySettings(data)
        } catch let error as NetworkError {
            if shouldFallbackToDefaultPrivacySettings(for: error) {
                print(
                    "[FriendPrivacy] defaultFallback " +
                    "status=\(privacyStatusCode(from: error) ?? -1) " +
                    "code=\(error.serverCode ?? "nil")"
                )
                return .default
            }
            throw error
        }
    }

    func updateSocialPrivacySettings(_ settings: SocialPrivacySettings) async throws -> SocialPrivacySettings {
        let payload = UpdateSocialPrivacySettingsRequestDTO(
            isFriendsListPublic: settings.isFriendsListPublic,
            isRecentPlayPublic: settings.isRecentPlayPublic,
            isLikedGamesPublic: settings.isLikedGamesPublic,
            isReviewsPublic: settings.isReviewsPublic
        )
        let data = try await remoteDataSource.updateSocialPrivacySettings(payload)
        return mapSocialPrivacySettings(data)
    }

    func importSteamFriends() async throws {
        try await remoteDataSource.importSteamFriends()
    }

    private func mapUser(_ dto: FriendUserDTO) -> FriendUserSummary {
        let relationshipStatus = resolvedRelationshipStatus(
            rawValue: dto.friendshipStatus,
            isMe: dto.isMe == true,
            canRequest: dto.canRequest,
            alreadyFriend: dto.alreadyFriend,
            pendingSent: dto.pendingSent,
            pendingReceived: dto.pendingReceived
        )
        return FriendUserSummary(
            id: dto.id,
            nickname: dto.nickname,
            bio: sanitized(dto.bio),
            profileImageURL: dto.profileImageUrl.flatMap(URL.init(string:)),
            relationshipStatus: relationshipStatus,
            recentPlayTitle: sanitized(dto.recentPlayTitle),
            presence: mapPresence(dto)
        )
    }

    private func mapRequest(_ dto: FriendRequestDTO, kind: FriendRequestListKind) -> FriendRequest {
        let fallbackUser = FriendUserDTO(
            id: "",
            nickname: L10n.Friend.Fallback.unknownUser,
            bio: nil,
            profileImageUrl: nil,
            friendshipStatus: nil,
            recentPlayTitle: nil,
            isMe: nil,
            canRequest: nil,
            alreadyFriend: nil,
            pendingSent: nil,
            pendingReceived: nil
        )
        let userDTO: FriendUserDTO
        switch kind {
        case .received:
            userDTO = dto.fromUser ?? dto.toUser ?? fallbackUser
        case .sent:
            userDTO = dto.toUser ?? dto.fromUser ?? fallbackUser
        }

        return FriendRequest(
            id: dto.id,
            user: mapUser(userDTO),
            createdAt: dto.createdAt
        )
    }

    private func resolvedRelationshipStatus(
        rawValue: String?,
        isMe: Bool,
        canRequest: Bool?,
        alreadyFriend: Bool?,
        pendingSent: Bool?,
        pendingReceived: Bool?
    ) -> FriendRelationshipStatus {
        if isMe { return .self }
        if alreadyFriend == true { return .friends }
        if pendingSent == true { return .outgoing }
        if pendingReceived == true { return .incoming }
        if canRequest == true { return .none }
        guard let normalized = sanitized(rawValue)?.lowercased() else { return .none }
        switch normalized {
        case "friends":
            return .friends
        case "outgoing", "requested", "pending_sent":
            return .outgoing
        case "incoming", "pending_received":
            return .incoming
        case "self":
            return .self
        default:
            return .none
        }
    }

    private func mapTasteSimilarity(_ dto: FriendTasteSimilarityDTO?) -> FriendTasteSimilarity? {
        guard let dto else { return nil }
        return FriendTasteSimilarity(
            percentage: dto.percentage,
            summaryText: sanitized(dto.summary) ?? L10n.Friend.Profile.tasteFallbackSummary
        )
    }

    private func mapTasteProfile(_ dto: FriendTasteProfileDTO?) -> FriendTasteProfile? {
        guard let dto else { return nil }
        let similarityScore = dto.similarityScore.map { Int(($0 * 100).rounded()) }
        return FriendTasteProfile(
            similarityScore: similarityScore,
            summaryText: sanitized(dto.summary) ?? L10n.Friend.Profile.tasteFallbackSummary,
            topGenres: uniqueLabels(dto.topGenres),
            topTags: uniqueLabels(dto.topTags)
        )
    }

    private func mapSharedGame(_ dto: SharedFriendGameDTO) -> SharedFriendGame? {
        let gameDTO: GameDTO?
        if let dtoGame = dto.game {
            gameDTO = dtoGame
        } else if let id = dto.id {
            gameDTO = GameDTO(
                id: id,
                name: dto.name,
                originalName: nil,
                summary: nil,
                originalSummary: nil,
                coverUrl: dto.coverUrl,
                genres: dto.genres,
                platforms: nil,
                rating: nil,
                aggregatedRating: nil,
                totalRating: nil,
                releaseDate: dto.releaseYear
            )
        } else {
            gameDTO = nil
        }

        guard let gameDTO else { return nil }
        return SharedFriendGame(
            game: GameMapper.toEntity(gameDTO),
            reasonText: sanitized(dto.sharedReason) ?? L10n.Friend.Recommendation.sharedRecentPlay
        )
    }

    private func mapSteamFriendsContext(_ dto: SteamFriendsContextDTO?) -> SteamFriendsContext? {
        guard let dto else { return nil }
        return SteamFriendsContext(
            isAvailable: dto.steamFriendsAvailable ?? false,
            isLimitedByPrivacy: dto.sharedGamesLimitedByPrivacy ?? false,
            isRecentPlayedAvailable: dto.recentPlayedAvailable ?? false
        )
    }

    private func mapSteamFriend(_ dto: SteamFriendDTO) -> SteamFriend {
        SteamFriend(
            steamId64: dto.steamId64,
            userId: sanitized(dto.userId),
            nickname: sanitized(dto.nickname),
            profileImageURL: sanitized(dto.profileImageUrl).flatMap(URL.init(string:)),
            personaName: sanitized(dto.personaName),
            avatarURL: sanitized(dto.avatarUrl).flatMap(URL.init(string:)),
            profileURL: sanitized(dto.profileUrl).flatMap(URL.init(string:)),
            isLinkedToGamePedia: dto.isLinkedToGamePedia ?? false
        )
    }

    private func mapPresence(_ dto: FriendUserDTO) -> UserPresence? {
        let normalizedStatus = sanitized(dto.presenceStatus)?.lowercased()
        let state: UserPresenceState

        switch normalizedStatus {
        case "online":
            state = .online
        case "playing":
            state = .playing
        case "recently_active", "recentlyactive", "recent":
            state = .recentlyActive
        case "last_played", "lastplayed":
            state = .lastPlayed
        case nil:
            if dto.currentGameTitle != nil {
                state = .playing
            } else if dto.lastActiveAt != nil {
                state = .recentlyActive
            } else if dto.lastPlayedAt != nil {
                state = .lastPlayed
            } else {
                state = .unknown
            }
        default:
            state = .unknown
        }

        guard state != .unknown || dto.currentGameTitle != nil || dto.lastActiveAt != nil || dto.lastPlayedAt != nil else {
            return nil
        }

        return UserPresence(
            state: state,
            gameTitle: sanitized(dto.currentGameTitle),
            lastActiveAt: dto.lastActiveAt,
            lastPlayedAt: dto.lastPlayedAt,
            isSteamSupplemented: dto.steamPresenceSupplemented == true
        )
    }

    private func resolvedActivityType(_ rawValue: String?) -> FriendActivityItem.ActivityType {
        let normalized = sanitized(rawValue)?.lowercased() ?? ""
        switch normalized {
        case "review_created", "created_review", "wrote_review":
            return .reviewCreated
        case "review_updated", "updated_review":
            return .reviewUpdated
        case "liked_game_added", "liked_added", "wishlisted", "liked_game":
            return .likedGameAdded
        case "liked_game_removed", "liked_removed", "unwishlisted":
            return .likedGameRemoved
        case "rating_changed", "rated_high", "high_rating", "ratedhigh", "high_rated_game":
            return .ratingChanged
        case "play_status_changed", "status_changed":
            return .playStatusChanged
        case "friend_started_playing", "started_playing", "startedplaying", "playing_started":
            return .friendStartedPlaying
        case "friend_recently_played", "recently_played", "played_game":
            return .friendRecentlyPlayed
        default:
            return .friendRecentlyPlayed
        }
    }

    private func mapFriendActivityGame(_ dto: FriendActivityGamePreviewDTO) -> Game {
        let title = sanitized(dto.title)
            ?? sanitized(dto.gameName)
            ?? L10n.tr("Localizable", "common.label.untitledGame")
        let identifier = Int(dto.igdbGameId ?? "") ?? Int(dto.externalGameId ?? "") ?? 0
        let isSteam = sanitized(dto.gameSource)?.lowercased() == "steam"
        return Game(
            id: identifier,
            title: title,
            translatedTitle: nil,
            summary: nil,
            translatedSummary: nil,
            genre: "—",
            category: "—",
            developer: "—",
            platform: isSteam ? "Steam" : "—",
            releaseDate: nil,
            releaseYear: 0,
            coverImageURL: sanitized(dto.coverUrl).flatMap(URL.init(string:)),
            rating: 0,
            reviewCount: 0,
            popularity: 0,
            isTrending: false,
            formattedRating: "—",
            formattedReviewCount: "—"
        )
    }

    private func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func uniqueLabels(_ values: [String]?) -> [String] {
        let sanitizedValues = (values ?? []).compactMap(sanitized)
        var seen = Set<String>()
        return sanitizedValues.filter { seen.insert($0).inserted }
    }

    private func mapSocialPrivacySettings(_ dto: SocialPrivacySettingsResponseDataDTO) -> SocialPrivacySettings {
        SocialPrivacySettings(
            isFriendsListPublic: dto.isFriendsListPublic ?? true,
            isRecentPlayPublic: dto.isRecentPlayPublic ?? true,
            isLikedGamesPublic: dto.isLikedGamesPublic ?? true,
            isReviewsPublic: dto.isReviewsPublic ?? true,
            isSteamFriendsFeatureAvailable: dto.steamFriendsFeatureAvailable ?? false
        )
    }

    private func shouldFallbackToDefaultPrivacySettings(for error: NetworkError) -> Bool {
        guard case .serverError(let statusCode, let code, let message) = error else { return false }
        if statusCode == 404 {
            return true
        }

        let normalizedCode = sanitized(code)?.uppercased() ?? ""
        let normalizedMessage = sanitized(message)?.lowercased() ?? ""
        return normalizedCode.contains("PRIVACY")
            && normalizedCode.contains("NOT_FOUND")
            || (normalizedMessage.contains("privacy") && normalizedMessage.contains("not found"))
    }

    private func privacyStatusCode(from error: NetworkError) -> Int? {
        guard case .serverError(let statusCode, _, _) = error else { return nil }
        return statusCode
    }
}
