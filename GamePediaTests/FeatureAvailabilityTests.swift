import XCTest
@testable import GamePedia

// The client-side kill-switch boundary (2.4): availability resolves from
// build-time flags plus runtime overrides, announces changes, and can
// never claim a remote-config capability that does not exist.
final class FeatureAvailabilityTests: XCTestCase {

    private func makeProvider(
        activityCenter: Bool = true,
        realtime: Bool = false,
        librarySync: Bool = true,
        notificationCenter: NotificationCenter = NotificationCenter()
    ) -> LocalFeatureAvailabilityProvider {
        LocalFeatureAvailabilityProvider(
            enableUnifiedActivityCenter: activityCenter,
            enableRealtimeActivity: realtime,
            enableOfflineLibrarySync: librarySync,
            notificationCenter: notificationCenter
        )
    }

    func test_defaults_followFeatureFlags() {
        let provider = makeProvider()
        XCTAssertEqual(provider.availability(for: .unifiedActivityCenter), .available)
        XCTAssertEqual(provider.availability(for: .offlineLibrarySync), .available)
        XCTAssertEqual(provider.availability(for: .socialPushBanners), .available)
        XCTAssertEqual(
            provider.availability(for: .realtimeActivity),
            .unavailable(.disabledByConfiguration)
        )
    }

    func test_disabledFlags_resolveUnavailable() {
        let provider = makeProvider(activityCenter: false, librarySync: false)
        XCTAssertEqual(
            provider.availability(for: .unifiedActivityCenter),
            .unavailable(.disabledByConfiguration)
        )
        XCTAssertEqual(
            provider.availability(for: .offlineLibrarySync),
            .unavailable(.disabledByConfiguration)
        )
    }

    func test_realtime_neverResolvesAvailable_withoutBackendContract() {
        // Even with the flag forced on, no committed backend contract
        // exists, so the boundary must refuse to report available.
        let provider = makeProvider(realtime: true)
        XCTAssertEqual(
            provider.availability(for: .realtimeActivity),
            .unavailable(.noBackendContract)
        )
    }

    func test_override_actsAsKillSwitch_andPostsChange() {
        let notificationCenter = NotificationCenter()
        let provider = makeProvider(notificationCenter: notificationCenter)

        var receivedFeatures: [String] = []
        let observer = notificationCenter.addObserver(
            forName: .liveServiceAvailabilityDidChange,
            object: nil,
            queue: nil
        ) { notification in
            let feature = notification
                .userInfo?[LiveServiceAvailabilityUserInfoKey.feature] as? String
            receivedFeatures.append(feature ?? "missing")
        }
        defer { notificationCenter.removeObserver(observer) }

        provider.setOverride(.unavailable(.localOverride), for: .unifiedActivityCenter)
        XCTAssertEqual(
            provider.availability(for: .unifiedActivityCenter),
            .unavailable(.localOverride)
        )
        XCTAssertEqual(receivedFeatures, [LiveServiceFeature.unifiedActivityCenter.rawValue])
    }

    func test_clearingOverride_restoresDefault_andPostsChange() {
        let notificationCenter = NotificationCenter()
        let provider = makeProvider(notificationCenter: notificationCenter)
        provider.setOverride(.unavailable(.localOverride), for: .unifiedActivityCenter)

        var changeCount = 0
        let observer = notificationCenter.addObserver(
            forName: .liveServiceAvailabilityDidChange,
            object: nil,
            queue: nil
        ) { _ in changeCount += 1 }
        defer { notificationCenter.removeObserver(observer) }

        provider.setOverride(nil, for: .unifiedActivityCenter)
        XCTAssertEqual(provider.availability(for: .unifiedActivityCenter), .available)
        XCTAssertEqual(changeCount, 1)
    }

    func test_redundantOverride_doesNotPostChange() {
        let notificationCenter = NotificationCenter()
        let provider = makeProvider(notificationCenter: notificationCenter)

        var changeCount = 0
        let observer = notificationCenter.addObserver(
            forName: .liveServiceAvailabilityDidChange,
            object: nil,
            queue: nil
        ) { _ in changeCount += 1 }
        defer { notificationCenter.removeObserver(observer) }

        provider.setOverride(.available, for: .unifiedActivityCenter)
        XCTAssertEqual(changeCount, 0, "no-op overrides must not announce changes")
    }

    func test_stateCodes_areStableIdentifiers() {
        XCTAssertEqual(FeatureAvailabilityState.available.code, "available")
        XCTAssertEqual(
            FeatureAvailabilityState.unavailable(.noBackendContract).code,
            "unavailable_noBackendContract"
        )
        XCTAssertEqual(
            FeatureAvailabilityState.unavailable(.disabledByConfiguration).code,
            "unavailable_disabledByConfiguration"
        )
    }
}
