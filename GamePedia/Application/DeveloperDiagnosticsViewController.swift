import UIKit
import Kingfisher

#if DEBUG

// MARK: - Developer diagnostics (DEBUG only)
//
// Extends the existing DEBUG environment menu with a read-only diagnostics
// screen. Shows safe metadata only: environment names, booleans, counters,
// generations, static error codes, durations, and cache sizes.
//
// Never shown and never compiled into Release. Never displays or copies:
// raw tokens, passwords, identity tokens, Authorization headers, email
// addresses, request bodies, or realtime payloads.

struct DeveloperDiagnosticsReport {

    static func build(
        environmentName: String,
        apiHost: String,
        isAuthenticated: Bool,
        accessTokenPresent: Bool,
        refreshTokenPresent: Bool,
        realtimeEnabled: Bool,
        realtime: RealtimeDiagnosticsSnapshot,
        librarySyncEnabled: Bool,
        librarySync: LibrarySyncDiagnosticsSnapshot?,
        metrics: [MetricSample],
        metricKit: MetricKitReceiptSummary,
        imageDiskCacheBytes: UInt?
    ) -> String {
        let timestampFormatter = ISO8601DateFormatter()

        var lines: [String] = []
        lines.append("== Environment ==")
        lines.append("environment: \(environmentName)")
        lines.append("apiHost: \(apiHost)")
        lines.append("")
        lines.append("== Session (booleans only) ==")
        lines.append("authenticated: \(isAuthenticated)")
        lines.append("accessTokenPresent: \(accessTokenPresent)")
        lines.append("refreshTokenPresent: \(refreshTokenPresent)")
        lines.append("")
        lines.append("== Realtime ==")
        lines.append("featureEnabled: \(realtimeEnabled)")
        lines.append("connectionState: \(realtime.connectionStateDescription)")
        lines.append("sessionGeneration: \(realtime.sessionGeneration)")
        lines.append("connectionGeneration: \(realtime.connectionGeneration)")
        lines.append("subscriberCount: \(realtime.subscriberCount)")
        lines.append("reconnectCount: \(realtime.reconnectCount)")
        lines.append("deliveredEventCount: \(realtime.deliveredEventCount)")
        lines.append("duplicateEventCount: \(realtime.duplicateEventCount)")
        lines.append("staleSequenceCount: \(realtime.staleSequenceCount)")
        lines.append("sequenceGapCount: \(realtime.sequenceGapCount)")
        lines.append("decodeFailureCount: \(realtime.decodeFailureCount)")
        lines.append("unknownEventTypeCount: \(realtime.unknownEventTypeCount)")
        lines.append("lastEventSequence: \(realtime.lastEventSequence.map(String.init) ?? "none")")
        lines.append("lastSafeErrorCode: \(realtime.lastSafeErrorCode ?? "none")")
        lines.append("")
        lines.append("== Library sync (offline-first queue) ==")
        lines.append("featureEnabled: \(librarySyncEnabled)")
        if let librarySync {
            lines.append("hasActiveAccount: \(librarySync.hasActiveAccount)")
            lines.append("sessionGeneration: \(librarySync.sessionGeneration)")
            lines.append("pendingOperationCount: \(librarySync.pendingOperationCount)")
            lines.append("parkedOperationCount: \(librarySync.parkedOperationCount)")
            lines.append("inFlightEntityCount: \(librarySync.inFlightEntityCount)")
            lines.append("completedOperationCount: \(librarySync.completedOperationCount)")
            lines.append("permanentlyFailedOperationCount: \(librarySync.permanentlyFailedOperationCount)")
            lines.append("recoveredFromCorruptedStore: \(librarySync.recoveredFromCorruptedStore)")
            lines.append("isBlockedOnAuth: \(librarySync.isBlockedOnAuth)")
            lines.append("lastSafeErrorCode: \(librarySync.lastSafeErrorCode ?? "none")")
        } else {
            lines.append("engine: disabled")
        }
        lines.append("")
        lines.append("== Local metrics (this process, simulator/device local) ==")
        if metrics.isEmpty {
            lines.append("no samples yet")
        }
        for sample in metrics {
            lines.append(
                "\(sample.metric.rawValue): " +
                "\(String(format: "%.1f", sample.durationMilliseconds))ms " +
                "outcome=\(sample.outcome.rawValue) " +
                "at=\(timestampFormatter.string(from: sample.endedAt))"
            )
        }
        lines.append("")
        lines.append("== MetricKit (counts only) ==")
        lines.append("metricPayloadCount: \(metricKit.metricPayloadCount)")
        lines.append("diagnosticPayloadCount: \(metricKit.diagnosticPayloadCount)")
        lines.append(
            "lastMetricPayloadAt: " +
            (metricKit.lastMetricPayloadAt.map(timestampFormatter.string(from:)) ?? "none")
        )
        lines.append("")
        lines.append("== Caches ==")
        lines.append(
            "imageDiskCacheBytes: " +
            (imageDiskCacheBytes.map(String.init) ?? "unknown")
        )
        return lines.joined(separator: "\n")
    }
}

final class DeveloperDiagnosticsViewController: UIViewController {
    private let textView = UITextView()
    private let hub: RealtimeHub

    init(hub: RealtimeHub = RealtimeRuntime.shared.hub) {
        self.hub = hub
        super.init(nibName: nil, bundle: nil)
        title = "Developer Diagnostics"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gpBackground
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = .clear
        textView.textColor = .gpTextPrimary
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(reload)
        )
        reload()
    }

    @objc
    private func reload() {
        let hub = self.hub
        Task { [weak self] in
            let realtimeSnapshot = await hub.diagnosticsSnapshot()
            let librarySyncSnapshot = await LibrarySyncRuntime.shared.engine?.diagnosticsSnapshot()
            let diskCacheBytes: UInt? = await withCheckedContinuation { continuation in
                ImageCache.default.calculateDiskStorageSize { result in
                    continuation.resume(returning: try? result.get())
                }
            }
            await MainActor.run {
                guard let self else { return }
                let tokenStore = KeychainTokenStore()
                self.textView.text = DeveloperDiagnosticsReport.build(
                    environmentName: AppConfig.apiEnvironment.rawValue,
                    apiHost: AppConfig.apiHost,
                    isAuthenticated: APIClient.shared.userAuthToken != nil,
                    accessTokenPresent: APIClient.shared.userAuthToken != nil,
                    refreshTokenPresent: tokenStore.fetchRefreshToken() != nil,
                    realtimeEnabled: RealtimeRuntime.shared.isRealtimeEnabled,
                    realtime: realtimeSnapshot,
                    librarySyncEnabled: LibrarySyncRuntime.shared.isEnabled,
                    librarySync: librarySyncSnapshot,
                    metrics: AppObservability.shared.recorder.latestSamplesSnapshot(),
                    metricKit: AppObservability.shared.metricKit.receiptSummary(),
                    imageDiskCacheBytes: diskCacheBytes
                )
            }
        }
    }
}
#endif
