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
}

struct FriendActivityDTO: Decodable {
    let id: String
    let actor: FriendUserDTO
    let activityType: String?
    let game: GameDTO
    let createdAt: Date?
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
