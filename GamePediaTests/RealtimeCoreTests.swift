import XCTest
@testable import GamePedia

final class RealtimeCoreTests: XCTestCase {

    // MARK: - ReconnectPolicy

    func testBackoffProgressionIsExponentialAndCapped() {
        let policy = ReconnectPolicy(baseDelay: 1, multiplier: 2, maxDelay: 30, maxJitterFraction: 0.25)

        XCTAssertEqual(policy.delay(forAttempt: 1, jitterUnit: 0), 1)
        XCTAssertEqual(policy.delay(forAttempt: 2, jitterUnit: 0), 2)
        XCTAssertEqual(policy.delay(forAttempt: 3, jitterUnit: 0), 4)
        XCTAssertEqual(policy.delay(forAttempt: 4, jitterUnit: 0), 8)
        XCTAssertEqual(policy.delay(forAttempt: 5, jitterUnit: 0), 16)
        XCTAssertEqual(policy.delay(forAttempt: 6, jitterUnit: 0), 30)
        XCTAssertEqual(policy.delay(forAttempt: 10, jitterUnit: 0), 30)
    }

    func testJitterIsDeterministicAndBounded() {
        let policy = ReconnectPolicy(baseDelay: 2, multiplier: 2, maxDelay: 30, maxJitterFraction: 0.25)

        // Deterministic: same inputs -> same output.
        XCTAssertEqual(
            policy.delay(forAttempt: 3, jitterUnit: 0.5),
            policy.delay(forAttempt: 3, jitterUnit: 0.5)
        )

        // Bounded: base <= delay <= base * (1 + maxJitterFraction).
        for jitterUnit in stride(from: 0.0, through: 0.999, by: 0.111) {
            let delay = policy.delay(forAttempt: 3, jitterUnit: jitterUnit)
            XCTAssertGreaterThanOrEqual(delay, 8)
            XCTAssertLessThanOrEqual(delay, 8 * 1.25)
        }

        // Out-of-range jitter input is clamped, never amplified.
        XCTAssertEqual(policy.delay(forAttempt: 1, jitterUnit: -5), 2)
        XCTAssertEqual(policy.delay(forAttempt: 1, jitterUnit: 99), 2 * 1.25)
    }

    // MARK: - EventDeduplicator

    func testDuplicateEventIDRegisteredOnce() {
        var deduplicator = EventDeduplicator(capacity: 8)
        XCTAssertTrue(deduplicator.register("a"))
        XCTAssertFalse(deduplicator.register("a"))
        XCTAssertTrue(deduplicator.register("b"))
        XCTAssertFalse(deduplicator.register("b"))
    }

    func testDeduplicatorEvictsOldestBeyondCapacity() {
        var deduplicator = EventDeduplicator(capacity: 2)
        XCTAssertTrue(deduplicator.register("a"))
        XCTAssertTrue(deduplicator.register("b"))
        XCTAssertTrue(deduplicator.register("c"))   // evicts "a"
        XCTAssertTrue(deduplicator.register("a"))   // "a" re-registrable
        XCTAssertFalse(deduplicator.register("c"))
    }

    // MARK: - EventSequenceStore

    func testSequenceJudgments() {
        var store = EventSequenceStore()
        XCTAssertEqual(store.judge(10), .first)
        XCTAssertEqual(store.judge(11), .next)
        XCTAssertEqual(store.judge(11), .stale)
        XCTAssertEqual(store.judge(5), .stale)
        XCTAssertEqual(store.judge(15), .gap(missed: 3))
        XCTAssertEqual(store.lastSequence, 15)
        store.reset()
        XCTAssertEqual(store.judge(1), .first)
    }

    // MARK: - RealtimeEventDecoder (PROPOSED envelope)

    func testDecoderParsesProposedEnvelope() throws {
        let json = """
        {"id":"evt_1","type":"friend_activity","schemaVersion":1,
         "sequence":7,"occurredAt":"2026-07-18T09:00:00Z","payload":{"k":"v"}}
        """
        let event = try RealtimeEventDecoder().decode(Data(json.utf8))
        XCTAssertEqual(event.id, "evt_1")
        XCTAssertEqual(event.type, .friendActivity)
        XCTAssertEqual(event.schemaVersion, 1)
        XCTAssertEqual(event.sequence, 7)
        XCTAssertNotNil(event.payload)
    }

    func testDecoderIsolatesMalformedEnvelope() {
        let malformed = Data("not json at all".utf8)
        XCTAssertThrowsError(try RealtimeEventDecoder().decode(malformed)) { error in
            XCTAssertEqual(error as? RealtimeEventDecodingError, .malformedEnvelope)
        }

        let missingFields = Data(#"{"id":"evt_1"}"#.utf8)
        XCTAssertThrowsError(try RealtimeEventDecoder().decode(missingFields))
    }

    func testDecoderPreservesUnknownEventType() throws {
        let json = """
        {"id":"evt_2","type":"mystery_type","schemaVersion":9,
         "sequence":1,"occurredAt":"2026-07-18T09:00:00Z"}
        """
        let event = try RealtimeEventDecoder().decode(Data(json.utf8))
        XCTAssertEqual(event.type, .unknown("mystery_type"))
    }

    // MARK: - Production availability wiring

    func testUnavailableClientNeverConnects() async {
        let client = UnavailableRealtimeClient(reason: .noBackendContract)
        XCTAssertEqual(client.availability, .unavailable(.noBackendContract))
        do {
            _ = try await client.open()
            XCTFail("open() must throw — no backend contract exists")
        } catch {
            XCTAssertEqual(error as? RealtimeClientError, .unavailable(.noBackendContract))
        }
    }

    func testRealtimeRuntimeDefaultsToDisabledAndUnavailable() {
        let flags = FeatureFlags.defaults(for: .production)
        XCTAssertFalse(flags.enableRealtimeActivity, "Realtime must stay disabled: no backend contract")

        let runtime = RealtimeRuntime(featureFlags: flags, notificationCenter: NotificationCenter())
        XCTAssertFalse(runtime.isRealtimeEnabled)
    }

    func testFeatureFlagDisabledInEveryEnvironment() {
        for environment in [APIEnvironment.dev, .staging, .production] {
            XCTAssertFalse(FeatureFlags.defaults(for: environment).enableRealtimeActivity)
        }
    }
}
