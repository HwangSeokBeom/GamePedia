import Foundation

// MARK: - MockRealtimeClient
//
// Deterministic, fully controllable transport double. Used by unit tests and
// by the DEBUG diagnostics demo. Never used in production wiring: mock events
// must never reach normal users (see FeatureFlags.enableRealtimeActivity).
//
// Each open() creates a MockRealtimeConnection whose stream is driven
// explicitly via emit/finish — no timers, no randomness, no sleeps.

final class MockRealtimeConnection {
    let source: RealtimeEventSource
    private let continuation: AsyncThrowingStream<RealtimeClientMessage, Error>.Continuation
    private let lock = NSLock()
    private var closeCount = 0

    init() {
        var installedContinuation: AsyncThrowingStream<RealtimeClientMessage, Error>.Continuation!
        let stream = AsyncThrowingStream<RealtimeClientMessage, Error> { continuation in
            installedContinuation = continuation
        }
        continuation = installedContinuation
        let lock = self.lock
        var closeBox = { }
        source = RealtimeEventSource(
            messages: stream,
            close: { closeBox() }
        )
        closeBox = { [weak self] in
            guard let self else { return }
            lock.lock()
            self.closeCount += 1
            lock.unlock()
            self.continuation.finish()
        }
    }

    var timesClosed: Int {
        lock.lock()
        defer { lock.unlock() }
        return closeCount
    }

    func emit(_ message: RealtimeClientMessage) {
        continuation.yield(message)
    }

    func emit(event: RealtimeEvent) {
        continuation.yield(.event(event))
    }

    /// Ends the stream as a transport drop (error) or graceful end (nil).
    func finish(throwing error: Error? = nil) {
        continuation.finish(throwing: error)
    }
}

final class MockRealtimeClient: RealtimeClient {
    private let lock = NSLock()
    private var connections: [MockRealtimeConnection] = []
    private var pendingOpenFailures: [Error] = []

    /// Called synchronously with each newly opened connection.
    var onOpen: ((MockRealtimeConnection) -> Void)?

    var availability: RealtimeAvailability { .available }

    /// Queue an error for the next open() call (connect failure simulation).
    func failNextOpen(with error: Error) {
        lock.lock()
        pendingOpenFailures.append(error)
        lock.unlock()
    }

    var openedConnections: [MockRealtimeConnection] {
        lock.lock()
        defer { lock.unlock() }
        return connections
    }

    var openCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return connections.count
    }

    func open() async throws -> RealtimeEventSource {
        lock.lock()
        if !pendingOpenFailures.isEmpty {
            let error = pendingOpenFailures.removeFirst()
            lock.unlock()
            throw error
        }
        let connection = MockRealtimeConnection()
        connections.append(connection)
        let handler = onOpen
        lock.unlock()
        handler?(connection)
        return connection.source
    }
}
