import Foundation

struct FriendActivityFeedItemViewState: Hashable {
    let id: String
    let actorUserID: String
    let actorNameText: String
    let actorAvatarURL: URL?
    let presenceDisplayModel: UserPresenceDisplayModel?
    let headlineText: String
    let subheadlineText: String?
    let gameTitleText: String
    let gameCoverURL: URL?
    let timestampText: String
    let primaryRoute: SocialActivityRoute
    let actorRoute: SocialActivityRoute?
}

enum FriendActivityFeedItemFormatter {
    static func makeViewState(from item: FriendActivityItem) -> FriendActivityFeedItemViewState {
        FriendActivityFeedItemViewState(
            id: item.stableIdentity,
            actorUserID: item.actor.id,
            actorNameText: item.actor.nickname,
            actorAvatarURL: item.actor.profileImageURL,
            presenceDisplayModel: UserPresenceDisplayFormatter.makeDisplayModel(from: item.actor.presence),
            headlineText: headlineText(for: item),
            subheadlineText: subheadlineText(for: item),
            gameTitleText: item.game.displayTitle,
            gameCoverURL: item.game.coverImageURL,
            timestampText: relativeDateText(for: item.createdAt),
            primaryRoute: primaryRoute(for: item),
            actorRoute: item.actor.id.isEmpty ? nil : .friendProfile(item.actor.id)
        )
    }

    private static func headlineText(for item: FriendActivityItem) -> String {
        if let override = sanitized(item.messageOverride) {
            return override
        }

        switch item.type {
        case .reviewCreated:
            return L10n.Friend.Activity.reviewCreated(item.actor.nickname)
        case .reviewUpdated:
            return L10n.Friend.Activity.reviewUpdated(item.actor.nickname)
        case .likedGameAdded:
            return L10n.Friend.Activity.likedGameAdded(item.actor.nickname)
        case .likedGameRemoved:
            return L10n.Friend.Activity.likedGameRemoved(item.actor.nickname)
        case .ratingChanged:
            if let updatedRating = item.metadata?.updatedRating {
                return L10n.Friend.Activity.ratingChangedValue(
                    item.actor.nickname,
                    LocalizedNumberFormatter.oneFraction(updatedRating)
                )
            }
            return L10n.Friend.Activity.ratingChanged(item.actor.nickname)
        case .playStatusChanged:
            if let updatedStatus = item.metadata?.updatedPlayStatus {
                switch updatedStatus {
                case .playing:
                    return L10n.Friend.Activity.playStatusPlaying(item.actor.nickname)
                case .completed:
                    return L10n.Friend.Activity.playStatusCompleted(item.actor.nickname)
                case .wishlist:
                    return L10n.Friend.Activity.playStatusWishlist(item.actor.nickname)
                case .dropped:
                    return L10n.Friend.Activity.playStatusChanged(item.actor.nickname)
                }
            }
            return L10n.Friend.Activity.playStatusChanged(item.actor.nickname)
        case .friendStartedPlaying:
            return L10n.Friend.Activity.playStatusPlaying(item.actor.nickname)
        case .friendRecentlyPlayed:
            return L10n.Friend.Activity.recentlyPlayed(item.actor.nickname)
        }
    }

    private static func subheadlineText(for item: FriendActivityItem) -> String? {
        if let updatedStatus = item.metadata?.updatedPlayStatus {
            switch updatedStatus {
            case .playing:
                return L10n.Friend.Activity.Subheadline.playStatusUpdate
            case .completed:
                return L10n.Friend.Activity.Subheadline.completed
            case .wishlist:
                return L10n.Friend.Activity.Subheadline.wishlist
            case .dropped:
                return L10n.Friend.Activity.Subheadline.dropped
            }
        }

        switch item.type {
        case .reviewCreated:
            return L10n.Friend.Activity.Subheadline.newReview
        case .reviewUpdated:
            return L10n.Friend.Activity.Subheadline.reviewUpdated
        case .likedGameAdded:
            return L10n.Friend.Activity.Subheadline.likedAdded
        case .likedGameRemoved:
            return L10n.Friend.Activity.Subheadline.likedRemoved
        case .ratingChanged:
            return L10n.Friend.Activity.Subheadline.ratingChanged
        case .playStatusChanged:
            return L10n.Friend.Activity.Subheadline.playStatus
        case .friendStartedPlaying:
            return L10n.Friend.Activity.Subheadline.playing
        case .friendRecentlyPlayed:
            return L10n.Friend.Activity.Subheadline.recentPlay
        }
    }

    private static func primaryRoute(for item: FriendActivityItem) -> SocialActivityRoute {
        switch item.type {
        case .reviewCreated, .reviewUpdated:
            return .review(gameID: item.game.id, reviewID: item.metadata?.reviewID)
        case .likedGameAdded,
             .likedGameRemoved,
             .ratingChanged,
             .playStatusChanged,
             .friendStartedPlaying,
             .friendRecentlyPlayed:
            return .gameDetail(item.game.id)
        }
    }

    private static func relativeDateText(for date: Date?) -> String {
        guard let date else { return L10n.Common.Time.justNow }
        if abs(date.timeIntervalSinceNow) < 60 {
            return L10n.Common.Time.justNow
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
