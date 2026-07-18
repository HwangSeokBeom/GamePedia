import Foundation

// MARK: - EventSequenceStore
// Client-side sequence protection (PROPOSED policy — the server contract for
// sequences does not exist yet). Stale sequences are rejected; a gap is
// reported so the hub can request REST reconciliation. REST remains the
// source of truth in all cases.

enum SequenceJudgment: Equatable {
    /// First observed sequence for this connection/session.
    case first
    /// Exactly the next expected sequence.
    case next
    /// Older than or equal to the last applied sequence — reject.
    case stale
    /// Newer than expected with missed values in between — apply, but
    /// reconcile via REST.
    case gap(missed: UInt64)
}

struct EventSequenceStore {
    private(set) var lastSequence: UInt64?

    mutating func judge(_ sequence: UInt64) -> SequenceJudgment {
        guard let last = lastSequence else {
            lastSequence = sequence
            return .first
        }
        if sequence <= last {
            return .stale
        }
        if sequence == last + 1 {
            lastSequence = sequence
            return .next
        }
        let missed = sequence - last - 1
        lastSequence = sequence
        return .gap(missed: missed)
    }

    mutating func reset() {
        lastSequence = nil
    }
}
