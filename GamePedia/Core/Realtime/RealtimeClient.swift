import Foundation

// MARK: - RealtimeClient
//
// Transport boundary for one physical realtime connection. The hub owns all
// subscriber fan-out, session ownership, reconnection, deduplication, and
// sequence policy — a client only opens a single connection and yields
// already-decoded messages.
//
// There is deliberately NO remote implementation: the backend has no
// committed realtime contract. Production wiring uses
// UnavailableRealtimeClient; deterministic tests and DEBUG demos use
// MockRealtimeClient.

enum RealtimeClientMessage {
    case event(RealtimeEvent)
    /// A malformed frame was received and isolated. The connection stays up.
    case decodeFailure
}

/// One physical connection: a stream of messages plus an idempotent close.
struct RealtimeEventSource {
    let messages: AsyncThrowingStream<RealtimeClientMessage, Error>
    let close: () -> Void
}

protocol RealtimeClient {
    var availability: RealtimeAvailability { get }
    /// Opens one physical connection. Throws RealtimeClientError.unavailable
    /// when no transport exists; throws transportFailure on connect failure.
    func open() async throws -> RealtimeEventSource
}

// Production default while the backend has no realtime contract. Never
// connects; the hub surfaces `.unavailable(.noBackendContract)` and feature
// code falls back to pure REST behavior.
struct UnavailableRealtimeClient: RealtimeClient {
    let reason: RealtimeUnavailabilityReason

    init(reason: RealtimeUnavailabilityReason = .noBackendContract) {
        self.reason = reason
    }

    var availability: RealtimeAvailability { .unavailable(reason) }

    func open() async throws -> RealtimeEventSource {
        throw RealtimeClientError.unavailable(reason)
    }
}
