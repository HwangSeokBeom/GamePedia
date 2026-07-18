import Foundation

// MARK: - Snapshot store boundary

protocol ActivityCenterSnapshotStoring: Sendable {
    func loadSnapshot(accountID: String) async -> PersistedActivityCenterSnapshot?
    func persistSnapshot(_ snapshot: PersistedActivityCenterSnapshot, accountID: String) async
    func purge(accountID: String) async
}

// MARK: - FetchActivityCenterUseCase
//
// Loads the unified Activity Center: notification inbox + friend activity
// feed, fetched concurrently, merged into the canonical timeline.
//
// Degradation policy (no source failure is silent):
// - both sources fresh          -> full snapshot
// - one source fails            -> partial snapshot, health marks the
//                                  failed source, UI shows degraded notice
// - both sources fail           -> persisted last-known snapshot when one
//                                  exists (isFromCache = true), otherwise
//                                  ActivityCenterError.allSourcesUnavailable
//
// REST is the source of truth; push/realtime never inject items here.
// Fresh merged views are persisted per account as the last-known state.

final class FetchActivityCenterUseCase {

    /// Items from different channels describing the same logical activity
    /// carry different server timestamps; collapse only when they are
    /// close together so repeated identical actions stay distinct.
    static let crossSourceCollapseWindow: TimeInterval = 600

    private let notificationRepository: any NotificationRepository
    private let friendRepository: any FriendRepository
    private let readStateStore: any ActivityReadStateStoring
    private let snapshotStore: any ActivityCenterSnapshotStoring
    private let breadcrumbs: OperationBreadcrumbRecorder
    private let dateProvider: () -> Date

    init(
        notificationRepository: any NotificationRepository,
        friendRepository: any FriendRepository,
        readStateStore: any ActivityReadStateStoring,
        snapshotStore: any ActivityCenterSnapshotStoring,
        breadcrumbs: OperationBreadcrumbRecorder = .shared,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.notificationRepository = notificationRepository
        self.friendRepository = friendRepository
        self.readStateStore = readStateStore
        self.snapshotStore = snapshotStore
        self.breadcrumbs = breadcrumbs
        self.dateProvider = dateProvider
    }

    func execute(accountID: String?) async throws -> ActivityCenterLoadOutcome {
        async let inboxPage: AppNotificationPage? = try? notificationRepository
            .fetchNotifications(page: 1, limit: 30)
        async let feedPage: FriendActivityFeedPage? = try? friendRepository
            .fetchFriendActivityFeed(cursor: nil)

        let inbox = await inboxPage
        let feed = await feedPage

        let health = ActivitySourceHealth(
            notificationInbox: inbox == nil ? .failed : .fresh,
            friendActivity: feed == nil ? .failed : .fresh
        )

        if health.isFullyFailed {
            if let accountID,
               let persisted = await snapshotStore.loadSnapshot(accountID: accountID) {
                breadcrumbs.record(
                    .activityCenter,
                    code: "load_cache_fallback",
                    metadata: ["itemCount": String(persisted.items.count)]
                )
                var snapshot = persisted.makeSnapshot()
                snapshot.sourceHealth = .allFailed
                return ActivityCenterLoadOutcome(snapshot: snapshot, isFromCache: true)
            }
            breadcrumbs.record(.activityCenter, code: "load_failed")
            throw ActivityCenterError.allSourcesUnavailable
        }

        let inboxItems = (inbox?.notifications ?? []).map(ActivityCenterItem.init(notification:))
        let feedItems = (feed?.activities ?? []).map(ActivityCenterItem.init(friendActivity:))
        var items = Self.merge(inboxItems: inboxItems, friendItems: feedItems)

        if let accountID {
            let readState = await readStateStore.readState(accountID: accountID)
            items = Self.applying(readState: readState, to: items)
        }

        let snapshot = ActivityCenterSnapshot(
            items: items,
            sourceHealth: health,
            generatedAt: dateProvider()
        )

        if let accountID {
            await snapshotStore.persistSnapshot(
                PersistedActivityCenterSnapshot(snapshot: snapshot),
                accountID: accountID
            )
        }

        if health.isFullyFresh {
            breadcrumbs.record(
                .activityCenter,
                code: "load_success",
                metadata: [
                    "itemCount": String(items.count),
                    "unreadCount": String(snapshot.unreadCount)
                ]
            )
        } else {
            breadcrumbs.record(
                .activityCenter,
                code: "load_partial",
                metadata: [
                    "inbox": health.notificationInbox.rawValue,
                    "friendActivity": health.friendActivity.rawValue,
                    "itemCount": String(items.count)
                ]
            )
        }

        return ActivityCenterLoadOutcome(snapshot: snapshot, isFromCache: false)
    }

    // MARK: Merge (pure, deterministic)

    /// Newest first; one logical activity appears once even when both the
    /// inbox and the friend feed deliver it. The inbox version wins a
    /// collapse because it carries server read state.
    static func merge(
        inboxItems: [ActivityCenterItem],
        friendItems: [ActivityCenterItem]
    ) -> [ActivityCenterItem] {
        let sorted = (inboxItems + friendItems).sorted {
            if $0.occurredAt != $1.occurredAt {
                return $0.occurredAt > $1.occurredAt
            }
            return $0.identity < $1.identity
        }

        var kept: [ActivityCenterItem] = []
        var seenExact = Set<String>()
        for candidate in sorted {
            // Exact duplicates (same delivered item surfacing twice) drop.
            guard seenExact.contains(candidate.identity) == false else { continue }

            if let matchIndex = kept.firstIndex(where: { existing in
                existing.logicalKey == candidate.logicalKey &&
                abs(existing.occurredAt.timeIntervalSince(candidate.occurredAt)) <= crossSourceCollapseWindow
            }) {
                // Cross-source twin: keep exactly one, preferring the inbox
                // item (server read state).
                if kept[matchIndex].source == .friendActivity, candidate.source == .notificationInbox {
                    kept[matchIndex] = candidate
                }
                seenExact.insert(candidate.identity)
                continue
            }

            seenExact.insert(candidate.identity)
            kept.append(candidate)
        }
        return kept
    }

    static func applying(
        readState: ActivityReadState,
        to items: [ActivityCenterItem]
    ) -> [ActivityCenterItem] {
        guard let watermark = readState.readWatermark else { return items }
        return items.map { item in
            guard item.isRead == false, item.occurredAt <= watermark else { return item }
            var updated = item
            updated.isRead = true
            return updated
        }
    }
}

// MARK: - MarkActivityCenterReadUseCase
//
// Server contract limitation: only "mark ALL notifications read" exists.
// The remote call and the local watermark advance together; a remote
// failure is recorded (breadcrumb) but never blocks local read state —
// the call is idempotent and repeats on the next visit.

final class MarkActivityCenterReadUseCase {

    private let notificationRepository: any NotificationRepository
    private let readStateStore: any ActivityReadStateStoring
    private let breadcrumbs: OperationBreadcrumbRecorder

    init(
        notificationRepository: any NotificationRepository,
        readStateStore: any ActivityReadStateStoring,
        breadcrumbs: OperationBreadcrumbRecorder = .shared
    ) {
        self.notificationRepository = notificationRepository
        self.readStateStore = readStateStore
        self.breadcrumbs = breadcrumbs
    }

    func execute(accountID: String?, snapshot: ActivityCenterSnapshot) async {
        guard snapshot.unreadCount > 0 else { return }

        let hasUnreadInboxItems = snapshot.items.contains {
            $0.source == .notificationInbox && $0.isRead == false
        }
        if hasUnreadInboxItems {
            do {
                try await notificationRepository.markAllNotificationsRead()
            } catch {
                breadcrumbs.record(.activityCenter, code: "mark_read_remote_failed")
            }
        }

        if let accountID,
           let newestOccurredAt = snapshot.items.map(\.occurredAt).max() {
            await readStateStore.advanceWatermark(to: newestOccurredAt, accountID: accountID)
        }
        breadcrumbs.record(
            .activityCenter,
            code: "mark_read_local",
            metadata: ["markedCount": String(snapshot.unreadCount)]
        )
    }
}
