import XCTest
@testable import GamePedia

// Incident breadcrumbs must be structurally unable to leak user content:
// only short machine identifiers survive the sanitizer, the buffer is
// bounded, and the DEBUG diagnostics rendering stays credential-free.
final class OperationBreadcrumbsTests: XCTestCase {

    private final class ClockBox: @unchecked Sendable {
        private let lock = NSLock()
        private var _now: Date
        init(_ now: Date) { _now = now }
        var now: Date {
            get { lock.lock(); defer { lock.unlock() }; return _now }
            set { lock.lock(); _now = newValue; lock.unlock() }
        }
    }

    func test_record_keepsSafeCodesAndMetadata() {
        let recorder = OperationBreadcrumbRecorder()
        recorder.record(
            .activityCenter,
            code: "load_success",
            metadata: ["itemCount": "12", "unreadCount": "3"]
        )

        let snapshot = recorder.snapshot()
        XCTAssertEqual(snapshot.count, 1)
        XCTAssertEqual(snapshot[0].code, "load_success")
        XCTAssertEqual(snapshot[0].metadata["itemCount"], "12")
        XCTAssertEqual(snapshot[0].metadata["unreadCount"], "3")
    }

    func test_record_redactsEmailShapedValues() {
        let recorder = OperationBreadcrumbRecorder()
        recorder.record(.session, code: "user@example.com", metadata: ["who": "person@host.io"])

        let snapshot = recorder.snapshot()
        XCTAssertEqual(snapshot[0].code, OperationBreadcrumbRecorder.redactedPlaceholder)
        XCTAssertEqual(snapshot[0].metadata["who"], OperationBreadcrumbRecorder.redactedPlaceholder)
    }

    func test_record_redactsFreeFormAndCredentialShapedValues() {
        let recorder = OperationBreadcrumbRecorder()
        let longToken = String(repeating: "a", count: 65)
        recorder.record(
            .push,
            code: "Bearer abc123",
            metadata: [
                "token": longToken,
                "body": "hello world!",
                "base64": "abc+def/ghi=",
                "empty": ""
            ]
        )

        let breadcrumb = recorder.snapshot()[0]
        XCTAssertEqual(breadcrumb.code, OperationBreadcrumbRecorder.redactedPlaceholder)
        for value in breadcrumb.metadata.values {
            XCTAssertEqual(value, OperationBreadcrumbRecorder.redactedPlaceholder)
        }
    }

    func test_buffer_isBounded_andKeepsNewestEntries() {
        let clock = ClockBox(Date(timeIntervalSince1970: 0))
        let recorder = OperationBreadcrumbRecorder(capacity: 3, dateProvider: { clock.now })

        for index in 0..<5 {
            clock.now = Date(timeIntervalSince1970: TimeInterval(index))
            recorder.record(.sync, code: "event_\(index)")
        }

        let codes = recorder.snapshot().map(\.code)
        XCTAssertEqual(codes, ["event_2", "event_3", "event_4"])
    }

    func test_clear_emptiesBuffer() {
        let recorder = OperationBreadcrumbRecorder()
        recorder.record(.realtime, code: "reconnect")
        recorder.clear()
        XCTAssertTrue(recorder.snapshot().isEmpty)
    }

    func test_snapshot_isOldestFirst_withInjectedClock() {
        let clock = ClockBox(Date(timeIntervalSince1970: 100))
        let recorder = OperationBreadcrumbRecorder(dateProvider: { clock.now })
        recorder.record(.session, code: "first")
        clock.now = Date(timeIntervalSince1970: 200)
        recorder.record(.session, code: "second")

        let snapshot = recorder.snapshot()
        XCTAssertEqual(snapshot.map(\.code), ["first", "second"])
        XCTAssertEqual(snapshot[0].occurredAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(snapshot[1].occurredAt, Date(timeIntervalSince1970: 200))
    }

#if DEBUG
    func test_diagnosticsReport_rendersBreadcrumbs_withoutCredentialMaterial() {
        let recorder = OperationBreadcrumbRecorder()
        recorder.record(.activityCenter, code: "load_partial", metadata: ["inbox": "failed"])
        recorder.record(.push, code: "someone@example.com", metadata: ["auth": "Bearer secret token"])

        let report = DeveloperDiagnosticsReport.build(
            environmentName: "dev",
            apiHost: "127.0.0.1",
            isAuthenticated: true,
            accessTokenPresent: true,
            refreshTokenPresent: true,
            realtimeEnabled: false,
            realtime: RealtimeDiagnosticsSnapshot(
                connectionState: .unavailable(.featureDisabled),
                isAuthenticated: false,
                sessionGeneration: 0,
                connectionGeneration: 0,
                subscriberCount: 0,
                reconnectCount: 0,
                deliveredEventCount: 0,
                duplicateEventCount: 0,
                staleSequenceCount: 0,
                sequenceGapCount: 0,
                decodeFailureCount: 0,
                unknownEventTypeCount: 0,
                lastEventSequence: nil,
                lastSafeErrorCode: nil
            ),
            librarySyncEnabled: false,
            librarySync: nil,
            metrics: [],
            metricKit: MetricKitReceiptSummary(),
            imageDiskCacheBytes: nil,
            featureAvailability: [
                (feature: "unifiedActivityCenter", state: "available")
            ],
            breadcrumbs: recorder.snapshot()
        )

        XCTAssertTrue(report.contains("load_partial"))
        XCTAssertTrue(report.contains("unifiedActivityCenter: available"))
        XCTAssertFalse(report.contains("@"), "sanitizer must keep email-shaped values out of diagnostics")
        XCTAssertFalse(report.contains("Bearer"))
        XCTAssertTrue(report.contains(OperationBreadcrumbRecorder.redactedPlaceholder))
    }
#endif
}
