import XCTest
@testable import GamePedia

// The DEBUG diagnostics surface may show safe metadata only. These tests pin
// the report format to booleans/counters/enum labels and prove that no
// credential-shaped material can appear in the output.
final class DeveloperDiagnosticsTests: XCTestCase {

    private func makeSnapshot(lastSafeErrorCode: String?) -> RealtimeDiagnosticsSnapshot {
        RealtimeDiagnosticsSnapshot(
            connectionState: .waitingToReconnect(attempt: 3),
            isAuthenticated: true,
            sessionGeneration: 7,
            connectionGeneration: 4,
            subscriberCount: 2,
            reconnectCount: 3,
            deliveredEventCount: 41,
            duplicateEventCount: 1,
            staleSequenceCount: 2,
            sequenceGapCount: 1,
            decodeFailureCount: 0,
            unknownEventTypeCount: 5,
            lastEventSequence: 991,
            lastSafeErrorCode: lastSafeErrorCode
        )
    }

    private func buildReport(lastSafeErrorCode: String? = "TRANSPORT_FAILURE") -> String {
        DeveloperDiagnosticsReport.build(
            environmentName: "dev",
            apiHost: "127.0.0.1",
            isAuthenticated: true,
            accessTokenPresent: true,
            refreshTokenPresent: true,
            realtimeEnabled: false,
            realtime: makeSnapshot(lastSafeErrorCode: lastSafeErrorCode),
            metrics: [
                MetricSample(
                    metric: .authRefresh,
                    durationMilliseconds: 123.4,
                    outcome: .success,
                    endedAt: Date(timeIntervalSince1970: 1_752_800_000)
                )
            ],
            metricKit: MetricKitReceiptSummary(),
            imageDiskCacheBytes: 1_024
        )
    }

    func testReportShowsTokenPresenceAsBooleansOnly() {
        let report = buildReport()
        XCTAssertTrue(report.contains("accessTokenPresent: true"))
        XCTAssertTrue(report.contains("refreshTokenPresent: true"))
        XCTAssertTrue(report.contains("authenticated: true"))
        XCTAssertTrue(report.contains("connectionState: waitingToReconnect(attempt: 3)"))
        XCTAssertTrue(report.contains("lastSafeErrorCode: TRANSPORT_FAILURE"))
    }

    func testReportContainsNoCredentialMaterial() {
        let report = buildReport()
        XCTAssertFalse(report.contains("Bearer"), "No Authorization material may appear")
        XCTAssertFalse(report.contains("Authorization"))
        XCTAssertFalse(report.contains("@"), "No email-shaped values may appear")
        XCTAssertFalse(report.lowercased().contains("password"))
        XCTAssertFalse(report.lowercased().contains("payload:"), "Raw event payloads may never be shown")
    }

    func testHubSafeErrorCodesAreFromStaticSetOnly() async {
        // The only codes the hub ever stores are static identifiers.
        let client = MockRealtimeClient()
        client.failNextOpen(with: RealtimeClientError.transportFailure)
        let hub = RealtimeHub(
            client: client,
            reconnectPolicy: ReconnectPolicy(),
            sleeper: TestRealtimeSleeper(autoResume: true),
            jitterSource: FixedJitterSource(unitValue: 0)
        )
        let states = await hub.observeConnectionState()
        await hub.sessionDidChange(isAuthenticated: true)
        let subscription = await hub.subscribe()
        await expectState(.connected, in: states)

        let snapshot = await hub.diagnosticsSnapshot()
        withExtendedLifetime(subscription) {}
        let allowedCodes: Set<String?> = [
            nil,
            "TRANSPORT_FAILURE",
            "UNAVAILABLE_NOBACKENDCONTRACT",
            "UNAVAILABLE_FEATUREDISABLED",
            "UNAVAILABLE_UNAUTHENTICATED"
        ]
        XCTAssertTrue(allowedCodes.contains(snapshot.lastSafeErrorCode))
    }
}
