import Foundation

// MARK: - AppObservability
// Composition root for the local observability stack. Owned by the app
// process; feature code reaches the recorder through this facade so tests
// can inject their own recorder/tracer/reporter without global state.

final class AppObservability {
    static let shared = AppObservability()

    let recorder: PerformanceMetricRecorder
    let metricKit: MetricKitReporting

    init(
        recorder: PerformanceMetricRecorder = PerformanceMetricRecorder(),
        metricKit: MetricKitReporting? = nil
    ) {
        self.recorder = recorder
        if let metricKit {
            self.metricKit = metricKit
        } else {
#if canImport(MetricKit)
            self.metricKit = MetricKitReporter()
#else
            self.metricKit = NoopMetricKitReporter()
#endif
        }
    }

    func start() {
        metricKit.start()
    }

    // MARK: - Cold launch

    private let launchLock = NSLock()
    private var coldLaunchToken: MetricIntervalToken?

    func markColdLaunchStart() {
        let token = recorder.begin(.coldLaunch)
        launchLock.lock()
        coldLaunchToken = token
        launchLock.unlock()
    }

    /// Ends the cold-launch interval exactly once, at the first meaningful
    /// main-screen render. Later calls are no-ops.
    func markFirstMeaningfulRenderIfNeeded() {
        launchLock.lock()
        let token = coldLaunchToken
        coldLaunchToken = nil
        launchLock.unlock()
        guard let token else { return }
        recorder.end(token, outcome: .success)
    }
}
