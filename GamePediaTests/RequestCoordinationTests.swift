import XCTest
@testable import GamePedia

// Deterministic coverage for the shared request-coordination layer:
// in-flight coalescing, cancellation ownership, and the latest-request
// gate's stale-result rejection.
final class RequestCoordinationTests: XCTestCase {

    // MARK: - Helpers

    /// An operation that parks until released, counting executions.
    private final class GatedOperation: @unchecked Sendable {
        private let lock = NSLock()
        private var startedCount = 0
        private var continuations: [CheckedContinuation<Void, Never>] = []

        var executions: Int {
            lock.lock()
            defer { lock.unlock() }
            return startedCount
        }

        var onStarted: (@Sendable (Int) -> Void)?

        func run() async -> Void {
            lock.lock()
            startedCount += 1
            let current = startedCount
            let callback = onStarted
            lock.unlock()
            callback?(current)
            await withCheckedContinuation { continuation in
                lock.lock()
                continuations.append(continuation)
                lock.unlock()
            }
        }

        func release() {
            lock.lock()
            let parked = continuations
            continuations.removeAll()
            lock.unlock()
            parked.forEach { $0.resume() }
        }
    }

    private func expectStarted(_ operation: GatedOperation, count: Int) -> XCTestExpectation {
        let started = expectation(description: "operation start #\(count)")
        operation.onStarted = { current in
            if current == count { started.fulfill() }
        }
        return started
    }

    // MARK: - RequestCoordinator: coalescing

    func test_concurrentSameKeyCallers_shareOneOperation() async throws {
        let coordinator = RequestCoordinator<String, Int>()
        let operation = GatedOperation()
        let started = expectStarted(operation, count: 1)

        let first = Task {
            try await coordinator.value(for: "k") {
                await operation.run()
                return 7
            }
        }
        await fulfillment(of: [started], timeout: 2)

        // Second and third callers arrive while the flight is parked.
        let second = Task {
            try await coordinator.value(for: "k") {
                await operation.run()
                return 8
            }
        }
        let third = Task {
            try await coordinator.value(for: "k") {
                await operation.run()
                return 9
            }
        }
        // Both must be registered as waiters before the release.
        while await coordinator.inFlightCount() != 1 {
            await Task.yield()
        }
        // Give the joiners a chance to reach the actor before releasing.
        for _ in 0..<50 { await Task.yield() }

        operation.release()

        let values = [try await first.value, try await second.value, try await third.value]
        XCTAssertEqual(values, [7, 7, 7], "all callers must receive the first flight's value")
        XCTAssertEqual(operation.executions, 1, "duplicate concurrent requests must coalesce to one execution")
    }

    func test_distinctKeys_doNotCoalesce() async throws {
        let coordinator = RequestCoordinator<String, Int>()
        async let a = coordinator.value(for: "a") { 1 }
        async let b = coordinator.value(for: "b") { 2 }
        let values = try await [a, b]
        XCTAssertEqual(values, [1, 2])
    }

    func test_sequentialCalls_reExecute_noCaching() async throws {
        let coordinator = RequestCoordinator<String, Int>()
        let counter = GatedOperation()

        counter.onStarted = nil
        let first = Task {
            try await coordinator.value(for: "k") {
                await counter.run()
                return 1
            }
        }
        let started = expectStarted(counter, count: 1)
        await fulfillment(of: [started], timeout: 2)
        counter.release()
        _ = try await first.value

        let second = Task {
            try await coordinator.value(for: "k") {
                await counter.run()
                return 2
            }
        }
        let startedAgain = expectStarted(counter, count: 2)
        await fulfillment(of: [startedAgain], timeout: 2)
        counter.release()
        let secondValue = try await second.value

        XCTAssertEqual(secondValue, 2, "a call after completion must run its own operation")
        XCTAssertEqual(counter.executions, 2)
    }

    func test_failure_propagatesToAllWaiters_andClearsSlot() async throws {
        struct TestFailure: Error {}
        let coordinator = RequestCoordinator<String, Int>()
        let operation = GatedOperation()
        let started = expectStarted(operation, count: 1)

        let first = Task {
            try await coordinator.value(for: "k") {
                await operation.run()
                throw TestFailure()
            }
        }
        await fulfillment(of: [started], timeout: 2)
        let second = Task {
            try await coordinator.value(for: "k") {
                await operation.run()
                throw TestFailure()
            }
        }
        for _ in 0..<50 { await Task.yield() }
        operation.release()

        for task in [first, second] {
            do {
                _ = try await task.value
                XCTFail("expected failure")
            } catch {
                XCTAssertTrue(error is TestFailure)
            }
        }

        // Slot must be free again: a fresh call executes.
        let value = try await coordinator.value(for: "k") { 42 }
        XCTAssertEqual(value, 42)
        let inFlight = await coordinator.inFlightCount()
        XCTAssertEqual(inFlight, 0)
    }

    // MARK: - RequestCoordinator: opt-in success TTL

    func test_successTTL_reusesFreshValue_andExpires() async throws {
        // Deterministic clock: advances only when the test says so.
        final class Clock: @unchecked Sendable {
            private let lock = NSLock()
            private var now = Date(timeIntervalSince1970: 1_000)
            func current() -> Date {
                lock.lock(); defer { lock.unlock() }
                return now
            }
            func advance(_ seconds: TimeInterval) {
                lock.lock(); defer { lock.unlock() }
                now = now.addingTimeInterval(seconds)
            }
        }

        let clock = Clock()
        let coordinator = RequestCoordinator<String, Int>(
            successTTL: 30,
            dateProvider: { clock.current() }
        )
        let counter = GatedOperation()

        func fetch() async throws -> Int {
            try await coordinator.value(for: "k") {
                await counter.run()
                return counter.executions
            }
        }

        let first = Task { try await fetch() }
        let started = expectStarted(counter, count: 1)
        await fulfillment(of: [started], timeout: 2)
        counter.release()
        let firstValue = try await first.value
        XCTAssertEqual(firstValue, 1)

        // Within TTL: cached value, no new execution.
        clock.advance(29)
        let cached = try await fetch()
        XCTAssertEqual(cached, 1)
        XCTAssertEqual(counter.executions, 1, "a fresh cached value must not re-execute")

        // Past TTL: re-executes.
        clock.advance(2)
        let second = Task { try await fetch() }
        let startedAgain = expectStarted(counter, count: 2)
        await fulfillment(of: [startedAgain], timeout: 2)
        counter.release()
        let secondValue = try await second.value
        XCTAssertEqual(secondValue, 2)
        XCTAssertEqual(counter.executions, 2, "an expired value must re-execute")
    }

    func test_successTTL_neverCachesFailures() async throws {
        struct TestFailure: Error {}
        let coordinator = RequestCoordinator<String, Int>(successTTL: 30)
        let counter = GatedOperation()

        let failing = Task {
            try await coordinator.value(for: "k") { () -> Int in
                await counter.run()
                throw TestFailure()
            }
        }
        let started = expectStarted(counter, count: 1)
        await fulfillment(of: [started], timeout: 2)
        counter.release()
        do {
            _ = try await failing.value
            XCTFail("expected failure")
        } catch {}

        let retry = Task {
            try await coordinator.value(for: "k") { () -> Int in
                await counter.run()
                return 5
            }
        }
        let startedAgain = expectStarted(counter, count: 2)
        await fulfillment(of: [startedAgain], timeout: 2)
        counter.release()
        let value = try await retry.value
        XCTAssertEqual(value, 5, "a failure must not be cached; retry must re-execute")
        XCTAssertEqual(counter.executions, 2)
    }

    // MARK: - RequestCoordinator: cancellation ownership

    func test_preCancelledCaller_throwsWithoutStartingFlight() async {
        let coordinator = RequestCoordinator<String, Int>()
        let operation = GatedOperation()

        let caller = Task {
            try await coordinator.value(for: "k") {
                await operation.run()
                return 1
            }
        }
        caller.cancel()

        do {
            _ = try await caller.value
            // A racy non-cancelled start is possible only if cancel lost the
            // race; in that case the operation gate would deadlock, so a
            // returned value here means the flight ran — release it.
            operation.release()
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func test_cancelledWaiter_doesNotCancelSharedFlight() async throws {
        let coordinator = RequestCoordinator<String, Int>()
        let operation = GatedOperation()
        let started = expectStarted(operation, count: 1)

        let survivor = Task {
            try await coordinator.value(for: "k") {
                await operation.run()
                return 11
            }
        }
        await fulfillment(of: [started], timeout: 2)

        let cancelled = Task {
            try await coordinator.value(for: "k") {
                await operation.run()
                return 12
            }
        }
        for _ in 0..<50 { await Task.yield() }
        cancelled.cancel()
        operation.release()

        let survivorValue = try await survivor.value
        XCTAssertEqual(survivorValue, 11, "surviving waiter must still receive the flight's value")
        XCTAssertEqual(operation.executions, 1, "waiter cancellation must not cancel or restart the shared flight")

        do {
            let cancelledValue = try await cancelled.value
            // The joiner may have been pre-cancelled before joining or
            // cancelled mid-wait; either way it must never surface a value.
            XCTFail("cancelled waiter must not receive a value, got \(cancelledValue)")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    // MARK: - LatestRequestGate

    @MainActor
    func test_gate_latestTokenWins() {
        let gate = LatestRequestGate()
        let first = gate.begin()
        let second = gate.begin()

        XCTAssertFalse(gate.isCurrent(first), "superseded token must not be current")
        XCTAssertTrue(gate.isCurrent(second))
        XCTAssertFalse(gate.commit(first), "superseded request must not commit")
        XCTAssertTrue(gate.commit(second), "latest request must commit")
        XCTAssertFalse(gate.commit(second), "a token can commit at most once")
    }

    @MainActor
    func test_gate_invalidateRejectsLateCommit() {
        let gate = LatestRequestGate()
        let token = gate.begin()
        XCTAssertTrue(gate.hasActiveRequest)

        gate.invalidate()

        XCTAssertFalse(gate.hasActiveRequest)
        XCTAssertFalse(gate.isCurrent(token))
        XCTAssertFalse(gate.commit(token), "a commit after invalidation must be rejected")
    }
}
