import Foundation

struct AppNotification: Hashable {
    enum Kind: Hashable {
        case friendRequestReceived
        case friendRequestAccepted
        case friendReviewReaction
        case friendReviewCreated
        case friendReviewUpdated
        case friendLikedGameAdded
        case friendLikedGameRemoved
        case friendRatingChanged
        case friendPlayStatusChanged
        case friendStartedPlaying
        case friendRecentlyPlayed
        case generic
    }

    let id: String
    let type: String
    let title: String
    let message: String
    let relatedGameID: Int?
    let relatedUserID: String?
    let isRead: Bool
    let createdAt: Date

    var kind: Kind {
        switch type.lowercased() {
        case "friend_request_received", "friend_request":
            return .friendRequestReceived
        case "friend_request_accepted":
            return .friendRequestAccepted
        case "friend_review_reaction":
            return .friendReviewReaction
        case "friend_review_created", "review_created", "friend_wrote_review":
            return .friendReviewCreated
        case "friend_review_updated", "review_updated":
            return .friendReviewUpdated
        case "friend_liked_game_added", "liked_game_added", "friend_wishlisted_game":
            return .friendLikedGameAdded
        case "friend_liked_game_removed", "liked_game_removed":
            return .friendLikedGameRemoved
        case "friend_rating_changed", "rating_changed", "friend_rated_high":
            return .friendRatingChanged
        case "friend_play_status_changed", "play_status_changed":
            return .friendPlayStatusChanged
        case "friend_started_playing":
            return .friendStartedPlaying
        case "friend_recently_played":
            return .friendRecentlyPlayed
        default:
            return .generic
        }
    }

    var socialRoute: SocialActivityRoute? {
        switch kind {
        case .friendRequestReceived:
            return .friendRequests
        case .friendRequestAccepted:
            if let relatedUserID {
                return .friendProfile(relatedUserID)
            }
            return .friendRequests
        case .friendReviewReaction,
             .friendReviewCreated,
             .friendReviewUpdated:
            if let relatedGameID {
                return .review(gameID: relatedGameID, reviewID: nil)
            }
            if let relatedUserID {
                return .friendProfile(relatedUserID)
            }
            return .friendActivityFeed
        case .friendLikedGameAdded,
             .friendLikedGameRemoved,
             .friendRatingChanged,
             .friendPlayStatusChanged,
             .friendStartedPlaying,
             .friendRecentlyPlayed:
            if let relatedGameID {
                return .gameDetail(relatedGameID)
            }
            if let relatedUserID {
                return .friendProfile(relatedUserID)
            }
            return .friendActivityFeed
        case .generic:
            if let relatedGameID {
                return .gameDetail(relatedGameID)
            }
            return nil
        }
    }

    var relativeCreatedAtText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

struct AppNotificationPage: Hashable {
    let notifications: [AppNotification]
    let unreadCount: Int
}
