import XCTest
@testable import GamePedia

// Unified cross-channel identity (2.4): the same logical activity
// delivered over REST inbox, friend feed, or push must derive the same
// logical key, while exact keys stay unique per delivered item.
final class LiveActivityIdentityTests: XCTestCase {

    // MARK: Canonical type codes

    func test_canonicalTypeCode_collapsesKnownAliases() {
        XCTAssertEqual(LiveActivityIdentity.canonicalTypeCode("friend_request"), "friend_request_received")
        XCTAssertEqual(LiveActivityIdentity.canonicalTypeCode("FRIEND_WROTE_REVIEW"), "friend_review_created")
        XCTAssertEqual(LiveActivityIdentity.canonicalTypeCode("review_updated"), "friend_review_updated")
        XCTAssertEqual(LiveActivityIdentity.canonicalTypeCode("liked_game_added"), "friend_liked_game_added")
        XCTAssertEqual(LiveActivityIdentity.canonicalTypeCode("friend_rated_high"), "friend_rating_changed")
        XCTAssertEqual(LiveActivityIdentity.canonicalTypeCode("library_curator"), "recommendation")
        XCTAssertEqual(LiveActivityIdentity.canonicalTypeCode("ai_recommendation"), "recommendation")
    }

    func test_canonicalTypeCode_passesUnknownTypesThroughLowercased() {
        XCTAssertEqual(LiveActivityIdentity.canonicalTypeCode("Totally_New_Event"), "totally_new_event")
    }

    // MARK: Exact vs logical keys

    func test_exactKey_prefersServerID() {
        let key = LiveActivityIdentity.exact(
            serverID: "n-123",
            rawType: "friend_review_created",
            actorUserID: "u1",
            gameID: 7
        )
        XCTAssertEqual(key.rawValue, "id:n-123")
    }

    func test_exactKey_fallsBackToLogicalFacetsWhenServerIDMissing() {
        let empty = LiveActivityIdentity.exact(
            serverID: "",
            rawType: "review_created",
            actorUserID: "u1",
            gameID: 7,
            reviewID: "r9"
        )
        let missing = LiveActivityIdentity.exact(
            serverID: nil,
            rawType: "friend_wrote_review",
            actorUserID: "u1",
            gameID: 7,
            reviewID: "r9"
        )
        XCTAssertEqual(empty, missing, "alias spellings and empty/nil server IDs must converge")
        XCTAssertTrue(empty.rawValue.hasPrefix("k:friend_review_created:"))
    }

    func test_logicalKey_isChannelAgnostic() {
        // Inbox and friend-feed deliveries of the same event have different
        // server object IDs but identical facets.
        let inboxKey = LiveActivityIdentity.logical(
            rawType: "friend_review_created",
            actorUserID: "u1",
            gameID: 7,
            reviewID: "r9"
        )
        let feedKey = LiveActivityIdentity.logical(
            rawType: "review_created",
            actorUserID: "u1",
            gameID: 7,
            reviewID: "r9"
        )
        XCTAssertEqual(inboxKey, feedKey)
    }

    func test_logicalKey_distinguishesDifferentFacets() {
        let first = LiveActivityIdentity.logical(rawType: "friend_rating_changed", actorUserID: "u1", gameID: 7)
        let otherGame = LiveActivityIdentity.logical(rawType: "friend_rating_changed", actorUserID: "u1", gameID: 8)
        let otherActor = LiveActivityIdentity.logical(rawType: "friend_rating_changed", actorUserID: "u2", gameID: 7)
        XCTAssertNotEqual(first, otherGame)
        XCTAssertNotEqual(first, otherActor)
    }

    func test_keys_containOnlyStableIdentifiers() {
        let key = LiveActivityIdentity.logical(
            rawType: "friend_review_created",
            actorUserID: "u1",
            gameID: 7,
            reviewID: "r9",
            commentID: "c2"
        )
        XCTAssertFalse(key.rawValue.contains("@"))
        XCTAssertFalse(key.rawValue.contains(" "))
    }

    // MARK: Deduplicator

    private final class ClockBox: @unchecked Sendable {
        private let lock = NSLock()
        private var _now: Date
        init(_ now: Date) { _now = now }
        var now: Date {
            get { lock.lock(); defer { lock.unlock() }; return _now }
            set { lock.lock(); _now = newValue; lock.unlock() }
        }
    }

    func test_deduplicator_appliesEachIdentityOnce() {
        let clock = ClockBox(Date(timeIntervalSince1970: 1_000))
        let deduplicator = LiveActivityDeduplicator(dateProvider: { clock.now })
        let identity = LiveActivityIdentity(rawValue: "id:n-1")

        XCTAssertTrue(deduplicator.shouldProcess(identity))
        XCTAssertFalse(deduplicator.shouldProcess(identity), "duplicate within TTL must be suppressed")
    }

    func test_deduplicator_expiresIdentitiesAfterTTL() {
        let clock = ClockBox(Date(timeIntervalSince1970: 1_000))
        let deduplicator = LiveActivityDeduplicator(defaultTimeToLive: 60, dateProvider: { clock.now })
        let identity = LiveActivityIdentity(rawValue: "id:n-1")

        XCTAssertTrue(deduplicator.shouldProcess(identity))
        clock.now = Date(timeIntervalSince1970: 1_059)
        XCTAssertFalse(deduplicator.shouldProcess(identity), "still inside TTL")
        clock.now = Date(timeIntervalSince1970: 1_061)
        XCTAssertTrue(deduplicator.shouldProcess(identity), "expired identity may be processed again")
    }

    func test_deduplicator_boundsMemoryByEvictingOldestFirst() {
        let clock = ClockBox(Date(timeIntervalSince1970: 0))
        let deduplicator = LiveActivityDeduplicator(
            defaultTimeToLive: 10_000,
            capacity: 3,
            dateProvider: { clock.now }
        )

        for index in 0..<4 {
            clock.now = Date(timeIntervalSince1970: TimeInterval(index))
            XCTAssertTrue(deduplicator.shouldProcess(LiveActivityIdentity(rawValue: "id:\(index)")))
        }

        // Oldest entry (id:0) was evicted to stay within capacity; newest
        // entries are still suppressed.
        XCTAssertTrue(deduplicator.shouldProcess(LiveActivityIdentity(rawValue: "id:0")))
        XCTAssertFalse(deduplicator.shouldProcess(LiveActivityIdentity(rawValue: "id:3")))
    }

    func test_deduplicator_reset_forgetsEverything() {
        let deduplicator = LiveActivityDeduplicator()
        let identity = LiveActivityIdentity(rawValue: "id:n-1")
        XCTAssertTrue(deduplicator.shouldProcess(identity))
        deduplicator.reset()
        XCTAssertTrue(deduplicator.shouldProcess(identity))
    }

    func test_deduplicator_isThreadSafe_underConcurrentRegistration() async {
        let deduplicator = LiveActivityDeduplicator(capacity: 2_048)
        let accepted = await withTaskGroup(of: Int.self, returning: Int.self) { group in
            for worker in 0..<8 {
                group.addTask {
                    var count = 0
                    for index in 0..<50 where deduplicator.shouldProcess(
                        LiveActivityIdentity(rawValue: "id:\(worker)-\(index)")
                    ) {
                        count += 1
                    }
                    return count
                }
            }
            var total = 0
            for await value in group { total += value }
            return total
        }
        XCTAssertEqual(accepted, 400, "distinct identities must all be accepted exactly once")
    }
}
