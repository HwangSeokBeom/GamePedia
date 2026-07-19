import Foundation

// MARK: - Activity Center domain models
//
// The canonical, source-agnostic activity model for the unified Activity
// Center (2.4). Notification-inbox items and friend-activity items are
// mapped into `ActivityCenterItem`; push payloads never enter the list
// directly (a push only signals — REST remains the source of truth).

struct ActivityCenterItem: Hashable {
    enum Source: String, Hashable, CaseIterable {
        case notificationInbox
        case friendActivity
    }

    /// Unique per delivered item (read-state key).
    let identity: String
    /// Channel-agnostic logical event key (cross-source collapse key).
    let logicalKey: String
    let source: Source
    /// Canonical event-class code (stable, machine-readable).
    let kindCode: String
    let title: String
    let message: String
    let occurredAt: Date
    var isRead: Bool
    let route: SocialActivityRoute?

    var notificationKind: AppNotification.Kind {
        AppNotification(
            id: identity,
            type: kindCode,
            title: title,
            message: message,
            relatedGameID: nil,
            relatedUserID: nil,
            relatedReviewID: nil,
            relatedCommentID: nil,
            isRead: isRead,
            createdAt: occurredAt
        ).kind
    }

    var relativeOccurredAtText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: occurredAt, relativeTo: Date())
    }
}

enum ActivitySourceState: String, Hashable {
    case fresh
    case failed
}

struct ActivitySourceHealth: Hashable {
    var notificationInbox: ActivitySourceState
    var friendActivity: ActivitySourceState

    var isFullyFresh: Bool {
        notificationInbox == .fresh && friendActivity == .fresh
    }

    var isFullyFailed: Bool {
        notificationInbox == .failed && friendActivity == .failed
    }

    static let allFresh = ActivitySourceHealth(notificationInbox: .fresh, friendActivity: .fresh)
    static let allFailed = ActivitySourceHealth(notificationInbox: .failed, friendActivity: .failed)
}

struct ActivityCenterSnapshot: Hashable {
    var items: [ActivityCenterItem]
    var sourceHealth: ActivitySourceHealth
    var generatedAt: Date

    var unreadCount: Int {
        items.filter { $0.isRead == false }.count
    }
}

struct ActivityCenterLoadOutcome: Hashable {
    let snapshot: ActivityCenterSnapshot
    /// True when the snapshot is the persisted last-known state rather
    /// than a fresh fetch (full offline/degraded fallback).
    let isFromCache: Bool
    /// The server-reported notification unread count, present ONLY when the
    /// remote inbox responded fresh on this load. This is the single badge
    /// authority: friend activity, local read-state overlays, and cached
    /// snapshots never contribute to it, and a nil here means no source in
    /// this load is allowed to touch the global badge.
    let serverInboxUnreadCount: Int?

    init(
        snapshot: ActivityCenterSnapshot,
        isFromCache: Bool,
        serverInboxUnreadCount: Int? = nil
    ) {
        self.snapshot = snapshot
        self.isFromCache = isFromCache
        self.serverInboxUnreadCount = serverInboxUnreadCount
    }
}

/// Result of a mark-read pass, separating the remote (badge-authoritative)
/// outcome from the local watermark bookkeeping.
enum ActivityCenterMarkReadResult: Equatable {
    /// The server confirmed mark-all-read; the badge may publish zero.
    case remoteConfirmed
    /// The remote call failed; the server unread count is unchanged and the
    /// badge must NOT publish zero. The idempotent call repeats next visit.
    case remoteFailed
    /// No remote call was needed (server unread count already zero); only
    /// the local watermark advanced.
    case localOnly
    /// The session was superseded before any side effect ran.
    case skippedStaleSession
}

enum ActivityCenterError: Error, Equatable {
    /// Every source failed and no last-known snapshot exists.
    case allSourcesUnavailable
}

// MARK: - Persistence payload
//
// Codable projection of a snapshot for the account-scoped last-known
// store. Routes are flattened to stable identifier fields; no tokens or
// credentials are ever part of this payload.

struct PersistedActivityCenterSnapshot: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Sendable {
        let identity: String
        let logicalKey: String
        let source: String
        let kindCode: String
        let title: String
        let message: String
        let occurredAt: Date
        let isRead: Bool
        let routeKind: String?
        let routeGameID: Int?
        let routeUserID: String?
        let routeReviewID: String?
        let routeCommentID: String?
    }

    let generatedAt: Date
    let items: [Item]
}

extension PersistedActivityCenterSnapshot {
    init(snapshot: ActivityCenterSnapshot) {
        generatedAt = snapshot.generatedAt
        items = snapshot.items.map { item in
            let route = item.route
            var routeKind: String?
            var routeGameID: Int?
            var routeUserID: String?
            var routeReviewID: String?
            var routeCommentID: String?
            switch route {
            case .friendActivityFeed:
                routeKind = "friendActivityFeed"
            case .friendRequests:
                routeKind = "friendRequests"
            case .friendProfile(let userID):
                routeKind = "friendProfile"
                routeUserID = userID
            case .gameDetail(let gameID):
                routeKind = "gameDetail"
                routeGameID = gameID
            case .review(let gameID, let reviewID, let commentID):
                routeKind = "review"
                routeGameID = gameID
                routeReviewID = reviewID
                routeCommentID = commentID
            case nil:
                routeKind = nil
            }
            return Item(
                identity: item.identity,
                logicalKey: item.logicalKey,
                source: item.source.rawValue,
                kindCode: item.kindCode,
                title: item.title,
                message: item.message,
                occurredAt: item.occurredAt,
                isRead: item.isRead,
                routeKind: routeKind,
                routeGameID: routeGameID,
                routeUserID: routeUserID,
                routeReviewID: routeReviewID,
                routeCommentID: routeCommentID
            )
        }
    }

    func makeSnapshot() -> ActivityCenterSnapshot {
        let restoredItems: [ActivityCenterItem] = items.compactMap { item in
            guard let source = ActivityCenterItem.Source(rawValue: item.source) else {
                // Unknown source from a newer writer: skip the row instead
                // of mis-rendering it.
                return nil
            }
            let route: SocialActivityRoute?
            switch item.routeKind {
            case "friendActivityFeed":
                route = .friendActivityFeed
            case "friendRequests":
                route = .friendRequests
            case "friendProfile":
                route = item.routeUserID.map { .friendProfile($0) }
            case "gameDetail":
                route = item.routeGameID.map { .gameDetail($0) }
            case "review":
                route = item.routeGameID.map {
                    .review(gameID: $0, reviewID: item.routeReviewID, commentID: item.routeCommentID)
                }
            default:
                route = nil
            }
            return ActivityCenterItem(
                identity: item.identity,
                logicalKey: item.logicalKey,
                source: source,
                kindCode: item.kindCode,
                title: item.title,
                message: item.message,
                occurredAt: item.occurredAt,
                isRead: item.isRead,
                route: route
            )
        }
        return ActivityCenterSnapshot(
            items: restoredItems,
            sourceHealth: .allFailed,
            generatedAt: generatedAt
        )
    }
}
