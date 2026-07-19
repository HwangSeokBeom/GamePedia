import Foundation

// MARK: - Canonical mapping into ActivityCenterItem
//
// Inbox notifications and friend-activity items become one model. The
// identity/logical keys are derived from stable identifiers only (see
// LiveActivityIdentity); display strings never enter a key.

extension ActivityCenterItem {

    init(notification: AppNotification) {
        let exact = LiveActivityIdentity.exact(
            serverID: notification.id,
            rawType: notification.type,
            actorUserID: notification.relatedUserID,
            gameID: notification.relatedGameID,
            reviewID: notification.relatedReviewID,
            commentID: notification.relatedCommentID
        )
        let logical = LiveActivityIdentity.logical(
            rawType: notification.type,
            actorUserID: notification.relatedUserID,
            gameID: notification.relatedGameID,
            reviewID: notification.relatedReviewID,
            commentID: notification.relatedCommentID
        )
        self.init(
            identity: exact.rawValue,
            logicalKey: logical.rawValue,
            source: .notificationInbox,
            kindCode: LiveActivityIdentity.canonicalTypeCode(notification.type),
            title: notification.title,
            message: notification.message,
            occurredAt: notification.createdAt,
            isRead: notification.isRead,
            route: notification.socialRoute
        )
    }

    init(friendActivity: FriendActivityItem) {
        let rawType = Self.rawType(for: friendActivity.type)
        let exact = LiveActivityIdentity.exact(
            serverID: friendActivity.id.isEmpty ? nil : friendActivity.id,
            rawType: rawType,
            actorUserID: friendActivity.actor.id,
            gameID: friendActivity.game.id,
            reviewID: friendActivity.metadata?.reviewID
        )
        let logical = LiveActivityIdentity.logical(
            rawType: rawType,
            actorUserID: friendActivity.actor.id,
            gameID: friendActivity.game.id,
            reviewID: friendActivity.metadata?.reviewID
        )
        // Items without a server timestamp cannot participate in the read
        // watermark; they are treated as read instead of pinning unread
        // state forever.
        let occurredAt = friendActivity.createdAt
        self.init(
            identity: exact.rawValue,
            logicalKey: logical.rawValue,
            source: .friendActivity,
            kindCode: LiveActivityIdentity.canonicalTypeCode(rawType),
            title: Self.headline(for: friendActivity),
            message: friendActivity.messageOverride ?? friendActivity.game.displayTitle,
            occurredAt: occurredAt ?? Date(timeIntervalSince1970: 0),
            isRead: occurredAt == nil,
            route: Self.route(for: friendActivity)
        )
    }

    private static func rawType(for type: FriendActivityItem.ActivityType) -> String {
        switch type {
        case .reviewCreated:
            return "friend_review_created"
        case .reviewUpdated:
            return "friend_review_updated"
        case .likedGameAdded:
            return "friend_liked_game_added"
        case .likedGameRemoved:
            return "friend_liked_game_removed"
        case .ratingChanged:
            return "friend_rating_changed"
        case .playStatusChanged:
            return "friend_play_status_changed"
        case .friendStartedPlaying:
            return "friend_started_playing"
        case .friendRecentlyPlayed:
            return "friend_recently_played"
        }
    }

    private static func headline(for item: FriendActivityItem) -> String {
        let nickname = item.actor.nickname
        switch item.type {
        case .reviewCreated:
            return L10n.Friend.Activity.reviewCreated(nickname)
        case .reviewUpdated:
            return L10n.Friend.Activity.reviewUpdated(nickname)
        case .likedGameAdded:
            return L10n.Friend.Activity.likedGameAdded(nickname)
        case .likedGameRemoved:
            return L10n.Friend.Activity.likedGameRemoved(nickname)
        case .ratingChanged:
            if let rating = item.metadata?.updatedRating {
                return L10n.Friend.Activity.ratingChangedValue(nickname, String(format: "%.1f", rating))
            }
            return L10n.Friend.Activity.ratingChanged(nickname)
        case .playStatusChanged:
            return L10n.Friend.Activity.playStatusChanged(nickname)
        case .friendStartedPlaying:
            return L10n.Friend.Activity.playStatusPlaying(nickname)
        case .friendRecentlyPlayed:
            return L10n.Friend.Activity.recentlyPlayed(nickname)
        }
    }

    private static func route(for item: FriendActivityItem) -> SocialActivityRoute {
        switch item.type {
        case .reviewCreated, .reviewUpdated:
            return .review(
                gameID: item.game.id,
                reviewID: item.metadata?.reviewID,
                commentID: nil
            )
        case .likedGameAdded, .likedGameRemoved, .ratingChanged,
             .playStatusChanged, .friendStartedPlaying, .friendRecentlyPlayed:
            return .gameDetail(item.game.id)
        }
    }
}
