import Foundation

// MARK: - RealtimeHub
//
// Actor-isolated owner of the (single) logical realtime connection.
//
// Ownership invariants:
// - One physical connection serves all subscribers.
// - The connection loop task is owned by the hub, tagged with the session
//   generation it was started for, and cancelled on: final unsubscribe,
//   session change (login/logout/supersession), and backgrounding. No task
//   outlives its session generation.
// - Every actor re-entry after an await re-validates the owning session
//   generation, so a late event from an old connection can never mutate
//   state belonging to a newer session.
// - Final-subscriber policy (explicit): when the last subscriber leaves, the
//   physical connection is closed and the loop stops; state returns to idle.
// - Reconnect uses deterministic exponential backoff with bounded injected
//   jitter, sleeps via an injected cancellable sleeper (no lock across await
//   — all mutable state is actor-isolated), and is cancelled by
//   logout/supersession/backgrounding.
// - Events are deduplicated by id; stale sequences are rejected; sequence
//   gaps and reconnects emit reconciliation signals. REST stays the source
//   of truth — subscribers treat signals as invalidation hints only.

actor RealtimeHub {
    struct Subscription {
        let id: UUID
        let signals: AsyncStream<RealtimeSignal>
    }

    private let client: RealtimeClient
    private let reconnectPolicy: ReconnectPolicy
    private let sleeper: RealtimeSleeping
    private let jitterSource: JitterSourcing

    private var subscribers: [UUID: AsyncStream<RealtimeSignal>.Continuation] = [:]
    private var stateObservers: [UUID: AsyncStream<RealtimeConnectionState>.Continuation] = [:]

    private(set) var connectionState: RealtimeConnectionState
    private var isAuthenticated = false
    private var isSuspended = false
    private var sessionGeneration: UInt64 = 0
    private var connectionGeneration: UInt64 = 0
    private var hasConnectedThisSession = false
    private var connectionTask: Task<Void, Never>?
    private var connectionLoopID: UUID?

    private var deduplicator = EventDeduplicator()
    private var sequenceStore = EventSequenceStore()

    private var reconnectCount = 0
    private var deliveredEventCount = 0
    private var duplicateEventCount = 0
    private var staleSequenceCount = 0
    private var sequenceGapCount = 0
    private var decodeFailureCount = 0
    private var unknownEventTypeCount = 0
    private var lastSafeErrorCode: String?

    init(
        client: RealtimeClient,
        reconnectPolicy: ReconnectPolicy = ReconnectPolicy(),
        sleeper: RealtimeSleeping = TaskRealtimeSleeper(),
        jitterSource: JitterSourcing = SystemJitterSource()
    ) {
        self.client = client
        self.reconnectPolicy = reconnectPolicy
        self.sleeper = sleeper
        self.jitterSource = jitterSource
        if case .unavailable(let reason) = client.availability {
            connectionState = .unavailable(reason)
        } else {
            connectionState = .idle
        }
    }

    deinit {
        connectionTask?.cancel()
    }

    // MARK: - Subscriptions

    func subscribe() -> Subscription {
        let id = UUID()
        var installedContinuation: AsyncStream<RealtimeSignal>.Continuation!
        let stream = AsyncStream<RealtimeSignal> { continuation in
            installedContinuation = continuation
        }
        subscribers[id] = installedContinuation
        installedContinuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.unsubscribe(id) }
        }
        startConnectionLoopIfNeeded()
        return Subscription(id: id, signals: stream)
    }

    func unsubscribe(_ id: UUID) {
        guard let continuation = subscribers.removeValue(forKey: id) else { return }
        continuation.finish()
        if subscribers.isEmpty {
            // Final-subscriber policy: last one out closes the connection.
            stopConnectionLoop(newState: postTeardownIdleState())
        }
    }

    var subscriberCount: Int { subscribers.count }

    // MARK: - Session ownership

    /// Bridged from `.authSessionDidChange`. Any session transition (login,
    /// logout, supersession by a fresh login, account deletion) bumps the
    /// session generation: the old connection loop is cancelled and events
    /// it may still surface are ignored by generation checks.
    func sessionDidChange(isAuthenticated: Bool) {
        sessionGeneration &+= 1
        self.isAuthenticated = isAuthenticated
        hasConnectedThisSession = false
        deduplicator.reset()
        sequenceStore.reset()
        stopConnectionLoop(newState: postTeardownIdleState())
        if isAuthenticated {
            startConnectionLoopIfNeeded()
        }
    }

    // MARK: - App lifecycle

    /// Background policy (explicit): close the connection and cancel all
    /// reconnect work while backgrounded; resume on foreground when there
    /// are live subscribers and an authenticated session.
    func appDidEnterBackground() {
        guard !isSuspended else { return }
        isSuspended = true
        stopConnectionLoop(newState: subscribers.isEmpty ? postTeardownIdleState() : .suspended)
    }

    func appWillEnterForeground() {
        guard isSuspended else { return }
        isSuspended = false
        if connectionState == .suspended {
            setConnectionState(postTeardownIdleState())
        }
        startConnectionLoopIfNeeded()
    }

    // MARK: - State observation

    func observeConnectionState() -> AsyncStream<RealtimeConnectionState> {
        let id = UUID()
        var installedContinuation: AsyncStream<RealtimeConnectionState>.Continuation!
        let stream = AsyncStream<RealtimeConnectionState> { continuation in
            installedContinuation = continuation
        }
        stateObservers[id] = installedContinuation
        installedContinuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.removeStateObserver(id) }
        }
        installedContinuation.yield(connectionState)
        return stream
    }

    private func removeStateObserver(_ id: UUID) {
        stateObservers.removeValue(forKey: id)?.finish()
    }

    func diagnosticsSnapshot() -> RealtimeDiagnosticsSnapshot {
        RealtimeDiagnosticsSnapshot(
            connectionState: connectionState,
            isAuthenticated: isAuthenticated,
            sessionGeneration: sessionGeneration,
            connectionGeneration: connectionGeneration,
            subscriberCount: subscribers.count,
            reconnectCount: reconnectCount,
            deliveredEventCount: deliveredEventCount,
            duplicateEventCount: duplicateEventCount,
            staleSequenceCount: staleSequenceCount,
            sequenceGapCount: sequenceGapCount,
            decodeFailureCount: decodeFailureCount,
            unknownEventTypeCount: unknownEventTypeCount,
            lastEventSequence: sequenceStore.lastSequence,
            lastSafeErrorCode: lastSafeErrorCode
        )
    }

    // MARK: - Connection loop

    private func startConnectionLoopIfNeeded() {
        guard connectionTask == nil,
              !subscribers.isEmpty,
              isAuthenticated,
              !isSuspended else { return }

        if case .unavailable(let reason) = client.availability {
            setConnectionState(.unavailable(reason))
            return
        }

        let owningGeneration = sessionGeneration
        let loopID = UUID()
        connectionLoopID = loopID
        connectionTask = Task {
            await self.runConnectionLoop(owningGeneration: owningGeneration, loopID: loopID)
        }
    }

    private func stopConnectionLoop(newState: RealtimeConnectionState) {
        connectionTask?.cancel()
        connectionTask = nil
        connectionLoopID = nil
        setConnectionState(newState)
    }

    private func postTeardownIdleState() -> RealtimeConnectionState {
        if case .unavailable(let reason) = client.availability {
            return .unavailable(reason)
        }
        return .idle
    }

    private func isCurrent(_ owningGeneration: UInt64) -> Bool {
        owningGeneration == sessionGeneration
    }

    private func runConnectionLoop(owningGeneration: UInt64, loopID: UUID) async {
        var attempt = 0
        defer { finishLoop(owningGeneration: owningGeneration, loopID: loopID) }

        while !Task.isCancelled,
              isCurrent(owningGeneration),
              !subscribers.isEmpty,
              isAuthenticated,
              !isSuspended {

            setConnectionState(.connecting)

            let source: RealtimeEventSource
            do {
                source = try await client.open()
            } catch let error as RealtimeClientError {
                guard isCurrent(owningGeneration), !Task.isCancelled else { return }
                switch error {
                case .unavailable(let reason):
                    // No transport contract: do not retry forever.
                    lastSafeErrorCode = "UNAVAILABLE_\(reason.rawValue.uppercased())"
                    setConnectionState(.unavailable(reason))
                    return
                case .transportFailure:
                    lastSafeErrorCode = "TRANSPORT_FAILURE"
                }
                if await !waitBeforeReconnect(&attempt, owningGeneration: owningGeneration) { return }
                continue
            } catch is CancellationError {
                return
            } catch {
                guard isCurrent(owningGeneration), !Task.isCancelled else { return }
                lastSafeErrorCode = "TRANSPORT_FAILURE"
                if await !waitBeforeReconnect(&attempt, owningGeneration: owningGeneration) { return }
                continue
            }

            // Re-entered the actor after the open await: re-validate owner.
            guard isCurrent(owningGeneration), !Task.isCancelled, !isSuspended else {
                source.close()
                return
            }

            attempt = 0
            connectionGeneration &+= 1
            let owningConnection = connectionGeneration
            setConnectionState(.connected)

            if hasConnectedThisSession {
                // Reconnected within the same session: local view may be
                // stale, ask features to reconcile via REST.
                reconnectCount += 1
                broadcast(.reconciliationRequired(.reconnected))
            }
            hasConnectedThisSession = true

            do {
                for try await message in source.messages {
                    guard isCurrent(owningGeneration),
                          owningConnection == connectionGeneration,
                          !Task.isCancelled else {
                        break
                    }
                    handle(message)
                }
            } catch is CancellationError {
                source.close()
                return
            } catch {
                lastSafeErrorCode = "TRANSPORT_FAILURE"
            }
            source.close()

            guard isCurrent(owningGeneration), !Task.isCancelled else { return }
            if await !waitBeforeReconnect(&attempt, owningGeneration: owningGeneration) { return }
        }
    }

    /// Loop epilogue: only the task that still owns the slot clears it, so a
    /// finishing old loop can never clobber a newer loop's registration.
    private func finishLoop(owningGeneration: UInt64, loopID: UUID) {
        guard connectionLoopID == loopID else { return }
        connectionTask = nil
        connectionLoopID = nil
        guard isCurrent(owningGeneration), !Task.isCancelled else { return }
        switch connectionState {
        case .connecting, .connected, .waitingToReconnect:
            setConnectionState(postTeardownIdleState())
        case .unavailable, .idle, .suspended:
            break
        }
    }

    /// Returns false when the loop must stop (cancellation or lost ownership).
    private func waitBeforeReconnect(
        _ attempt: inout Int,
        owningGeneration: UInt64
    ) async -> Bool {
        guard !subscribers.isEmpty, isAuthenticated, !isSuspended else {
            return false
        }

        attempt += 1
        setConnectionState(.waitingToReconnect(attempt: attempt))
        let delay = reconnectPolicy.delay(
            forAttempt: attempt,
            jitterUnit: jitterSource.nextUnitValue()
        )
        do {
            try await sleeper.sleep(seconds: delay)
        } catch {
            // Cancelled while waiting (logout, supersession, background,
            // final unsubscribe): reconnect is abandoned.
            return false
        }
        guard isCurrent(owningGeneration), !Task.isCancelled else { return false }
        return true
    }

    // MARK: - Message handling

    private func handle(_ message: RealtimeClientMessage) {
        switch message {
        case .decodeFailure:
            // Malformed frame isolated: connection and other events continue.
            decodeFailureCount += 1
        case .event(let event):
            if case .unknown = event.type {
                // Unknown types are counted and still delivered as opaque
                // signals; they must never crash the pipeline.
                unknownEventTypeCount += 1
            }
            guard deduplicator.register(event.id) else {
                duplicateEventCount += 1
                return
            }
            switch sequenceStore.judge(event.sequence) {
            case .stale:
                staleSequenceCount += 1
                return
            case .gap:
                sequenceGapCount += 1
                broadcast(.reconciliationRequired(.sequenceGap))
                deliveredEventCount += 1
                broadcast(.event(event))
            case .first, .next:
                deliveredEventCount += 1
                broadcast(.event(event))
            }
        }
    }

    private func broadcast(_ signal: RealtimeSignal) {
        for continuation in subscribers.values {
            continuation.yield(signal)
        }
    }

    private func setConnectionState(_ newState: RealtimeConnectionState) {
        guard connectionState != newState else { return }
        connectionState = newState
        for continuation in stateObservers.values {
            continuation.yield(newState)
        }
    }
}
