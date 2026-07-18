import Foundation

// MARK: - RequestCoordinator
//
// Shared in-flight request coalescing with an opt-in short success TTL.
// When several callers ask for the same key while a request is running,
// they all await the one underlying task instead of issuing duplicates.
// By default there is **no response cache**: a call that starts after the
// previous flight finished executes again, so data freshness is exactly
// what each call site had before adopting it. A call site may opt into a
// success TTL when near-simultaneous sequential duplicates are the actual
// defect (e.g. widget snapshot refresh and Home both loading the same
// lists within seconds of launch); errors are never cached.
//
// This generalizes the in-flight-join half of the patterns that already
// existed separately in `GameDetailRequestStore` (game detail TTL cache),
// `WidgetSnapshotRefreshCoordinator` (widget refresh TTL), and the
// `SearchViewModel` latest-request gate. Cache/TTL/backoff policies stay
// with their owning call sites — they are product decisions, not shared
// infrastructure.
//
// Cancellation ownership: the shared flight is owned by the coordinator,
// not by any single waiter. One waiter's task being cancelled must not
// cancel the flight for the others; the cancelled waiter itself stops
// waiting and observes `CancellationError`. The flight is detached from
// the callers' task tree for exactly this reason and is documented here
// as coordinator-owned: it cannot outlive the operation it runs, and its
// result is always delivered to (or discarded with) the keyed slot.
//
// Keys must be privacy-safe: use stable identifiers (endpoint labels,
// numeric IDs, enum raw values) — never raw user input such as search text.

actor RequestCoordinator<Key: Hashable & Sendable, Value: Sendable> {

    private struct CachedValue {
        let value: Value
        let storedAt: Date
    }

    private var inFlightTasks: [Key: Task<Value, Error>] = [:]
    private var cachedValues: [Key: CachedValue] = [:]
    private let logLabel: String?
    private let successTTL: TimeInterval?
    private let dateProvider: @Sendable () -> Date

    /// - Parameters:
    ///   - logLabel: DEBUG-only log prefix; pass nil to stay silent.
    ///   - successTTL: when set, a successful value is reused for this many
    ///     seconds instead of re-fetching. Nil (default) disables caching.
    ///   - dateProvider: injectable clock for deterministic TTL tests.
    init(
        logLabel: String? = nil,
        successTTL: TimeInterval? = nil,
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.logLabel = logLabel
        self.successTTL = successTTL
        self.dateProvider = dateProvider
    }

    /// Runs `operation` for `key`, or joins the identical in-flight request.
    ///
    /// Waiter-cancellation contract: a cancelled caller never receives the
    /// flight's value — it throws `CancellationError` (before the wait if
    /// already cancelled, otherwise on resume when the flight finishes) —
    /// and its cancellation never cancels the shared flight for the other
    /// waiters. Cancellation is not observed mid-wait; the wait ends when
    /// the flight ends. That keeps the semantics deterministic.
    func value(
        for key: Key,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        // Pre-cancelled callers never start or join a flight; this also
        // keeps the keyed slot's lifetime identical to the flight's.
        if Task.isCancelled { throw CancellationError() }

        if let successTTL, let cached = cachedValues[key] {
            let age = dateProvider().timeIntervalSince(cached.storedAt)
            if age >= 0, age < successTTL {
#if DEBUG
                if let logLabel {
                    print("[RequestCache] hit label=\(logLabel) key=\(key) age=\(Int(age))s")
                }
#endif
                return cached.value
            }
            cachedValues[key] = nil
        }

        if let existingTask = inFlightTasks[key] {
#if DEBUG
            if let logLabel {
                print("[RequestCoalescing] join label=\(logLabel) key=\(key)")
            }
#endif
            return try await waitHonoringCallerCancellation(existingTask)
        }

        // Detached deliberately: the flight is coordinator-owned, so no
        // single waiter's task tree may cancel it. It cannot leak — it ends
        // exactly when `operation` ends, and the keyed slot is cleared by
        // the first caller's defer below.
        let flight = Task.detached {
            try await operation()
        }
        inFlightTasks[key] = flight

        defer { inFlightTasks[key] = nil }
        let value = try await waitHonoringCallerCancellation(flight)
        if successTTL != nil {
            cachedValues[key] = CachedValue(value: value, storedAt: dateProvider())
        }
        return value
    }

    /// Number of distinct keys currently in flight (test/diagnostic seam).
    func inFlightCount() -> Int {
        inFlightTasks.count
    }

    private func waitHonoringCallerCancellation(
        _ flight: Task<Value, Error>
    ) async throws -> Value {
        let value = try await flight.value
        if Task.isCancelled { throw CancellationError() }
        return value
    }
}
