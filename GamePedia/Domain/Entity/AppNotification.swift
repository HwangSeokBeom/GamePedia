import Foundation

struct AppNotification: Hashable {
    enum Kind: Hashable {
        case friendRequestReceived
        case friendRequestAccepted
        case friendReviewReaction
        case friendStartedPlaying
        case friendWroteReview
        case friendWishlistedGame
        case friendRatedHigh
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
        case "friend_started_playing":
            return .friendStartedPlaying
        case "friend_wrote_review":
            return .friendWroteReview
        case "friend_wishlisted_game":
            return .friendWishlistedGame
        case "friend_rated_high":
            return .friendRatedHigh
        default:
            return .generic
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
