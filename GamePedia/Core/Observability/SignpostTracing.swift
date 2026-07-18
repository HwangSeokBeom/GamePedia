import Foundation
import OSLog

// MARK: - SignpostTracing
// Thin abstraction over os_signpost intervals so Instruments can attach to
// the same measurements the in-app recorder keeps. Implementations must be
// safe to call from any thread and must never attach dynamic private values
// (tokens, emails, URLs, payloads) to a signpost.

struct SignpostIntervalHandle {
    fileprivate let metric: AppMetric
    fileprivate let state: OSSignpostIntervalState?

    fileprivate init(metric: AppMetric, state: OSSignpostIntervalState?) {
        self.metric = metric
        self.state = state
    }
}

protocol SignpostTracing {
    func beginInterval(_ metric: AppMetric) -> SignpostIntervalHandle
    func endInterval(_ handle: SignpostIntervalHandle, outcome: MetricOutcome)
}

// Emits real os_signpost intervals, visible in Instruments' os_signpost track.
// Only the static metric name and the static outcome label are attached.
final class OSSignpostTracer: SignpostTracing {
    private let signposter: OSSignposter

    init(subsystem: String = Bundle.main.bundleIdentifier ?? "GamePedia") {
        signposter = OSSignposter(subsystem: subsystem, category: "Performance")
    }

    func beginInterval(_ metric: AppMetric) -> SignpostIntervalHandle {
        guard signposter.isEnabled else {
            return SignpostIntervalHandle(metric: metric, state: nil)
        }
        let state = signposter.beginInterval(metric.signpostName, id: signposter.makeSignpostID())
        return SignpostIntervalHandle(metric: metric, state: state)
    }

    func endInterval(_ handle: SignpostIntervalHandle, outcome: MetricOutcome) {
        guard let state = handle.state else { return }
        signposter.endInterval(handle.metric.signpostName, state, "\(outcome.rawValue)")
    }
}

// Test double: records nothing, never crashes in any environment.
final class NoopSignpostTracer: SignpostTracing {
    func beginInterval(_ metric: AppMetric) -> SignpostIntervalHandle {
        SignpostIntervalHandle(metric: metric, state: nil)
    }

    func endInterval(_ handle: SignpostIntervalHandle, outcome: MetricOutcome) {}
}
