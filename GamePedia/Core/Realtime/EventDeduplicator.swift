import Foundation

// MARK: - EventDeduplicator
// Bounded event-ID dedup: an id already seen is applied exactly once.
// FIFO eviction keeps memory constant on long-lived connections.

struct EventDeduplicator {
    private var seen: Set<String> = []
    private var order: [String] = []
    private let capacity: Int

    init(capacity: Int = 512) {
        self.capacity = max(1, capacity)
    }

    /// Returns true when the id is new (event should be applied).
    mutating func register(_ id: String) -> Bool {
        guard !seen.contains(id) else { return false }
        seen.insert(id)
        order.append(id)
        if order.count > capacity {
            let evicted = order.removeFirst()
            seen.remove(evicted)
        }
        return true
    }

    mutating func reset() {
        seen.removeAll()
        order.removeAll()
    }
}
