import Foundation

// MARK: - RealtimeEvent (PROPOSED envelope)
//
// PROPOSED — NOT AN IMPLEMENTED SERVER CONTRACT.
// The backend currently has no realtime channel. This envelope is the
// client-side proposal submitted to the backend team in
// docs/backend/REALTIME_CONTRACT_REQUEST.md. Field names and semantics may
// change when a real contract is committed. The decoder exists so the mock
// client and deterministic tests can exercise the full pipeline.
//
// PROPOSED fields:
//   id            — globally unique event id (dedup key)
//   type          — namespaced event type string
//   schemaVersion — integer envelope version for forward compatibility
//   sequence      — per-session monotonically increasing ordering value
//   occurredAt    — server-side occurrence time (ISO-8601)
//   payload       — opaque event body; never rendered directly by features

struct RealtimeEvent: Equatable {
    let id: String
    let type: RealtimeEventType
    let schemaVersion: Int
    let sequence: UInt64
    let occurredAt: Date
    /// Opaque payload. Feature code must never render this directly; it is
    /// an invalidation hint that triggers REST reconciliation.
    let payload: Data?
}

enum RealtimeEventType: Equatable {
    case friendActivity
    /// Unknown types are preserved (not dropped, never a crash) so newer
    /// server events degrade gracefully on older clients.
    case unknown(String)

    init(rawValue: String) {
        switch rawValue {
        case "friend_activity": self = .friendActivity
        default: self = .unknown(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .friendActivity: return "friend_activity"
        case .unknown(let value): return value
        }
    }
}

enum RealtimeEventDecodingError: Error, Equatable {
    case malformedEnvelope
}

// Decodes a single PROPOSED envelope. A malformed message must be isolated:
// the decoder reports the failure and the stream continues.
struct RealtimeEventDecoder {
    private struct EnvelopeDTO: Decodable {
        let id: String
        let type: String
        let schemaVersion: Int
        let sequence: UInt64
        let occurredAt: Date
    }

    private let decoder: JSONDecoder

    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func decode(_ data: Data) throws -> RealtimeEvent {
        guard let envelope = try? decoder.decode(EnvelopeDTO.self, from: data) else {
            throw RealtimeEventDecodingError.malformedEnvelope
        }
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let payloadData = (payload?["payload"]).flatMap { body in
            try? JSONSerialization.data(withJSONObject: body)
        }
        return RealtimeEvent(
            id: envelope.id,
            type: RealtimeEventType(rawValue: envelope.type),
            schemaVersion: envelope.schemaVersion,
            sequence: envelope.sequence,
            occurredAt: envelope.occurredAt,
            payload: payloadData
        )
    }
}
