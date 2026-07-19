import Foundation

// MARK: - Live activity identity
//
// One logical activity reaches the client over up to three channels:
// REST (notification inbox, friend activity feed), push (FCM social
// payloads), and — once a backend contract exists — realtime events.
// Each channel assigns its own object ID, so "same server ID" is NOT a
// usable cross-channel identity (docs/backend/REALTIME_CONTRACT_REQUEST.md
// open question #8 asks the backend for a shared dedupe key).
//
// Until that contract exists the client derives two keys:
//
// - `exact`: unique per delivered item. Prefers the channel's server ID;
//   falls back to the logical facets. Used for read-state bookkeeping and
//   TTL-based push dedup.
// - `logical`: canonical event class + participant facets, with channel
//   ID deliberately excluded. Two items from different channels that
//   describe the same logical activity produce the same logical key, so
//   the merged Activity Center can collapse them.
//
// Keys are built from stable identifiers only (type codes, user/game/
// review/comment IDs). They never embed titles, messages, emails, tokens,
// or any other free-form value.

struct LiveActivityIdentity: Hashable, Sendable {
    let rawValue: String

    /// Canonical event-class code for a raw channel type string. All the
    /// alias spellings observed across the inbox and push contracts map to
    /// one canonical code so cross-channel keys line up.
    static func canonicalTypeCode(_ rawType: String) -> String {
        switch rawType.lowercased() {
        case "friend_request_received", "friend_request":
            return "friend_request_received"
        case "friend_request_accepted":
            return "friend_request_accepted"
        case "friend_review_reaction":
            return "friend_review_reaction"
        case "friend_review_created", "review_created", "friend_wrote_review":
            return "friend_review_created"
        case "friend_review_updated", "review_updated":
            return "friend_review_updated"
        case "review_comment_reply":
            return "review_comment_reply"
        case "review_comment_like":
            return "review_comment_like"
        case "review_comment_dislike":
            return "review_comment_dislike"
        case "friend_liked_game_added", "liked_game_added", "friend_wishlisted_game":
            return "friend_liked_game_added"
        case "friend_liked_game_removed", "liked_game_removed":
            return "friend_liked_game_removed"
        case "friend_rating_changed", "rating_changed", "friend_rated_high":
            return "friend_rating_changed"
        case "friend_play_status_changed", "play_status_changed":
            return "friend_play_status_changed"
        case "friend_started_playing":
            return "friend_started_playing"
        case "friend_recently_played":
            return "friend_recently_played"
        case "library_curator", "recommendation", "ai_recommendation", "recommendation_ready":
            return "recommendation"
        default:
            return rawType.lowercased()
        }
    }

    static func exact(
        serverID: String?,
        rawType: String,
        actorUserID: String? = nil,
        gameID: Int? = nil,
        reviewID: String? = nil,
        commentID: String? = nil
    ) -> LiveActivityIdentity {
        if let serverID, serverID.isEmpty == false {
            return LiveActivityIdentity(rawValue: "id:\(serverID)")
        }
        return logical(
            rawType: rawType,
            actorUserID: actorUserID,
            gameID: gameID,
            reviewID: reviewID,
            commentID: commentID
        )
    }

    static func logical(
        rawType: String,
        actorUserID: String? = nil,
        gameID: Int? = nil,
        reviewID: String? = nil,
        commentID: String? = nil
    ) -> LiveActivityIdentity {
        let components = [
            "k",
            canonicalTypeCode(rawType),
            actorUserID ?? "",
            gameID.map(String.init) ?? "",
            reviewID ?? "",
            commentID ?? ""
        ]
        return LiveActivityIdentity(rawValue: components.joined(separator: ":"))
    }
}

// MARK: - Live activity deduplicator
//
// TTL + capacity bounded first-writer-wins registry. Generalizes the 2.x
// `SocialActivityDeduplicator` (which now delegates here) so push banners,
// push routes, and future realtime ingestion all share one suppression
// registry: one logical activity is processed once regardless of origin.
//
// The clock is injectable for deterministic tests; production uses Date().

final class LiveActivityDeduplicator: @unchecked Sendable {

    private let lock = NSLock()
    private var seenEvents: [String: Date] = [:]
    private let defaultTimeToLive: TimeInterval
    private let capacity: Int
    private let dateProvider: () -> Date

    init(
        defaultTimeToLive: TimeInterval = 60 * 10,
        capacity: Int = 512,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.defaultTimeToLive = defaultTimeToLive
        self.capacity = capacity
        self.dateProvider = dateProvider
    }

    /// Returns true exactly once per identity within the TTL window.
    func shouldProcess(_ identity: LiveActivityIdentity, timeToLive: TimeInterval? = nil) -> Bool {
        let ttl = timeToLive ?? defaultTimeToLive
        let now = dateProvider()

        lock.lock()
        defer { lock.unlock() }

        seenEvents = seenEvents.filter { now.timeIntervalSince($0.value) < ttl }
        guard seenEvents[identity.rawValue] == nil else { return false }
        if seenEvents.count >= capacity {
            // Bounded memory: evict the oldest entries. Eviction can only
            // cause a duplicate to be re-processed, never an event to be
            // lost, so the safe failure direction is preserved.
            let overflow = seenEvents.count - capacity + 1
            for (key, _) in seenEvents.sorted(by: { $0.value < $1.value }).prefix(overflow) {
                seenEvents.removeValue(forKey: key)
            }
        }
        seenEvents[identity.rawValue] = now
        return true
    }

    func reset() {
        lock.lock()
        seenEvents.removeAll()
        lock.unlock()
    }
}
