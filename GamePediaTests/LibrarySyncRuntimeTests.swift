import XCTest
@testable import GamePedia

// MARK: - LibrarySyncRuntime composition and bridging

final class LibrarySyncRuntimeTests: XCTestCase {

    private final class MockConnectivityObserver: ConnectivityObserving {
        private(set) var handler: (@Sendable (Bool) -> Void)?
        func startObserving(onChange: @escaping @Sendable (Bool) -> Void) {
            handler = onChange
        }
        func stopObserving() {
            handler = nil
        }
    }

    func testFeatureFlagIsEnabledInEveryEnvironment() {
        for environment in [APIEnvironment.dev, .staging, .production] {
            XCTAssertTrue(
                FeatureFlags.defaults(for: environment).enableOfflineLibrarySync,
                "offline library sync replays only committed REST mutations and ships enabled; \(environment) must expose the kill-switch as on"
            )
        }
    }

    func testDisabledFlagExposesNoRouterAndRevertsToDirectPath() {
        let flags = FeatureFlags(
            enableSocialLogin: true,
            enableReportFeature: true,
            enableNewReviewUI: false,
            useExperimentalSearch: false,
            enableRealtimeActivity: false,
            enableOfflineLibrarySync: false,
            enableUnifiedActivityCenter: true
        )
        let runtime = LibrarySyncRuntime(
            featureFlags: flags,
            connectivityObserver: MockConnectivityObserver(),
            notificationCenter: NotificationCenter()
        )
        XCTAssertFalse(runtime.isEnabled)
        XCTAssertNil(runtime.engine)
        XCTAssertNil(runtime.mutationRouter)
        runtime.start()
    }

    func testRuntimeBridgesAuthSessionNotificationIntoEngine() async throws {
        let center = NotificationCenter()
        let flags = FeatureFlags.defaults(for: .dev)
        let transport = MockLibrarySyncTransport()
        let store = InMemorySyncOperationStore()
        let runtime = LibrarySyncRuntime(
            featureFlags: flags,
            store: store,
            transport: transport,
            connectivityObserver: MockConnectivityObserver(),
            notificationCenter: center,
            jitterSource: FixedJitterSource(unitValue: 0),
            sleeper: TestRealtimeSleeper(autoResume: true)
        )
        runtime.start()
        let engine = try XCTUnwrap(runtime.engine)

        // Before any session event, enqueues are rejected (no account).
        let rejected = await engine.enqueueFavoriteChange(gameID: "1", isFavorite: true)
        XCTAssertFalse(rejected)

        // The bridged authenticated notification activates the account.
        let activated = notificationExpectation(.librarySyncQueueDidChange, center: center)
        center.post(
            name: .authSessionDidChange,
            object: nil,
            userInfo: [
                AuthSessionChangeUserInfoKey.isAuthenticated: true,
                AuthSessionChangeUserInfoKey.userId: "user-a"
            ]
        )
        await fulfillment(of: [activated], timeout: 10)

        let success = notificationExpectation(.favoriteDidChange, center: center)
        let accepted = await engine.enqueueFavoriteChange(gameID: "1", isFavorite: true)
        XCTAssertTrue(accepted)
        await fulfillment(of: [success], timeout: 10)
    }

    func testRuntimeBridgesAccountDeletionNotificationIntoPurge() async throws {
        let center = NotificationCenter()
        let transport = MockLibrarySyncTransport()
        transport.behavior = { _, _ in .hold }
        let store = InMemorySyncOperationStore()
        let runtime = LibrarySyncRuntime(
            featureFlags: FeatureFlags.defaults(for: .dev),
            store: store,
            transport: transport,
            connectivityObserver: MockConnectivityObserver(),
            notificationCenter: center,
            jitterSource: FixedJitterSource(unitValue: 0),
            sleeper: TestRealtimeSleeper(autoResume: true)
        )
        runtime.start()
        let engine = try XCTUnwrap(runtime.engine)

        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")
        let transportCalled = expectation(description: "operation in flight")
        transport.onCall = { _ in transportCalled.fulfill() }
        _ = await engine.enqueueFavoriteChange(gameID: "5", isFavorite: true)
        await fulfillment(of: [transportCalled], timeout: 10)
        XCTAssertEqual(store.storedOperations(accountID: "user-a").count, 1)

        // Deletion signal purges durable state. The engine method itself is
        // already covered; here we prove the notification bridge works by
        // waiting for the queue signal the purge emits.
        let purged = notificationExpectation(.librarySyncQueueDidChange, center: center) { notification in
            notification.userInfo?[LibrarySyncQueueUserInfoKey.pendingCount] as? Int == 0
        }
        center.post(
            name: .authAccountDidDelete,
            object: nil,
            userInfo: [AuthSessionChangeUserInfoKey.userId: "user-a"]
        )
        await fulfillment(of: [purged], timeout: 10)
        XCTAssertTrue(store.storedOperations(accountID: "user-a").isEmpty)
        transport.resolveHeldWithDefaultSuccess(index: 0)
    }

    func testConnectivityRestoredUnparksAndDrains() async throws {
        let center = NotificationCenter()
        let connectivity = MockConnectivityObserver()
        let transport = MockLibrarySyncTransport()
        // The single-attempt budget parks the entity after one transient
        // failure; the next attempt (post-unpark) succeeds.
        transport.behavior = { _, index in
            index == 0 ? .failure(FavoriteError.network) : .success(nil)
        }
        var configuration = LibrarySyncEngine.Configuration()
        configuration.maxAutomaticAttempts = 1
        let store = InMemorySyncOperationStore()
        let runtime = LibrarySyncRuntime(
            featureFlags: FeatureFlags.defaults(for: .dev),
            store: store,
            transport: transport,
            connectivityObserver: connectivity,
            notificationCenter: center,
            engineConfiguration: configuration,
            jitterSource: FixedJitterSource(unitValue: 0),
            sleeper: TestRealtimeSleeper(autoResume: true)
        )
        runtime.start()
        let engine = try XCTUnwrap(runtime.engine)

        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")
        let parked = notificationExpectation(.librarySyncQueueDidChange, center: center) { notification in
            notification.userInfo?[LibrarySyncQueueUserInfoKey.parkedCount] as? Int == 1
        }
        _ = await engine.enqueueFavoriteChange(gameID: "5", isFavorite: true)
        await fulfillment(of: [parked], timeout: 10)

        // Connectivity restored → un-park → drain → success.
        let replayed = notificationExpectation(.favoriteDidChange, center: center)
        connectivity.handler?(true)
        await fulfillment(of: [replayed], timeout: 10)
    }
}
