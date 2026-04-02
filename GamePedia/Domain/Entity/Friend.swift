import Foundation

enum FriendRelationshipStatus: String, Hashable {
    case none
    case outgoing
    case incoming
    case friends
    case `self`
}

enum UserPresenceState: String, Hashable {
    case online
    case recentlyActive
    case playing
    case lastPlayed
    case unknown
}

struct UserPresence: Hashable {
    let state: UserPresenceState
    let gameTitle: String?
    let lastActiveAt: Date?
    let lastPlayedAt: Date?
    let isSteamSupplemented: Bool

    var stableIdentity: String {
        [
            state.rawValue,
            gameTitle ?? "",
            lastActiveAt.map { String($0.timeIntervalSince1970) } ?? "",
            lastPlayedAt.map { String($0.timeIntervalSince1970) } ?? "",
            isSteamSupplemented ? "steam" : "app"
        ].joined(separator: "|")
    }
}

struct FriendUserSummary: Hashable {
    let id: String
    let nickname: String
    let bio: String?
    let profileImageURL: URL?
    let relationshipStatus: FriendRelationshipStatus
    let recentPlayTitle: String?
    let presence: UserPresence?
}

struct FriendRequest: Hashable {
    let id: String
    let user: FriendUserSummary
    let createdAt: Date?
}

struct FriendProfileReview: Hashable {
    let id: String
    let gameID: Int?
    let gameTitle: String
    let content: String
    let ratingText: String?
    let createdAtText: String
}

struct FriendTasteSimilarity: Hashable {
    let percentage: Int?
    let summaryText: String

    var titleText: String {
        if let percentage {
            return "취향 유사도 \(percentage)%"
        }
        return "취향 유사도"
    }
}

struct FriendTasteProfile: Hashable {
    let similarityScore: Int?
    let summaryText: String
    let topGenres: [String]
    let topTags: [String]

    var highlightTitle: String {
        if let similarityScore {
            return "취향 유사도 \(similarityScore)%"
        }
        return "취향 유사도"
    }

    var displayChips: [String] {
        Array((topGenres + topTags).prefix(4))
    }
}

struct SharedFriendGame: Hashable {
    let game: Game
    let reasonText: String
}

struct FriendRecommendation: Hashable {
    let game: Game
    let reasonText: String
}

struct SteamFriendsContext: Hashable {
    let isAvailable: Bool
    let isLimitedByPrivacy: Bool
    let isRecentPlayedAvailable: Bool
}

struct SteamFriend: Hashable {
    let steamId64: String
    let userId: String?
    let nickname: String?
    let profileImageURL: URL?
    let personaName: String?
    let avatarURL: URL?
    let profileURL: URL?
    let isLinkedToGamePedia: Bool

    var displayName: String {
        if let nickname, !nickname.isEmpty {
            return nickname
        }
        if let personaName, !personaName.isEmpty {
            return personaName
        }
        return "Steam 친구"
    }

    var resolvedAvatarURL: URL? {
        profileImageURL ?? avatarURL
    }
}

struct FriendActivityMetadata: Hashable {
    let reviewID: String?
    let previousRating: Double?
    let updatedRating: Double?
    let previousPlayStatus: UserGameStatus?
    let updatedPlayStatus: UserGameStatus?
    let note: String?
}

struct FriendActivityItem: Hashable {
    enum ActivityType: String, Hashable {
        case reviewCreated
        case reviewUpdated
        case likedGameAdded
        case likedGameRemoved
        case ratingChanged
        case playStatusChanged
        case friendStartedPlaying
        case friendRecentlyPlayed
    }

    let id: String
    let actor: FriendUserSummary
    let type: ActivityType
    let game: Game
    let createdAt: Date?
    let messageOverride: String?
    let metadata: FriendActivityMetadata?

    var stableIdentity: String {
        if !id.isEmpty {
            return id
        }

        return [
            actor.id,
            type.rawValue,
            String(game.id),
            createdAt.map { String($0.timeIntervalSince1970) } ?? "0"
        ].joined(separator: ":")
    }
}

struct FriendActivityFeedPage: Hashable {
    let activities: [FriendActivityItem]
    let nextCursor: String?
}

struct FriendProfile {
    let user: FriendUserSummary
    let tasteSimilarity: FriendTasteSimilarity?
    let tasteProfile: FriendTasteProfile?
    let sharedGames: [SharedFriendGame]
    let commonLikedGames: [Game]
    let commonInterestGames: [Game]
    let commonHighlyRatedGames: [Game]
    let recentlyPlayed: [RecentGame]
    let likedGames: [Game]
    let writtenReviews: [FriendProfileReview]
    let friendRecommendations: [FriendRecommendation]
    let steamFriendsContext: SteamFriendsContext?
}

struct SocialPrivacySettings: Hashable {
    let isFriendsListPublic: Bool
    let isRecentPlayPublic: Bool
    let isLikedGamesPublic: Bool
    let isReviewsPublic: Bool
    let isSteamFriendsFeatureAvailable: Bool

    static let `default` = SocialPrivacySettings(
        isFriendsListPublic: true,
        isRecentPlayPublic: true,
        isLikedGamesPublic: true,
        isReviewsPublic: true,
        isSteamFriendsFeatureAvailable: false
    )

    func updated(
        isFriendsListPublic: Bool? = nil,
        isRecentPlayPublic: Bool? = nil,
        isLikedGamesPublic: Bool? = nil,
        isReviewsPublic: Bool? = nil
    ) -> SocialPrivacySettings {
        SocialPrivacySettings(
            isFriendsListPublic: isFriendsListPublic ?? self.isFriendsListPublic,
            isRecentPlayPublic: isRecentPlayPublic ?? self.isRecentPlayPublic,
            isLikedGamesPublic: isLikedGamesPublic ?? self.isLikedGamesPublic,
            isReviewsPublic: isReviewsPublic ?? self.isReviewsPublic,
            isSteamFriendsFeatureAvailable: isSteamFriendsFeatureAvailable
        )
    }
}
