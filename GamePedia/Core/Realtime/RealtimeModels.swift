import Foundation

// MARK: - Realtime foundation models
//
// The GamePedia backend has NO committed WebSocket/SSE contract today
// (verified against the CoreServer dev branch — see
// docs/backend/REALTIME_CONTRACT_REQUEST.md). Everything in Core/Realtime is
// therefore a client-side foundation: protocol boundaries, deterministic
// mocks, and an explicitly unavailable production provider. No remote
// transport exists and none may be invented here.

enum RealtimeUnavailabilityReason: String, Equatable {
    /// The backend has no committed realtime contract. Production default.
    case noBackendContract
    /// The feature flag for realtime activity is off.
    case featureDisabled
    /// No authenticated session; authenticated-only channel must not connect.
    case unauthenticated
}

enum RealtimeAvailability: Equatable {
    case available
    case unavailable(RealtimeUnavailabilityReason)
}

enum RealtimeClientError: Error, Equatable {
    case unavailable(RealtimeUnavailabilityReason)
    case transportFailure
}

enum RealtimeConnectionState: Equatable {
    case unavailable(RealtimeUnavailabilityReason)
    /// No subscribers / no session; nothing to do.
    case idle
    case connecting
    case connected
    case waitingToReconnect(attempt: Int)
    /// App is backgrounded: connection closed, reconnect timers cancelled.
    case suspended
}

/// What the hub delivers to subscribers. REST remains the source of truth:
/// feature code treats signals as invalidation hints and reconciles via REST.
enum RealtimeSignal: Equatable {
    case event(RealtimeEvent)
    case reconciliationRequired(RealtimeReconciliationReason)
}

enum RealtimeReconciliationReason: String, Equatable {
    /// A sequence gap was observed; events may have been missed.
    case sequenceGap
    /// The connection was (re)established; state may be stale.
    case reconnected
}
