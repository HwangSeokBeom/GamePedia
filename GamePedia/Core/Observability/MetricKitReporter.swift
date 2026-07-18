import Foundation
#if canImport(MetricKit)
import MetricKit
#endif

// MARK: - MetricKitReporting
// MetricKit subscription with strictly privacy-safe bookkeeping: the reporter
// records only payload counts and receipt timestamps. Raw MXMetricPayload /
// MXDiagnosticPayload contents are never logged, persisted, or displayed.
// Payloads are aggregate OS-provided data and arrive on a system schedule;
// on the simulator MetricKit typically delivers nothing — registration is
// still safe and must never crash.

struct MetricKitReceiptSummary: Equatable {
    var metricPayloadCount: Int = 0
    var diagnosticPayloadCount: Int = 0
    var lastMetricPayloadAt: Date?
    var lastDiagnosticPayloadAt: Date?
}

protocol MetricKitReporting: AnyObject {
    var isActive: Bool { get }
    func start()
    func stop()
    func receiptSummary() -> MetricKitReceiptSummary
}

// Test double / unsupported-environment fallback.
final class NoopMetricKitReporter: MetricKitReporting {
    private(set) var isActive = false
    func start() {}
    func stop() {}
    func receiptSummary() -> MetricKitReceiptSummary { MetricKitReceiptSummary() }
}

#if canImport(MetricKit)
final class MetricKitReporter: NSObject, MetricKitReporting {
    private let lock = NSLock()
    private let dateProvider: () -> Date
    private var summary = MetricKitReceiptSummary()
    private var started = false

    init(dateProvider: @escaping () -> Date = Date.init) {
        self.dateProvider = dateProvider
        super.init()
    }

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return started
    }

    func start() {
        lock.lock()
        let alreadyStarted = started
        started = true
        lock.unlock()
        guard !alreadyStarted else { return }
        MXMetricManager.shared.add(self)
        print("[MetricKit] subscriberRegistered=true")
    }

    func stop() {
        lock.lock()
        let wasStarted = started
        started = false
        lock.unlock()
        guard wasStarted else { return }
        MXMetricManager.shared.remove(self)
    }

    func receiptSummary() -> MetricKitReceiptSummary {
        lock.lock()
        defer { lock.unlock() }
        return summary
    }
}

extension MetricKitReporter: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        lock.lock()
        summary.metricPayloadCount += payloads.count
        summary.lastMetricPayloadAt = dateProvider()
        lock.unlock()
        // Count only — payload contents are never logged.
        print("[MetricKit] metricPayloadsReceived=\(payloads.count)")
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        lock.lock()
        summary.diagnosticPayloadCount += payloads.count
        summary.lastDiagnosticPayloadAt = dateProvider()
        lock.unlock()
        // Count only — crash/hang diagnostics contents are never logged.
        print("[MetricKit] diagnosticPayloadsReceived=\(payloads.count)")
    }
}
#endif
