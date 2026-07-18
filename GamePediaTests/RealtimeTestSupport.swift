import XCTest
@testable import GamePedia

// MARK: - Deterministic realtime test doubles
//
// No sleeps, no timing-based polling: time is controlled through
// TestRealtimeSleeper (continuation gates), jitter through FixedJitterSource,
// and transport through MockRealtimeClient. The watchdog in awaitFirst is a
// failure safety net only — successful paths never depend on elapsed time.

// Cancellable fake sleeper. Modes:
// - autoResume: sleep() returns immediately (still recording the delay).
// - manual: sleep() parks on a continuation until released or cancelled.
final class TestRealtimeSleeper: RealtimeSleeping, @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var preCancelled: Set<UUID> = []
    private var recordedDelays: [TimeInterval] = []
    private let autoResume: Bool

    /// Fired after a sleep request is registered (safe to fulfill expectations).
    var onSleepRequested: ((TimeInterval) -> Void)?

    init(autoResume: Bool) {
        self.autoResume = autoResume
    }

    var requestedDelays: [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        return recordedDelays
    }

    var pendingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pending.count
    }

    func releaseAll() {
        lock.lock()
        let continuations = pending
        pending.removeAll()
        lock.unlock()
        continuations.values.forEach { $0.resume() }
    }

    func sleep(seconds: TimeInterval) async throws {
        let id = UUID()
        try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    lock.lock()
                    recordedDelays.append(seconds)
                    if preCancelled.remove(id) != nil {
                        lock.unlock()
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    if autoResume {
                        let callback = onSleepRequested
                        lock.unlock()
                        callback?(seconds)
                        continuation.resume()
                        return
                    }
                    pending[id] = continuation
                    let callback = onSleepRequested
                    lock.unlock()
                    callback?(seconds)
                }
            },
            onCancel: {
                lock.lock()
                if let continuation = pending.removeValue(forKey: id) {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                } else {
                    preCancelled.insert(id)
                    lock.unlock()
                }
            }
        )
    }
}

struct FixedJitterSource: JitterSourcing {
    let unitValue: Double
    func nextUnitValue() -> Double { unitValue }
}

// MARK: - Factories

func makeRealtimeEvent(
    id: String = UUID().uuidString,
    type: String = "friend_activity",
    sequence: UInt64
) -> RealtimeEvent {
    RealtimeEvent(
        id: id,
        type: RealtimeEventType(rawValue: type),
        schemaVersion: 1,
        sequence: sequence,
        occurredAt: Date(timeIntervalSince1970: 1_000),
        payload: nil
    )
}

// MARK: - Deterministic async helpers

enum AwaitFirstResult<T> {
    case value(T)
    case streamEnded
    case watchdogExpired
}

/// Consumes `stream` until `predicate` matches. The watchdog exists only to
/// fail fast on a broken implementation instead of hanging the suite.
func awaitFirst<T>(
    in stream: AsyncStream<T>,
    watchdogSeconds: TimeInterval = 10,
    where predicate: @escaping (T) -> Bool
) async -> AwaitFirstResult<T> {
    await withTaskGroup(of: AwaitFirstResult<T>.self) { group in
        group.addTask {
            for await element in stream where predicate(element) {
                return .value(element)
            }
            return .streamEnded
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(watchdogSeconds * 1_000_000_000))
            return .watchdogExpired
        }
        let first = await group.next() ?? .watchdogExpired
        group.cancelAll()
        return first
    }
}

@discardableResult
func expectState(
    _ target: RealtimeConnectionState,
    in stream: AsyncStream<RealtimeConnectionState>,
    file: StaticString = #filePath,
    line: UInt = #line
) async -> Bool {
    let result = await awaitFirst(in: stream) { $0 == target }
    if case .value = result { return true }
    XCTFail("Did not observe state \(target); got \(result)", file: file, line: line)
    return false
}

/// Waits until the state stream produces the given subsequence (not
/// necessarily contiguous). Use when the target state may already be buffered
/// as the observer's initial value — e.g. proving a NEW connect happened by
/// requiring `.connecting` before `.connected`.
@discardableResult
func expectStateSequence(
    _ sequence: [RealtimeConnectionState],
    in stream: AsyncStream<RealtimeConnectionState>,
    watchdogSeconds: TimeInterval = 10,
    file: StaticString = #filePath,
    line: UInt = #line
) async -> Bool {
    await withTaskGroup(of: Bool.self) { group in
        group.addTask {
            var remaining = sequence[...]
            for await state in stream {
                if state == remaining.first {
                    remaining = remaining.dropFirst()
                    if remaining.isEmpty { return true }
                }
            }
            return false
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(watchdogSeconds * 1_000_000_000))
            return false
        }
        let matched = await group.next() ?? false
        group.cancelAll()
        if !matched {
            XCTFail("Did not observe state sequence \(sequence)", file: file, line: line)
        }
        return matched
    }
}

/// Collects exactly `count` signals from the subscription stream.
func collectSignals(
    _ count: Int,
    from stream: AsyncStream<RealtimeSignal>,
    watchdogSeconds: TimeInterval = 10
) async -> [RealtimeSignal] {
    await withTaskGroup(of: [RealtimeSignal].self) { group in
        group.addTask {
            var collected: [RealtimeSignal] = []
            for await signal in stream {
                collected.append(signal)
                if collected.count == count { break }
            }
            return collected
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(watchdogSeconds * 1_000_000_000))
            return []
        }
        let first = await group.next() ?? []
        group.cancelAll()
        return first
    }
}
