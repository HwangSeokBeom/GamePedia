import Foundation

// MARK: - ReconnectPolicy
//
// Deterministic exponential backoff with bounded jitter. Pure computation:
// randomness and time are injected so every reconnect scenario is exactly
// reproducible in tests.

protocol JitterSourcing {
    /// A value in [0, 1). Injected so tests control jitter deterministically.
    func nextUnitValue() -> Double
}

struct SystemJitterSource: JitterSourcing {
    func nextUnitValue() -> Double {
        Double.random(in: 0..<1)
    }
}

protocol RealtimeSleeping {
    /// Cancellable suspension. Tests substitute gate-based fakes — no sleeps.
    func sleep(seconds: TimeInterval) async throws
}

struct TaskRealtimeSleeper: RealtimeSleeping {
    func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }
}

struct ReconnectPolicy {
    let baseDelay: TimeInterval
    let multiplier: Double
    let maxDelay: TimeInterval
    /// Additive jitter as a fraction of the computed delay, in [0, maxJitterFraction].
    let maxJitterFraction: Double

    init(
        baseDelay: TimeInterval = 1,
        multiplier: Double = 2,
        maxDelay: TimeInterval = 30,
        maxJitterFraction: Double = 0.25
    ) {
        self.baseDelay = baseDelay
        self.multiplier = multiplier
        self.maxDelay = maxDelay
        self.maxJitterFraction = maxJitterFraction
    }

    /// attempt is 1-based. jitterUnit must be in [0, 1).
    func delay(forAttempt attempt: Int, jitterUnit: Double) -> TimeInterval {
        let boundedAttempt = max(1, attempt)
        let exponential = baseDelay * pow(multiplier, Double(boundedAttempt - 1))
        let capped = min(exponential, maxDelay)
        let boundedJitterUnit = min(max(jitterUnit, 0), 1)
        return capped * (1 + maxJitterFraction * boundedJitterUnit)
    }
}
