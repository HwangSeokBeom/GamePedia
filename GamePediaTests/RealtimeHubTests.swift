import XCTest
@testable import GamePedia

// Deterministic coverage for RealtimeHub session/lifecycle/connection
// ownership. All time and randomness is injected; connection streams are
// driven explicitly by MockRealtimeClient. No sleeps, no polling.
final class RealtimeHubTests: XCTestCase {

    private func makeHub(
        client: RealtimeClient,
        sleeper: RealtimeSleeping = TestRealtimeSleeper(autoResume: true),
        jitterUnit: Double = 0
    ) -> RealtimeHub {
        RealtimeHub(
            client: client,
            reconnectPolicy: ReconnectPolicy(baseDelay: 1, multiplier: 2, maxDelay: 30, maxJitterFraction: 0.25),
            sleeper: sleeper,
            jitterSource: FixedJitterSource(unitValue: jitterUnit)
        )
    }

    private func makeConnectedHub(
        client: MockRealtimeClient,
        sleeper: RealtimeSleeping = TestRealtimeSleeper(autoResume: true)
    ) async -> (hub: RealtimeHub, subscription: RealtimeHub.Subscription, connection: MockRealtimeConnection) {
        let hub = makeHub(client: client, sleeper: sleeper)
        let states = await hub.observeConnectionState()
        await hub.sessionDidChange(isAuthenticated: true)
        let subscription = await hub.subscribe()
        await expectState(.connected, in: states)
        let connection = client.openedConnections.last!
        return (hub, subscription, connection)
    }

    // MARK: 1. Concurrent subscribers share one logical connection

    func testConcurrentSubscribersShareOneConnection() async {
        let client = MockRealtimeClient()
        let hub = makeHub(client: client)
        let states = await hub.observeConnectionState()
        await hub.sessionDidChange(isAuthenticated: true)

        async let first = hub.subscribe()
        async let second = hub.subscribe()
        let subscriptions = await (first, second)
        await expectState(.connected, in: states)

        XCTAssertEqual(client.openCount, 1, "One physical connection serves all subscribers")

        let event = makeRealtimeEvent(sequence: 1)
        client.openedConnections[0].emit(event: event)

        let firstSignals = await collectSignals(1, from: subscriptions.0.signals)
        let secondSignals = await collectSignals(1, from: subscriptions.1.signals)
        XCTAssertEqual(firstSignals, [.event(event)])
        XCTAssertEqual(secondSignals, [.event(event)])
    }

    // MARK: 2. One subscriber cancellation preserves other subscribers

    func testOneSubscriberCancellationPreservesOthers() async {
        let client = MockRealtimeClient()
        let hub = makeHub(client: client)
        let states = await hub.observeConnectionState()
        await hub.sessionDidChange(isAuthenticated: true)

        let leaving = await hub.subscribe()
        let staying = await hub.subscribe()
        await expectState(.connected, in: states)
        let connection = client.openedConnections[0]

        await hub.unsubscribe(leaving.id)

        XCTAssertEqual(connection.timesClosed, 0, "Shared connection must survive a non-final cancellation")
        let subscriberCount = await hub.subscriberCount
        XCTAssertEqual(subscriberCount, 1)

        let event = makeRealtimeEvent(sequence: 1)
        connection.emit(event: event)
        let signals = await collectSignals(1, from: staying.signals)
        XCTAssertEqual(signals, [.event(event)])
    }

    // MARK: 3. Final-subscriber policy closes the connection

    func testFinalSubscriberCancellationClosesConnection() async {
        let client = MockRealtimeClient()
        let (hub, subscription, connection) = await makeConnectedHub(client: client)
        let states = await hub.observeConnectionState()

        await hub.unsubscribe(subscription.id)

        await expectState(.idle, in: states)
        XCTAssertGreaterThanOrEqual(connection.timesClosed, 1, "Final subscriber leaving closes the physical connection")
        XCTAssertEqual(client.openCount, 1, "No reconnect without subscribers")
    }

    // MARK: 4. Reconnect backoff progression (deterministic)

    func testReconnectBackoffProgressionMatchesPolicy() async {
        let client = MockRealtimeClient()
        let sleeper = TestRealtimeSleeper(autoResume: true)
        client.failNextOpen(with: RealtimeClientError.transportFailure)
        client.failNextOpen(with: RealtimeClientError.transportFailure)
        client.failNextOpen(with: RealtimeClientError.transportFailure)

        let hub = makeHub(client: client, sleeper: sleeper)
        let states = await hub.observeConnectionState()
        await hub.sessionDidChange(isAuthenticated: true)
        let subscription = await hub.subscribe()

        await expectState(.connected, in: states)

        // Three failed opens -> attempts 1, 2, 3 with zero jitter.
        // (openCount counts successful connections only: the three failures
        // never produce a connection object, the fourth open succeeds.)
        XCTAssertEqual(sleeper.requestedDelays, [1, 2, 4])
        XCTAssertEqual(client.openCount, 1)
        withExtendedLifetime(subscription) {}
    }

    // MARK: 5. Jitter applied to reconnect delays is bounded and injected

    func testReconnectDelayUsesInjectedJitterWithinBounds() async {
        let client = MockRealtimeClient()
        let sleeper = TestRealtimeSleeper(autoResume: true)
        client.failNextOpen(with: RealtimeClientError.transportFailure)

        let hub = makeHub(client: client, sleeper: sleeper, jitterUnit: 0.5)
        let states = await hub.observeConnectionState()
        await hub.sessionDidChange(isAuthenticated: true)
        let subscription = await hub.subscribe()
        await expectState(.connected, in: states)

        // attempt 1, base 1s, jitterUnit 0.5, maxJitterFraction 0.25 -> 1.125s
        XCTAssertEqual(sleeper.requestedDelays, [1 * (1 + 0.25 * 0.5)])
        withExtendedLifetime(subscription) {}
    }

    // MARK: 6. Reconnect cancelled after logout

    func testLogoutCancelsPendingReconnect() async {
        let client = MockRealtimeClient()
        let sleeper = TestRealtimeSleeper(autoResume: false)
        let sleepRequested = expectation(description: "reconnect wait registered")
        sleeper.onSleepRequested = { _ in sleepRequested.fulfill() }

        let (hub, subscription, connection) = await makeConnectedHub(client: client, sleeper: sleeper)
        let states = await hub.observeConnectionState()

        // Drop the transport -> hub schedules a reconnect wait.
        connection.finish(throwing: RealtimeClientError.transportFailure)
        await fulfillment(of: [sleepRequested], timeout: 10)

        // Logout while waiting: the reconnect must be abandoned.
        await hub.sessionDidChange(isAuthenticated: false)
        await expectState(.idle, in: states)

        XCTAssertEqual(client.openCount, 1, "No reconnect may fire after logout")
        XCTAssertEqual(sleeper.pendingCount, 0, "Pending reconnect wait must be cancelled")
        let snapshot = await hub.diagnosticsSnapshot()
        XCTAssertFalse(snapshot.isAuthenticated)
        withExtendedLifetime(subscription) {}
    }

    // MARK: 7 + 8. Session replacement invalidates the old connection and its events

    func testSessionReplacementInvalidatesOldConnectionEvents() async {
        let client = MockRealtimeClient()
        let (hub, subscription, oldConnection) = await makeConnectedHub(client: client)
        let states = await hub.observeConnectionState()

        // Fresh login supersedes the session. Require the connecting ->
        // connected transition so the buffered pre-supersession .connected
        // state cannot satisfy the wait.
        await hub.sessionDidChange(isAuthenticated: true)
        await expectStateSequence([.connecting, .connected], in: states)
        XCTAssertEqual(client.openCount, 2, "New session opens a new connection generation")
        let newConnection = client.openedConnections.last!

        // Events on the superseded connection must not reach subscribers.
        oldConnection.emit(event: makeRealtimeEvent(id: "old-evt", sequence: 99))
        let newEvent = makeRealtimeEvent(id: "new-evt", sequence: 1)
        newConnection.emit(event: newEvent)

        let signals = await collectSignals(1, from: subscription.signals)
        XCTAssertEqual(signals, [.event(newEvent)], "Old-session event must be ignored; first delivered signal comes from the new session")

        let snapshot = await hub.diagnosticsSnapshot()
        XCTAssertEqual(snapshot.deliveredEventCount, 1)
        XCTAssertEqual(snapshot.lastEventSequence, 1, "Old-session sequence must not pollute the new session")
    }

    // MARK: 9. Late old-connection completion is ignored

    func testLateOldConnectionCompletionIgnored() async {
        let client = MockRealtimeClient()
        let sleeper = TestRealtimeSleeper(autoResume: false)
        let (hub, subscription, oldConnection) = await makeConnectedHub(client: client, sleeper: sleeper)
        let states = await hub.observeConnectionState()

        await hub.sessionDidChange(isAuthenticated: true)
        await expectStateSequence([.connecting, .connected], in: states)
        XCTAssertEqual(client.openCount, 2)

        // The superseded connection dies late — must not schedule reconnects
        // or disturb the new connection's state.
        oldConnection.finish(throwing: RealtimeClientError.transportFailure)
        oldConnection.emit(event: makeRealtimeEvent(sequence: 5))

        let stateAfter = await hub.connectionState
        XCTAssertEqual(stateAfter, .connected)
        XCTAssertEqual(sleeper.pendingCount, 0, "A dead superseded connection must not schedule reconnect work")
        XCTAssertEqual(client.openCount, 2)
        withExtendedLifetime(subscription) {}
    }

    // MARK: 10. Duplicate event id applied once

    func testDuplicateEventIDAppliedOnce() async {
        let client = MockRealtimeClient()
        let (hub, subscription, connection) = await makeConnectedHub(client: client)

        connection.emit(event: makeRealtimeEvent(id: "dup", sequence: 1))
        connection.emit(event: makeRealtimeEvent(id: "dup", sequence: 2))
        connection.emit(event: makeRealtimeEvent(id: "next", sequence: 2))

        let signals = await collectSignals(2, from: subscription.signals)
        XCTAssertEqual(signals.count, 2)
        if case .event(let first) = signals[0] { XCTAssertEqual(first.id, "dup") } else { XCTFail() }
        if case .event(let second) = signals[1] { XCTAssertEqual(second.id, "next") } else { XCTFail() }

        let snapshot = await hub.diagnosticsSnapshot()
        XCTAssertEqual(snapshot.duplicateEventCount, 1)
        XCTAssertEqual(snapshot.deliveredEventCount, 2)
    }

    // MARK: 11. Stale sequence ignored

    func testStaleSequenceIgnored() async {
        let client = MockRealtimeClient()
        let (hub, subscription, connection) = await makeConnectedHub(client: client)

        connection.emit(event: makeRealtimeEvent(id: "e5", sequence: 5))
        connection.emit(event: makeRealtimeEvent(id: "e4", sequence: 4))   // stale
        connection.emit(event: makeRealtimeEvent(id: "e6", sequence: 6))

        let signals = await collectSignals(2, from: subscription.signals)
        if case .event(let first) = signals[0] { XCTAssertEqual(first.sequence, 5) } else { XCTFail() }
        if case .event(let second) = signals[1] { XCTAssertEqual(second.sequence, 6) } else { XCTFail() }

        let snapshot = await hub.diagnosticsSnapshot()
        XCTAssertEqual(snapshot.staleSequenceCount, 1)
        XCTAssertEqual(snapshot.lastEventSequence, 6)
    }

    // MARK: 12. Sequence gap requests REST reconciliation

    func testSequenceGapEmitsReconciliationSignal() async {
        let client = MockRealtimeClient()
        let (hub, subscription, connection) = await makeConnectedHub(client: client)

        connection.emit(event: makeRealtimeEvent(id: "e1", sequence: 1))
        let gapEvent = makeRealtimeEvent(id: "e5", sequence: 5)
        connection.emit(event: gapEvent)

        let signals = await collectSignals(3, from: subscription.signals)
        XCTAssertEqual(signals[1], .reconciliationRequired(.sequenceGap))
        XCTAssertEqual(signals[2], .event(gapEvent))

        let snapshot = await hub.diagnosticsSnapshot()
        XCTAssertEqual(snapshot.sequenceGapCount, 1)
    }

    // MARK: 13 + 14. Background disconnect policy and foreground reconnect

    func testBackgroundDisconnectsAndForegroundReconnects() async {
        let client = MockRealtimeClient()
        let sleeper = TestRealtimeSleeper(autoResume: false)
        let (hub, subscription, connection) = await makeConnectedHub(client: client, sleeper: sleeper)
        let states = await hub.observeConnectionState()

        await hub.appDidEnterBackground()
        await expectState(.suspended, in: states)
        XCTAssertEqual(sleeper.pendingCount, 0, "No reconnect work may run while backgrounded")

        // Events from the closed background connection are ignored.
        connection.emit(event: makeRealtimeEvent(sequence: 1))

        await hub.appWillEnterForeground()
        await expectStateSequence([.connecting, .connected], in: states)
        XCTAssertEqual(client.openCount, 2, "Foreground resumes with a fresh connection")

        // Reconnect within the same session emits a reconciliation hint so
        // features re-sync via REST.
        let signals = await collectSignals(1, from: subscription.signals)
        XCTAssertEqual(signals, [.reconciliationRequired(.reconnected)])
    }

    // MARK: 15. Malformed event isolated

    func testMalformedEventIsolated() async {
        let client = MockRealtimeClient()
        let (hub, subscription, connection) = await makeConnectedHub(client: client)

        connection.emit(.decodeFailure)
        let valid = makeRealtimeEvent(sequence: 1)
        connection.emit(event: valid)

        let signals = await collectSignals(1, from: subscription.signals)
        XCTAssertEqual(signals, [.event(valid)], "Connection and later events survive a malformed frame")

        let snapshot = await hub.diagnosticsSnapshot()
        XCTAssertEqual(snapshot.decodeFailureCount, 1)
        XCTAssertEqual(snapshot.connectionState, .connected)
    }

    // MARK: 16. Unknown event type does not crash

    func testUnknownEventTypeCountedAndDelivered() async {
        let client = MockRealtimeClient()
        let (hub, subscription, connection) = await makeConnectedHub(client: client)

        let unknown = makeRealtimeEvent(type: "mystery_type", sequence: 1)
        connection.emit(event: unknown)

        let signals = await collectSignals(1, from: subscription.signals)
        XCTAssertEqual(signals, [.event(unknown)])
        let snapshot = await hub.diagnosticsSnapshot()
        XCTAssertEqual(snapshot.unknownEventTypeCount, 1)
    }

    // MARK: 17. Unavailable client -> hub stays unavailable, nothing connects

    func testHubWithUnavailableClientNeverConnects() async {
        let client = UnavailableRealtimeClient(reason: .noBackendContract)
        let hub = makeHub(client: client)
        await hub.sessionDidChange(isAuthenticated: true)
        let subscription = await hub.subscribe()

        let state = await hub.connectionState
        XCTAssertEqual(state, .unavailable(.noBackendContract))
        let snapshot = await hub.diagnosticsSnapshot()
        XCTAssertEqual(snapshot.reconnectCount, 0)
        XCTAssertEqual(snapshot.deliveredEventCount, 0)
        withExtendedLifetime(subscription) {}
    }

    // MARK: Unauthenticated sessions never connect

    func testUnauthenticatedSessionNeverConnects() async {
        let client = MockRealtimeClient()
        let hub = makeHub(client: client)
        let subscription = await hub.subscribe()

        let state = await hub.connectionState
        XCTAssertEqual(state, .idle)
        XCTAssertEqual(client.openCount, 0, "Authenticated-only channel must not connect as guest")
        withExtendedLifetime(subscription) {}
    }

    // MARK: Focused race repetition (50x): supersession vs old-connection events

    func testRepeatedSupersessionRaceKeepsOwnershipConsistent() async {
        for iteration in 0..<50 {
            let client = MockRealtimeClient()
            let (hub, subscription, oldConnection) = await makeConnectedHub(client: client)
            let states = await hub.observeConnectionState()

            // Race: old connection keeps emitting while the session flips.
            oldConnection.emit(event: makeRealtimeEvent(id: "race-\(iteration)-pre", sequence: 1))
            await hub.sessionDidChange(isAuthenticated: true)
            oldConnection.emit(event: makeRealtimeEvent(id: "race-\(iteration)-post", sequence: 2))

            await expectStateSequence([.connecting, .connected], in: states)
            XCTAssertEqual(client.openCount, 2, "iteration \(iteration)")
            let newConnection = client.openedConnections.last!

            let marker = makeRealtimeEvent(id: "race-\(iteration)-marker", sequence: 1)
            newConnection.emit(event: marker)

            // Drain until the marker arrives; every signal before it must be
            // the pre-supersession event at most — never the post one.
            var seen: [RealtimeSignal] = []
            for await signal in subscription.signals {
                seen.append(signal)
                if signal == .event(marker) { break }
            }
            XCTAssertFalse(
                seen.contains { signal in
                    if case .event(let event) = signal { return event.id == "race-\(iteration)-post" }
                    return false
                },
                "iteration \(iteration): post-supersession event from old session must never be delivered"
            )
        }
    }

    // MARK: Focused race repetition (50x): final unsubscribe vs resubscribe

    func testRepeatedUnsubscribeResubscribeRaceKeepsSingleLoop() async {
        for iteration in 0..<50 {
            let client = MockRealtimeClient()
            let (hub, subscription, _) = await makeConnectedHub(client: client)
            let states = await hub.observeConnectionState()

            await hub.unsubscribe(subscription.id)
            let replacement = await hub.subscribe()

            await expectStateSequence([.connecting, .connected], in: states)
            XCTAssertEqual(client.openCount, 2, "iteration \(iteration): exactly one replacement loop")

            let event = makeRealtimeEvent(id: "resub-\(iteration)", sequence: 1)
            client.openedConnections.last!.emit(event: event)
            let signals = await collectSignals(1, from: replacement.signals)
            // A .reconnected hint may precede the event depending on interleaving.
            XCTAssertTrue(
                signals == [.event(event)] || signals == [.reconciliationRequired(.reconnected)],
                "iteration \(iteration): unexpected signals \(signals)"
            )
        }
    }
}
