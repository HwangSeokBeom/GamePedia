import Foundation

// MARK: - PerformanceMetricRecorder
// In-process recorder for the local metric intervals defined in AppMetric.
// Pairs every interval with an os_signpost interval so the same measurement
// is visible in Instruments. Keeps only the latest sample per metric for the
// DEBUG diagnostics surface — durations and timestamps, never content.
//
// Thread-safe via an internal lock; no lock is ever held across an await.

protocol MetricUptimeClock {
    /// Monotonic uptime in nanoseconds. Injectable for deterministic tests.
    func uptimeNanoseconds() -> UInt64
}

struct SystemMetricUptimeClock: MetricUptimeClock {
    func uptimeNanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }
}

struct MetricIntervalToken {
    fileprivate let metric: AppMetric
    fileprivate let id: UUID
    fileprivate let startUptimeNanoseconds: UInt64
    fileprivate let signpostHandle: SignpostIntervalHandle
}

final class PerformanceMetricRecorder {
    private let lock = NSLock()
    private let tracer: SignpostTracing
    private let clock: MetricUptimeClock
    private let dateProvider: () -> Date
    private let logsSamples: Bool
    private var latestSamples: [AppMetric: MetricSample] = [:]
    private var openIntervals: Set<UUID> = []

    init(
        tracer: SignpostTracing = OSSignpostTracer(),
        clock: MetricUptimeClock = SystemMetricUptimeClock(),
        dateProvider: @escaping () -> Date = Date.init,
        logsSamples: Bool = true
    ) {
        self.tracer = tracer
        self.clock = clock
        self.dateProvider = dateProvider
        self.logsSamples = logsSamples
    }

    func begin(_ metric: AppMetric) -> MetricIntervalToken {
        let token = MetricIntervalToken(
            metric: metric,
            id: UUID(),
            startUptimeNanoseconds: clock.uptimeNanoseconds(),
            signpostHandle: tracer.beginInterval(metric)
        )
        lock.lock()
        openIntervals.insert(token.id)
        lock.unlock()
        return token
    }

    @discardableResult
    func end(_ token: MetricIntervalToken, outcome: MetricOutcome = .success) -> MetricSample? {
        let endUptime = clock.uptimeNanoseconds()

        lock.lock()
        guard openIntervals.remove(token.id) != nil else {
            lock.unlock()
            return nil
        }
        let elapsedNanoseconds = endUptime >= token.startUptimeNanoseconds
            ? endUptime - token.startUptimeNanoseconds
            : 0
        let sample = MetricSample(
            metric: token.metric,
            durationMilliseconds: Double(elapsedNanoseconds) / 1_000_000,
            outcome: outcome,
            endedAt: dateProvider()
        )
        latestSamples[token.metric] = sample
        lock.unlock()

        tracer.endInterval(token.signpostHandle, outcome: outcome)
        if logsSamples {
            print(
                "[Metric] name=\(token.metric.rawValue) " +
                "durationMs=\(String(format: "%.1f", sample.durationMilliseconds)) " +
                "outcome=\(outcome.rawValue)"
            )
        }
        return sample
    }

    /// Latest completed sample per metric. Safe metadata only.
    func latestSamplesSnapshot() -> [MetricSample] {
        lock.lock()
        defer { lock.unlock() }
        return AppMetric.allCases.compactMap { latestSamples[$0] }
    }
}
