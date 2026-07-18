import XCTest
@testable import GamePedia

final class ObservabilityTests: XCTestCase {

    private final class ManualUptimeClock: MetricUptimeClock {
        private let lock = NSLock()
        private var current: UInt64 = 0

        func advance(milliseconds: UInt64) {
            lock.lock()
            current += milliseconds * 1_000_000
            lock.unlock()
        }

        func uptimeNanoseconds() -> UInt64 {
            lock.lock()
            defer { lock.unlock() }
            return current
        }
    }

    private func makeRecorder(clock: ManualUptimeClock = ManualUptimeClock()) -> PerformanceMetricRecorder {
        PerformanceMetricRecorder(
            tracer: NoopSignpostTracer(),
            clock: clock,
            dateProvider: { Date(timeIntervalSince1970: 1_000) },
            logsSamples: false
        )
    }

    // MARK: - Recorder

    func testRecorderMeasuresDurationWithInjectedClock() {
        let clock = ManualUptimeClock()
        let recorder = makeRecorder(clock: clock)

        let token = recorder.begin(.searchRoundTrip)
        clock.advance(milliseconds: 250)
        let sample = recorder.end(token, outcome: .success)

        XCTAssertEqual(sample?.durationMilliseconds, 250)
        XCTAssertEqual(sample?.metric, .searchRoundTrip)
        XCTAssertEqual(sample?.outcome, .success)
        XCTAssertEqual(recorder.latestSamplesSnapshot(), [sample].compactMap { $0 })
    }

    func testRecorderEndIsIdempotentPerToken() {
        let recorder = makeRecorder()
        let token = recorder.begin(.authRefresh)
        XCTAssertNotNil(recorder.end(token, outcome: .success))
        XCTAssertNil(recorder.end(token, outcome: .failure), "Double-end must be a no-op")
        XCTAssertEqual(recorder.latestSamplesSnapshot().count, 1)
    }

    func testRecorderKeepsLatestSamplePerMetric() {
        let clock = ManualUptimeClock()
        let recorder = makeRecorder(clock: clock)

        let first = recorder.begin(.gameDetailLoad)
        clock.advance(milliseconds: 100)
        recorder.end(first, outcome: .success)

        let second = recorder.begin(.gameDetailLoad)
        clock.advance(milliseconds: 40)
        recorder.end(second, outcome: .failure)

        let samples = recorder.latestSamplesSnapshot()
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.durationMilliseconds, 40)
        XCTAssertEqual(samples.first?.outcome, .failure)
    }

    func testRecorderSamplesContainOnlySafeFields() {
        // MetricSample is duration/outcome/timestamp/metric-name only —
        // no request data can leak because none is ever accepted.
        let recorder = makeRecorder()
        let token = recorder.begin(.friendActivityRefresh)
        let sample = recorder.end(token, outcome: .success)
        let mirror = Mirror(reflecting: sample!)
        let labels = Set(mirror.children.compactMap(\.label))
        XCTAssertEqual(labels, ["metric", "durationMilliseconds", "outcome", "endedAt"])
    }

    // MARK: - Signpost tracer safety

    func testSignpostTracerIsSafeInTestEnvironment() {
        let tracer = OSSignpostTracer(subsystem: "test.gamepedia.observability")
        let handle = tracer.beginInterval(.coldLaunch)
        tracer.endInterval(handle, outcome: .success)

        let noop = NoopSignpostTracer()
        let noopHandle = noop.beginInterval(.coldLaunch)
        noop.endInterval(noopHandle, outcome: .cancelled)
        // Reaching this point without a crash is the assertion.
    }

    // MARK: - MetricKit safety

    func testMetricKitReporterRegistrationIsSafeAndIdempotent() {
        let reporter = MetricKitReporter(dateProvider: { Date(timeIntervalSince1970: 0) })
        XCTAssertFalse(reporter.isActive)
        reporter.start()
        reporter.start() // double-start must not double-register or crash
        XCTAssertTrue(reporter.isActive)
        XCTAssertEqual(reporter.receiptSummary(), MetricKitReceiptSummary())
        reporter.stop()
        reporter.stop()
        XCTAssertFalse(reporter.isActive)
    }

    func testNoopMetricKitReporterIsInert() {
        let reporter = NoopMetricKitReporter()
        reporter.start()
        XCTAssertFalse(reporter.isActive)
        XCTAssertEqual(reporter.receiptSummary(), MetricKitReceiptSummary())
    }

    // MARK: - Cold launch single-shot

    func testColdLaunchCompletesExactlyOnce() {
        let clock = ManualUptimeClock()
        let recorder = makeRecorder(clock: clock)
        let observability = AppObservability(recorder: recorder, metricKit: NoopMetricKitReporter())

        observability.markColdLaunchStart()
        clock.advance(milliseconds: 1_200)
        observability.markFirstMeaningfulRenderIfNeeded()
        observability.markFirstMeaningfulRenderIfNeeded() // second call is a no-op

        let samples = recorder.latestSamplesSnapshot()
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.metric, .coldLaunch)
        XCTAssertEqual(samples.first?.durationMilliseconds, 1_200)
    }
}
