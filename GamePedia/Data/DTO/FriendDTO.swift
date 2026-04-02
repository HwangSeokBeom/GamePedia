import Foundation

struct FriendResponseEnvelopeDTO<DataDTO: Decodable>: Decodable {
    let success: Bool
    let data: DataDTO
}

struct FriendUserDTO: Decodable {
    let id: String
    let nickname: String
    let bio: String?
    let profileImageUrl: String?
    let friendshipStatus: String?
    let recentPlayTitle: String?
    let isMe: Bool?
    let canRequest: Bool?
    let alreadyFriend: Bool?
    let pendingSent: Bool?
    let pendingReceived: Bool?
    let presenceStatus: String?
    let currentGameTitle: String?
    let lastActiveAt: Date?
    let lastPlayedAt: Date?
    let steamPresenceSupplemented: Bool?

    init(
        id: String,
        nickname: String,
        bio: String?,
        profileImageUrl: String?,
        friendshipStatus: String?,
        recentPlayTitle: String?,
        isMe: Bool?,
        canRequest: Bool?,
        alreadyFriend: Bool?,
        pendingSent: Bool?,
        pendingReceived: Bool?,
        presenceStatus: String? = nil,
        currentGameTitle: String? = nil,
        lastActiveAt: Date? = nil,
        lastPlayedAt: Date? = nil,
        steamPresenceSupplemented: Bool? = nil
    ) {
        self.id = id
        self.nickname = nickname
        self.bio = bio
        self.profileImageUrl = profileImageUrl
        self.friendshipStatus = friendshipStatus
        self.recentPlayTitle = recentPlayTitle
        self.isMe = isMe
        self.canRequest = canRequest
        self.alreadyFriend = alreadyFriend
        self.pendingSent = pendingSent
        self.pendingReceived = pendingReceived
        self.presenceStatus = presenceStatus
        self.currentGameTitle = currentGameTitle
        self.lastActiveAt = lastActiveAt
        self.lastPlayedAt = lastPlayedAt
        self.steamPresenceSupplemented = steamPresenceSupplemented
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? ""
        nickname = (try? container.decode(String.self, forKey: .nickname)) ?? "알 수 없는 사용자"
        bio = try? container.decodeIfPresent(String.self, forKey: .bio)
        profileImageUrl = try? container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        friendshipStatus = try? container.decodeIfPresent(String.self, forKey: .friendshipStatus)
        recentPlayTitle = (try? container.decodeIfPresent(String.self, forKey: .recentPlayTitle))
            ?? (try? container.decodeIfPresent(String.self, forKey: .lastPlayedGameTitle))
        isMe = try? container.decodeIfPresent(Bool.self, forKey: .isMe)
        canRequest = try? container.decodeIfPresent(Bool.self, forKey: .canRequest)
        alreadyFriend = try? container.decodeIfPresent(Bool.self, forKey: .alreadyFriend)
        pendingSent = try? container.decodeIfPresent(Bool.self, forKey: .pendingSent)
        pendingReceived = try? container.decodeIfPresent(Bool.self, forKey: .pendingReceived)
        presenceStatus = (try? container.decodeIfPresent(String.self, forKey: .presenceStatus))
            ?? (try? container.decodeIfPresent(String.self, forKey: .presence))
            ?? (try? container.decodeIfPresent(String.self, forKey: .presence_state))
        currentGameTitle = (try? container.decodeIfPresent(String.self, forKey: .currentGameTitle))
            ?? (try? container.decodeIfPresent(String.self, forKey: .playingGameTitle))
            ?? (try? container.decodeIfPresent(String.self, forKey: .current_game_title))
        lastActiveAt = Self.decodeDateIfPresent(container, primary: .lastActiveAt, secondary: .last_active_at)
        lastPlayedAt = Self.decodeDateIfPresent(container, primary: .lastPlayedAt, secondary: .last_played_at)
        steamPresenceSupplemented = (try? container.decodeIfPresent(Bool.self, forKey: .steamPresenceSupplemented))
            ?? (try? container.decodeIfPresent(Bool.self, forKey: .steam_supplemented))
            ?? (try? container.decodeIfPresent(Bool.self, forKey: .isSteamPresence))
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case bio
        case profileImageUrl
        case friendshipStatus
        case recentPlayTitle
        case lastPlayedGameTitle
        case isMe
        case canRequest
        case alreadyFriend
        case pendingSent
        case pendingReceived
        case presenceStatus
        case presence
        case presence_state
        case currentGameTitle
        case playingGameTitle
        case current_game_title
        case lastActiveAt
        case last_active_at
        case lastPlayedAt
        case last_played_at
        case steamPresenceSupplemented
        case steam_supplemented
        case isSteamPresence
    }

    private static func decodeDateIfPresent(
        _ container: KeyedDecodingContainer<CodingKeys>,
        primary: CodingKeys,
        secondary: CodingKeys
    ) -> Date? {
        if let date = try? container.decodeIfPresent(Date.self, forKey: primary) {
            return date
        }
        if let dateString = try? container.decodeIfPresent(String.self, forKey: primary) {
            return FriendActivityDTO.parseDate(dateString)
        }
        if let date = try? container.decodeIfPresent(Date.self, forKey: secondary) {
            return date
        }
        if let dateString = try? container.decodeIfPresent(String.self, forKey: secondary) {
            return FriendActivityDTO.parseDate(dateString)
        }
        return nil
    }
}

struct FriendSearchResponseDataDTO: Decodable {
    let users: [FriendUserDTO]
}

struct FriendRequestsResponseDataDTO: Decodable {
    let requests: [FriendRequestDTO]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let requests = try container.decodeIfPresent([FriendRequestDTO].self, forKey: .requests) {
            self.requests = requests
            return
        }
        if let requests = try container.decodeIfPresent([FriendRequestDTO].self, forKey: .receivedRequests) {
            self.requests = requests
            return
        }
        if let requests = try container.decodeIfPresent([FriendRequestDTO].self, forKey: .sentRequests) {
            self.requests = requests
            return
        }
        if let requests = try container.decodeIfPresent([FriendRequestDTO].self, forKey: .friendRequests) {
            self.requests = requests
            return
        }

        if let singleValueContainer = try? decoder.singleValueContainer(),
           let requests = try? singleValueContainer.decode([FriendRequestDTO].self) {
            self.requests = requests
            return
        }

        self.requests = []
    }

    private enum CodingKeys: String, CodingKey {
        case requests
        case receivedRequests
        case sentRequests
        case friendRequests
    }
}

struct FriendRequestDTO: Decodable {
    let id: String
    let status: String?
    let fromUser: FriendUserDTO?
    let toUser: FriendUserDTO?
    let createdAt: Date?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id))
            ?? (try? container.decode(String.self, forKey: .requestId))
            ?? UUID().uuidString
        status = try? container.decode(String.self, forKey: .status)
        fromUser = (try? container.decode(FriendUserDTO.self, forKey: .fromUser))
            ?? (try? container.decode(FriendUserDTO.self, forKey: .user))
        toUser = try? container.decode(FriendUserDTO.self, forKey: .toUser)
        createdAt = try? container.decode(Date.self, forKey: .createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case requestId
        case user
        case status
        case fromUser
        case toUser
        case createdAt
    }
}

struct FriendsListResponseDataDTO: Decodable {
    let friends: [FriendshipDTO]
}

struct FriendshipDTO: Decodable {
    let friendSince: Date?
    let user: FriendUserDTO

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        friendSince = try? container.decode(Date.self, forKey: .friendSince)
        user = (try? container.decode(FriendUserDTO.self, forKey: .user))
            ?? (try? container.decode(FriendUserDTO.self, forKey: .friend))
            ?? (try? FriendUserDTO(from: decoder))
            ?? FriendUserDTO(
                id: "",
                nickname: "알 수 없는 사용자",
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
    }

    private enum CodingKeys: String, CodingKey {
        case friendSince
        case user
        case friend
    }
}

struct FriendProfileResponseDataDTO: Decodable {
    let user: FriendUserDTO
    let tasteSimilarity: FriendTasteSimilarityDTO?
    let tasteProfile: FriendTasteProfileDTO?
    let sharedGames: [SharedFriendGameDTO]?
    let commonLikedGames: [GameDTO]?
    let commonInterestGames: [GameDTO]?
    let commonHighlyRatedGames: [GameDTO]?
    let recentlyPlayed: [RecentGameDTO]?
    let likedGames: [GameDTO]?
    let writtenReviews: [FriendProfileReviewDTO]?
    let friendRecommendations: [FriendRecommendationDTO]?
    let steamFriendsContext: SteamFriendsContextDTO?
}

struct FriendProfileReviewDTO: Decodable {
    let id: String
    let gameId: String?
    let gameTitle: String?
    let rating: Double?
    let content: String
    let createdAt: String
}

struct FriendTasteSimilarityDTO: Decodable {
    let percentage: Int?
    let summary: String?
}

struct FriendTasteProfileDTO: Decodable {
    let similarityScore: Double?
    let summary: String?
    let topGenres: [String]?
    let topTags: [String]?
    let matchedSignals: [String]?
}

struct SharedFriendGameDTO: Decodable {
    let game: GameDTO?
    let id: Int?
    let name: String?
    let coverUrl: String?
    let genres: [String]?
    let releaseYear: Int?
    let sharedReason: String?
}

struct FriendRecommendationDTO: Decodable {
    let game: GameDTO
    let reason: String?
}

struct SteamFriendsContextDTO: Decodable {
    let steamFriendsAvailable: Bool?
    let sharedGamesLimitedByPrivacy: Bool?
    let recentPlayedAvailable: Bool?
}

struct SteamFriendsResponseDataDTO: Decodable {
    let friends: [SteamFriendDTO]
    let steamFriendsAvailable: Bool?
    let steamFriendsLimitedByPrivacy: Bool?
    let syncWarningCode: String?
}

struct SteamFriendDTO: Decodable {
    let steamId64: String
    let isLinkedToGamePedia: Bool?
    let userId: String?
    let nickname: String?
    let profileImageUrl: String?
    let personaName: String?
    let avatarUrl: String?
    let profileUrl: String?
}

struct FriendRecommendationsResponseDataDTO: Decodable {
    let recommendations: [FriendRecommendationDTO]
}

struct FriendActivityFeedResponseDataDTO: Decodable {
    let activities: [FriendActivityDTO]
    let nextCursor: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nextCursor = (try? container.decodeIfPresent(String.self, forKey: .nextCursor))
            ?? (try? container.decodeIfPresent(String.self, forKey: .cursor))
        if let activities = try container.decodeIfPresent([FriendActivityDTO].self, forKey: .activities) {
            self.activities = activities
            return
        }
        if let activities = try container.decodeIfPresent([FriendActivityDTO].self, forKey: .items) {
            self.activities = activities
            return
        }
        self.activities = []
    }

    private enum CodingKeys: String, CodingKey {
        case activities
        case items
        case nextCursor
        case cursor
    }
}

struct FriendActivityDTO: Decodable {
    let id: String
    let actor: FriendUserDTO
    let activityType: String?
    let game: FriendActivityGamePreviewDTO
    let message: String?
    let createdAt: Date?
    let reviewId: String?
    let previousRating: Double?
    let updatedRating: Double?
    let previousPlayStatus: String?
    let updatedPlayStatus: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id))
            ?? UUID().uuidString
        actor = (try? container.decode(FriendUserDTO.self, forKey: .actor))
            ?? (try? container.decode(FriendUserDTO.self, forKey: .user))
            ?? FriendUserDTO(
                id: "",
                nickname: "알 수 없는 친구",
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
        activityType = (try? container.decode(String.self, forKey: .activityType))
            ?? (try? container.decode(String.self, forKey: .type))
        game = (try? container.decode(FriendActivityGamePreviewDTO.self, forKey: .relatedGame))
            ?? (try? container.decode(FriendActivityGamePreviewDTO.self, forKey: .game))
            ?? FriendActivityGamePreviewDTO.emptyFallback
        message = try? container.decode(String.self, forKey: .message)
        createdAt = Self.decodeDate(from: container)
        reviewId = (try? container.decode(String.self, forKey: .reviewId))
            ?? (try? container.decode(String.self, forKey: .review_id))
        previousRating = Self.decodeLossyDouble(from: container, primary: .previousRating, secondary: .previous_rating)
        updatedRating = Self.decodeLossyDouble(from: container, primary: .updatedRating, secondary: .updated_rating)
        previousPlayStatus = (try? container.decode(String.self, forKey: .previousPlayStatus))
            ?? (try? container.decode(String.self, forKey: .previous_play_status))
        updatedPlayStatus = (try? container.decode(String.self, forKey: .updatedPlayStatus))
            ?? (try? container.decode(String.self, forKey: .updated_play_status))
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case actor
        case user
        case activityType
        case type
        case relatedGame
        case game
        case message
        case createdAt
        case created_at
        case reviewId
        case review_id
        case previousRating
        case previous_rating
        case updatedRating
        case updated_rating
        case previousPlayStatus
        case previous_play_status
        case updatedPlayStatus
        case updated_play_status
    }

    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>) -> Date? {
        if let date = try? container.decode(Date.self, forKey: .createdAt) {
            return date
        }
        if let value = try? container.decode(String.self, forKey: .createdAt) {
            return parseDate(value)
        }
        if let value = try? container.decode(String.self, forKey: .created_at) {
            return parseDate(value)
        }
        return nil
    }

    private static func decodeLossyDouble(
        from container: KeyedDecodingContainer<CodingKeys>,
        primary: CodingKeys,
        secondary: CodingKeys
    ) -> Double? {
        if let value = try? container.decodeIfPresent(Double.self, forKey: primary) {
            return value
        }
        if let value = try? container.decodeIfPresent(String.self, forKey: primary) {
            return Double(value)
        }
        if let value = try? container.decodeIfPresent(Double.self, forKey: secondary) {
            return value
        }
        if let value = try? container.decodeIfPresent(String.self, forKey: secondary) {
            return Double(value)
        }
        return nil
    }
}

struct FriendActivityGamePreviewDTO: Decodable {
    let gameSource: String?
    let externalGameId: String?
    let title: String?
    let gameName: String?
    let coverUrl: String?
    let igdbGameId: String?
    let metadataEnriched: Bool?
    let detailAvailable: Bool?

    static let emptyFallback = FriendActivityGamePreviewDTO(
        gameSource: nil,
        externalGameId: nil,
        title: "게임",
        gameName: "게임",
        coverUrl: nil,
        igdbGameId: nil,
        metadataEnriched: nil,
        detailAvailable: nil
    )
}

fileprivate extension FriendActivityDTO {
    static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parseDate(_ value: String) -> Date? {
        iso8601WithFractionalSeconds.date(from: value)
            ?? iso8601.date(from: value)
    }
}

struct SendFriendRequestDTO: Encodable {
    let toUserId: String
}

struct BlockUserRequestDTO: Encodable {
    let userId: String
}

struct SocialPrivacySettingsResponseDataDTO: Decodable {
    let isFriendsListPublic: Bool?
    let isRecentPlayPublic: Bool?
    let isLikedGamesPublic: Bool?
    let isReviewsPublic: Bool?
    let steamFriendsFeatureAvailable: Bool?

    enum CodingKeys: String, CodingKey {
        case isFriendsListPublic
        case isRecentPlayPublic
        case isLikedGamesPublic
        case isReviewsPublic
        case steamFriendsFeatureAvailable
    }
}

struct UpdateSocialPrivacySettingsRequestDTO: Encodable {
    let isFriendsListPublic: Bool
    let isRecentPlayPublic: Bool
    let isLikedGamesPublic: Bool
    let isReviewsPublic: Bool
}
