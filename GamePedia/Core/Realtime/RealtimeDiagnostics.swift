import Foundation

// MARK: - RealtimeDiagnosticsSnapshot
// Safe-metadata-only view of the hub for the DEBUG diagnostics surface and
// tests. Contains booleans, counters, generations, and static error codes.
// Never contains tokens, emails, Authorization values, or event payloads.

struct RealtimeDiagnosticsSnapshot: Equatable {
    let connectionState: RealtimeConnectionState
    let isAuthenticated: Bool
    let sessionGeneration: UInt64
    let connectionGeneration: UInt64
    let subscriberCount: Int
    let reconnectCount: Int
    let deliveredEventCount: Int
    let duplicateEventCount: Int
    let staleSequenceCount: Int
    let sequenceGapCount: Int
    let decodeFailureCount: Int
    let unknownEventTypeCount: Int
    let lastEventSequence: UInt64?
    /// Static, privacy-safe error code (e.g. "TRANSPORT_FAILURE") — never a
    /// server message or dynamic string.
    let lastSafeErrorCode: String?

    var connectionStateDescription: String {
        switch connectionState {
        case .unavailable(let reason): return "unavailable(\(reason.rawValue))"
        case .idle: return "idle"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .waitingToReconnect(let attempt): return "waitingToReconnect(attempt: \(attempt))"
        case .suspended: return "suspended"
        }
    }
}
