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
            return "\(item.actor.nickname)님이 새 리뷰를 남겼어요"
        case .reviewUpdated:
            return "\(item.actor.nickname)님이 리뷰를 수정했어요"
        case .likedGameAdded:
            return "\(item.actor.nickname)님이 게임을 찜했어요"
        case .likedGameRemoved:
            return "\(item.actor.nickname)님이 찜을 정리했어요"
        case .ratingChanged:
            if let updatedRating = item.metadata?.updatedRating {
                return "\(item.actor.nickname)님이 평점을 \(String(format: "%.1f", updatedRating))점으로 남겼어요"
            }
            return "\(item.actor.nickname)님이 평점을 변경했어요"
        case .playStatusChanged:
            if let updatedStatus = item.metadata?.updatedPlayStatus {
                switch updatedStatus {
                case .playing:
                    return "\(item.actor.nickname)님이 지금 플레이 중이에요"
                case .completed:
                    return "\(item.actor.nickname)님이 플레이를 완료했어요"
                case .wishlist:
                    return "\(item.actor.nickname)님이 나중에 플레이할 게임으로 담아뒀어요"
                case .dropped:
                    return "\(item.actor.nickname)님이 플레이 상태를 바꿨어요"
                }
            }
            return "\(item.actor.nickname)님이 플레이 상태를 업데이트했어요"
        case .friendStartedPlaying:
            return "\(item.actor.nickname)님이 지금 플레이 중이에요"
        case .friendRecentlyPlayed:
            return "\(item.actor.nickname)님이 최근에 플레이했어요"
        }
    }

    private static func subheadlineText(for item: FriendActivityItem) -> String? {
        if let updatedStatus = item.metadata?.updatedPlayStatus {
            switch updatedStatus {
            case .playing:
                return "플레이 상태 업데이트"
            case .completed:
                return "엔딩까지 완료"
            case .wishlist:
                return "나중에 플레이 예정"
            case .dropped:
                return "중단한 게임"
            }
        }

        switch item.type {
        case .reviewCreated:
            return "새 리뷰"
        case .reviewUpdated:
            return "리뷰 수정"
        case .likedGameAdded:
            return "찜 추가"
        case .likedGameRemoved:
            return "찜 제거"
        case .ratingChanged:
            return "평점 변경"
        case .playStatusChanged:
            return "플레이 상태"
        case .friendStartedPlaying:
            return "플레이 중"
        case .friendRecentlyPlayed:
            return "최근 플레이"
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
        guard let date else { return "방금 전" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
