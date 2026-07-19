import XCTest
@testable import GamePedia

// Composition-root bridging for the 2.4 live-service foundation: account
// tracking from auth notifications, purge on account deletion, and
// breadcrumbed availability changes.
final class LiveServiceRuntimeTests: XCTestCase {

    private var directoryURL: URL!
    private var notificationCenter: NotificationCenter!
    private var breadcrumbs: OperationBreadcrumbRecorder!

    override func setUp() {
        super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("live-service-runtime-tests-\(UUID().uuidString)", isDirectory: true)
        notificationCenter = NotificationCenter()
        breadcrumbs = OperationBreadcrumbRecorder()
    }

    override func tearDown() {
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        super.tearDown()
    }

    private func makeRuntime(activityCenterEnabled: Bool = true) -> LiveServiceRuntime {
        LiveServiceRuntime(
            featureFlags: FeatureFlags(
                enableSocialLogin: true,
                enableReportFeature: true,
                enableNewReviewUI: false,
                useExperimentalSearch: false,
                enableRealtimeActivity: false,
                enableOfflineLibrarySync: true,
                enableUnifiedActivityCenter: activityCenterEnabled
            ),
            notificationCenter: notificationCenter,
            breadcrumbs: breadcrumbs,
            readStateStore: ActivityReadStateStore(directoryURL: directoryURL),
            snapshotStore: FileActivityCenterSnapshotStore(directoryURL: directoryURL)
        )
    }

    private func postSessionChange(isAuthenticated: Bool, userID: String?) {
        var userInfo: [String: Any] = [
            AuthSessionChangeUserInfoKey.isAuthenticated: isAuthenticated
        ]
        if let userID {
            userInfo[AuthSessionChangeUserInfoKey.userId] = userID
        }
        notificationCenter.post(name: .authSessionDidChange, object: nil, userInfo: userInfo)
    }

    // MARK: Session bridging

    func test_authenticatedSession_setsAccountScope() {
        let runtime = makeRuntime()
        runtime.start()

        postSessionChange(isAuthenticated: true, userID: "acct-1")
        XCTAssertEqual(runtime.currentAccountID, "acct-1")
    }

    func test_logout_clearsAccountScope() {
        let runtime = makeRuntime()
        runtime.start()
        postSessionChange(isAuthenticated: true, userID: "acct-1")

        postSessionChange(isAuthenticated: false, userID: nil)
        XCTAssertNil(runtime.currentAccountID, "guest mode must never expose an account scope")
    }

    func test_accountSwitch_replacesAccountScope() {
        let runtime = makeRuntime()
        runtime.start()
        postSessionChange(isAuthenticated: true, userID: "acct-1")

        postSessionChange(isAuthenticated: true, userID: "acct-2")
        XCTAssertEqual(runtime.currentAccountID, "acct-2")
    }

    func test_sessionTransitions_leaveBreadcrumbs() {
        let runtime = makeRuntime()
        runtime.start()

        postSessionChange(isAuthenticated: true, userID: "acct-1")
        postSessionChange(isAuthenticated: false, userID: nil)

        let codes = breadcrumbs.snapshot().map(\.code)
        XCTAssertEqual(codes, ["session_authenticated", "session_guest"])
        // Account IDs must never appear in breadcrumbs.
        for breadcrumb in breadcrumbs.snapshot() {
            XCTAssertFalse(breadcrumb.metadata.values.contains("acct-1"))
        }
    }

    // MARK: Account deletion cleanup

    func test_accountDeletion_clearsScope_andPurgesPersistedState() async {
        let runtime = makeRuntime()
        runtime.start()
        postSessionChange(isAuthenticated: true, userID: "acct-1")

        await runtime.readStateStore.advanceWatermark(
            to: Date(timeIntervalSince1970: 5_000),
            accountID: "acct-1"
        )
        await runtime.snapshotStore.persistSnapshot(
            PersistedActivityCenterSnapshot(generatedAt: Date(timeIntervalSince1970: 5_000), items: []),
            accountID: "acct-1"
        )

        runtime.handleAccountDeletionMarker(userID: "acct-1")
        await runtime.purgeAccountState(userID: "acct-1")

        XCTAssertNil(runtime.currentAccountID)
        let readState = await ActivityReadStateStore(directoryURL: directoryURL)
            .readState(accountID: "acct-1")
        XCTAssertNil(readState.readWatermark)
        let snapshot = await FileActivityCenterSnapshotStore(directoryURL: directoryURL)
            .loadSnapshot(accountID: "acct-1")
        XCTAssertNil(snapshot)
        XCTAssertTrue(breadcrumbs.snapshot().map(\.code).contains("account_state_purged"))
    }

    func test_deletionOfDifferentAccount_keepsCurrentScope() {
        let runtime = makeRuntime()
        runtime.start()
        postSessionChange(isAuthenticated: true, userID: "acct-1")

        runtime.handleAccountDeletionMarker(userID: "acct-other")
        XCTAssertEqual(runtime.currentAccountID, "acct-1")
    }

    // MARK: Availability bridging

    func test_availabilityOverride_recordsBreadcrumb_withStateCode() {
        let runtime = makeRuntime()
        runtime.start()

        runtime.availability.setOverride(.unavailable(.localOverride), for: .unifiedActivityCenter)

        let availabilityCrumbs = breadcrumbs.snapshot().filter { $0.category == .availability }
        XCTAssertEqual(availabilityCrumbs.count, 1)
        XCTAssertEqual(availabilityCrumbs[0].code, "availability_changed")
        XCTAssertEqual(
            availabilityCrumbs[0].metadata["feature"],
            LiveServiceFeature.unifiedActivityCenter.rawValue
        )
        XCTAssertEqual(availabilityCrumbs[0].metadata["state"], "unavailable_localOverride")
    }

    func test_disabledActivityCenterFlag_resolvesUnavailable() {
        let runtime = makeRuntime(activityCenterEnabled: false)
        XCTAssertEqual(
            runtime.availability.availability(for: .unifiedActivityCenter),
            .unavailable(.disabledByConfiguration)
        )
    }
}
