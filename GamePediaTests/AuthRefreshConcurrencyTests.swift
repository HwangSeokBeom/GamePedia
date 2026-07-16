import Combine
import XCTest
@testable import GamePedia

final class AuthRefreshConcurrencyTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        RefreshURLProtocol.reset()
    }

    override func tearDown() {
        cancellables.removeAll()
        RefreshURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Single-flight refresh

    func testConcurrentRefreshCallsShareOneRotatingRequest() throws {
        let tokenStore = InMemoryTokenStore(refreshToken: "old-refresh")
        let userStore = TestUserSessionStore()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefreshURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let apiClient = APIClient(baseURL: URL(string: "https://example.test")!, session: session)
        let remote = AuthRemoteDataSource(
            baseURL: URL(string: "https://example.test")!,
            tokenStore: tokenStore,
            urlSession: session
        )
        let repository = DefaultAuthRepository(
            authRemoteDataSource: remote,
            tokenStore: tokenStore,
            userSessionStore: userStore,
            apiClient: apiClient
        )

        RefreshURLProtocol.responseDelay = 0.1
        RefreshURLProtocol.responseData = Self.authResponseJSON(
            accessToken: "new-access",
            refreshToken: "new-refresh"
        )

        let first = expectation(description: "first refresh")
        let second = expectation(description: "second refresh")
        var receivedRefreshTokens: [String] = []
        let resultLock = NSLock()

        repository.refreshSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("First refresh failed: \(error)")
                    }
                },
                receiveValue: { session in
                    resultLock.lock()
                    receivedRefreshTokens.append(session.refreshToken)
                    resultLock.unlock()
                    first.fulfill()
                }
            )
            .store(in: &cancellables)

        repository.refreshSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Second refresh failed: \(error)")
                    }
                },
                receiveValue: { session in
                    resultLock.lock()
                    receivedRefreshTokens.append(session.refreshToken)
                    resultLock.unlock()
                    second.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [first, second], timeout: 2)

        XCTAssertEqual(RefreshURLProtocol.requestCount, 1)
        XCTAssertEqual(RefreshURLProtocol.refreshTokens, ["old-refresh"])
        XCTAssertEqual(receivedRefreshTokens, ["new-refresh", "new-refresh"])
        XCTAssertEqual(tokenStore.fetchRefreshToken(), "new-refresh")
        XCTAssertEqual(tokenStore.fetchAccessToken(), "new-access")
        XCTAssertEqual(apiClient.userAuthToken, "new-access")
        XCTAssertEqual(userStore.fetchUser()?.id, "00000000-0000-0000-0000-000000000001")
    }

    func testSequentialRefreshRotatesRefreshTokenWithSingleFlightPerCall() {
        let context = makeContext(initialRefreshToken: "old-refresh")
        defer { context.session.invalidateAndCancel() }

        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "new-access", refreshToken: "new-refresh")
        )

        let firstRefresh = expectation(description: "first refresh value")
        context.repository.refreshSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("First refresh failed: \(error)")
                    }
                },
                receiveValue: { _ in firstRefresh.fulfill() }
            )
            .store(in: &cancellables)
        wait(for: [firstRefresh], timeout: 2)

        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "newer-access", refreshToken: "newer-refresh")
        )

        let secondRefresh = expectation(description: "second refresh value")
        context.repository.refreshSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Second refresh failed: \(error)")
                    }
                },
                receiveValue: { _ in secondRefresh.fulfill() }
            )
            .store(in: &cancellables)
        wait(for: [secondRefresh], timeout: 2)

        XCTAssertEqual(RefreshURLProtocol.requestCount, 2)
        XCTAssertEqual(RefreshURLProtocol.refreshTokens, ["old-refresh", "new-refresh"])
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "newer-refresh")
        XCTAssertEqual(context.tokenStore.fetchAccessToken(), "newer-access")
        XCTAssertEqual(context.apiClient.userAuthToken, "newer-access")
    }

    // MARK: - Fresh authentication supersedes in-flight refresh

    func testLoginSupersedesOlderRefreshSuccess() {
        assertFreshAuthenticationSupersedesBlockedRefreshCommit(.login)
    }

    func testSignUpSupersedesOlderRefresh() {
        assertFreshAuthenticationSupersedesBlockedRefreshCommit(.signUp)
    }

    func testAppleLoginSupersedesOlderRefresh() {
        assertFreshAuthenticationSupersedesBlockedRefreshCommit(.apple)
    }

    func testGoogleLoginSupersedesOlderRefresh() {
        assertFreshAuthenticationSupersedesBlockedRefreshCommit(.google)
    }

    func testLoginSupersedesOlderRefreshFailure() {
        let resolveEntered = DispatchSemaphore(value: 0)
        let releaseResolve = DispatchSemaphore(value: 0)
        let resolveFinished = DispatchSemaphore(value: 0)
        let context = makeContext(
            initialRefreshToken: "old-refresh",
            refreshWillResolve: {
                resolveEntered.signal()
                _ = releaseResolve.wait(timeout: .now() + 4)
            },
            refreshDidResolve: { resolveFinished.signal() }
        )
        defer { context.session.invalidateAndCancel() }

        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 401,
            data: Data(
                """
                {"success": false, "data": null, "error": {"code": "UNAUTHORIZED", "message": "expired"}}
                """.utf8
            )
        )
        RefreshURLProtocol.routeResponses["auth/login"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "login-access", refreshToken: "login-refresh")
        )

        let refreshSuperseded = expectation(description: "refresh superseded")
        context.repository.refreshSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(.unauthorized) = completion {
                        refreshSuperseded.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Superseded refresh must not deliver a session.")
                }
            )
            .store(in: &cancellables)

        // The refresh failure has arrived and is parked right before the
        // repository resolves it.
        XCTAssertEqual(resolveEntered.wait(timeout: .now() + 2), .success)

        let loggedIn = expectation(description: "login completed")
        context.repository.login(email: "fixture@example.test", password: "password-123")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Login failed: \(error)")
                    }
                },
                receiveValue: { _ in loggedIn.fulfill() }
            )
            .store(in: &cancellables)

        wait(for: [loggedIn, refreshSuperseded], timeout: 2)

        let unauthenticatedNotifications = SessionChangeCounter(authenticated: false)
        defer { unauthenticatedNotifications.stop() }

        releaseResolve.signal()
        XCTAssertEqual(resolveFinished.wait(timeout: .now() + 2), .success)

        XCTAssertEqual(unauthenticatedNotifications.count, 0)
        XCTAssertEqual(context.tokenStore.fetchAccessToken(), "login-access")
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "login-refresh")
        XCTAssertEqual(context.apiClient.userAuthToken, "login-access")
        XCTAssertNotNil(context.userStore.fetchUser())
    }

    func testStaleRefreshCannotOverwriteNewerPersistedTokens() {
        let commitEntered = DispatchSemaphore(value: 0)
        let releaseCommit = DispatchSemaphore(value: 0)
        let commitAttemptFinished = DispatchSemaphore(value: 0)
        let context = makeContext(
            initialRefreshToken: "old-refresh",
            refreshWillResolve: {
                commitEntered.signal()
                _ = releaseCommit.wait(timeout: .now() + 4)
            },
            refreshDidResolve: { commitAttemptFinished.signal() }
        )
        defer { context.session.invalidateAndCancel() }

        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "stale-access", refreshToken: "stale-refresh")
        )
        RefreshURLProtocol.routeResponses["auth/login"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "login-access", refreshToken: "login-refresh")
        )

        let refreshInvalidated = expectation(description: "refresh invalidated")
        context.repository.refreshSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(.unauthorized) = completion {
                        refreshInvalidated.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Stale refresh must not deliver a session.")
                }
            )
            .store(in: &cancellables)

        XCTAssertEqual(commitEntered.wait(timeout: .now() + 2), .success)

        // Logout then a fresh login while the decoded stale refresh is parked
        // right before its commit: the stale commit must lose to both.
        context.repository.logout()

        let loggedIn = expectation(description: "login completed")
        context.repository.login(email: "fixture@example.test", password: "password-123")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Login failed: \(error)")
                    }
                },
                receiveValue: { _ in loggedIn.fulfill() }
            )
            .store(in: &cancellables)
        wait(for: [loggedIn, refreshInvalidated], timeout: 2)

        releaseCommit.signal()
        XCTAssertEqual(commitAttemptFinished.wait(timeout: .now() + 2), .success)

        XCTAssertEqual(context.tokenStore.fetchAccessToken(), "login-access")
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "login-refresh")
        XCTAssertEqual(context.apiClient.userAuthToken, "login-access")
        XCTAssertNotNil(context.userStore.fetchUser())
    }

    // MARK: - Logout / account deletion invalidate in-flight refresh

    func testLogoutCancelsInFlightRefreshBeforeItCanRestoreSession() {
        let tokenStore = InMemoryTokenStore(refreshToken: "old-refresh")
        let userStore = TestUserSessionStore()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefreshURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let apiClient = APIClient(baseURL: URL(string: "https://example.test")!, session: session)
        let remote = AuthRemoteDataSource(
            baseURL: URL(string: "https://example.test")!,
            tokenStore: tokenStore,
            urlSession: session
        )
        let repository = DefaultAuthRepository(
            authRemoteDataSource: remote,
            tokenStore: tokenStore,
            userSessionStore: userStore,
            apiClient: apiClient
        )

        RefreshURLProtocol.responseDelay = 0.2
        RefreshURLProtocol.responseData = Self.authResponseJSON(
            accessToken: "new-access",
            refreshToken: "new-refresh"
        )

        let cancelled = expectation(description: "refresh cancelled")
        repository.refreshSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(.unauthorized) = completion {
                        cancelled.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("A cancelled refresh must not restore a session.")
                }
            )
            .store(in: &cancellables)

        repository.logout()
        wait(for: [cancelled], timeout: 1)

        XCTAssertNil(tokenStore.fetchAccessToken())
        XCTAssertNil(tokenStore.fetchRefreshToken())
        XCTAssertNil(apiClient.userAuthToken)
        XCTAssertNil(userStore.fetchUser())
    }

    func testLogoutInvalidatesDecodedRefreshBeforeCommit() {
        assertSessionInvalidationWinsDecodedRefresh(useAccountDeletion: false)
    }

    func testAccountDeletionInvalidatesDecodedRefreshBeforeCommit() {
        assertSessionInvalidationWinsDecodedRefresh(useAccountDeletion: true)
    }

    // MARK: - Waiter cancellation

    func testCancellingOneWaiterKeepsSharedRefreshAliveForRemainingWaiters() {
        let context = makeContext(initialRefreshToken: "old-refresh")
        defer { context.session.invalidateAndCancel() }

        RefreshURLProtocol.responseDelay = 0.2
        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "new-access", refreshToken: "new-refresh")
        )

        let firstWaiter = context.repository.refreshSession()
            .sink(
                receiveCompletion: { _ in
                    XCTFail("A cancelled waiter must not receive a completion.")
                },
                receiveValue: { _ in
                    XCTFail("A cancelled waiter must not receive a session.")
                }
            )

        let secondWaiterReceived = expectation(description: "remaining waiter receives the shared result")
        context.repository.refreshSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Remaining waiter failed: \(error)")
                    }
                },
                receiveValue: { session in
                    XCTAssertEqual(session.refreshToken, "new-refresh")
                    secondWaiterReceived.fulfill()
                }
            )
            .store(in: &cancellables)

        firstWaiter.cancel()

        wait(for: [secondWaiterReceived], timeout: 2)

        XCTAssertEqual(RefreshURLProtocol.requestCount, 1)
        XCTAssertEqual(RefreshURLProtocol.refreshTokens, ["old-refresh"])
        XCTAssertEqual(context.tokenStore.fetchAccessToken(), "new-access")
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "new-refresh")
        XCTAssertEqual(context.apiClient.userAuthToken, "new-access")
    }

    func testLastWaiterCancellationCancelsRequestAndLeavesSessionUntouched() {
        let context = makeContext(initialRefreshToken: "old-refresh")
        defer { context.session.invalidateAndCancel() }

        // The stub would only answer after 2 seconds, so any stopLoading
        // observed inside the 0.8 second window below can only come from the
        // abandoned flight cancelling its underlying URLSession task.
        RefreshURLProtocol.responseDelay = 2
        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "abandoned-access", refreshToken: "abandoned-refresh")
        )

        let authenticatedNotifications = SessionChangeCounter(authenticated: true)
        defer { authenticatedNotifications.stop() }

        // Cancelling immediately can beat the URLSession task's own startup,
        // in which case the protocol never starts loading at all. Wait until
        // the request is genuinely in flight so the test exercises the
        // cancellation of live provider work.
        let requestStarted = expectation(description: "refresh request started")
        RefreshURLProtocol.signalNextStartLoading { requestStarted.fulfill() }

        let noDelivery = expectation(description: "abandoned waiter receives nothing")
        noDelivery.isInverted = true
        let onlyWaiter = context.repository.refreshSession()
            .sink(
                receiveCompletion: { _ in noDelivery.fulfill() },
                receiveValue: { _ in noDelivery.fulfill() }
            )

        wait(for: [requestStarted], timeout: 2)

        onlyWaiter.cancel()

        wait(for: [noDelivery], timeout: 0.8)

        XCTAssertEqual(RefreshURLProtocol.stopLoadingCount, 1, "Cancelling the last waiter must cancel the underlying request.")
        XCTAssertNil(context.tokenStore.fetchAccessToken())
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "old-refresh")
        XCTAssertNil(context.apiClient.userAuthToken)
        XCTAssertNil(context.userStore.fetchUser())
        XCTAssertEqual(authenticatedNotifications.count, 0)

        // The abandoned flight was detached, so a later refresh starts a new
        // request with the still-unconsumed refresh token.
        RefreshURLProtocol.responseDelay = 0
        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "new-access", refreshToken: "new-refresh")
        )

        let refreshed = expectation(description: "fresh refresh succeeds")
        context.repository.refreshSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Fresh refresh failed: \(error)")
                    }
                },
                receiveValue: { _ in refreshed.fulfill() }
            )
            .store(in: &cancellables)
        wait(for: [refreshed], timeout: 2)

        XCTAssertEqual(RefreshURLProtocol.requestCount, 2)
        XCTAssertEqual(RefreshURLProtocol.refreshTokens, ["old-refresh", "old-refresh"])
        XCTAssertEqual(context.tokenStore.fetchAccessToken(), "new-access")
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "new-refresh")
    }

    func testSessionSupersededDuringStartupSuppressesAbandonedRequest() {
        let startupParked = DispatchSemaphore(value: 0)
        let releaseStartup = DispatchSemaphore(value: 0)
        let parkFirstStartup = ParkOnce(parked: startupParked, release: releaseStartup)
        let context = makeContext(
            initialRefreshToken: "old-refresh",
            refreshUpstreamWillStart: { parkFirstStartup.parkIfFirst() }
        )
        defer { context.session.invalidateAndCancel() }

        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "abandoned-access", refreshToken: "abandoned-refresh")
        )
        RefreshURLProtocol.routeResponses["auth/login"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "login-access", refreshToken: "login-refresh")
        )

        // The first subscriber creates the flight and parks right before
        // the provider request would be installed, leaving the flight in
        // its starting state.
        let backgroundCancellables = LockedCancellableStore()
        let superseded = expectation(description: "parked subscriber superseded")
        DispatchQueue.global().async {
            let cancellable = context.repository.refreshSession()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(.unauthorized) = completion {
                            superseded.fulfill()
                        }
                    },
                    receiveValue: { _ in
                        XCTFail("A superseded refresh must not deliver a session.")
                    }
                )
            backgroundCancellables.store(cancellable)
        }
        XCTAssertEqual(startupParked.wait(timeout: .now() + 2), .success)

        // A fresh login supersedes the starting flight while it is parked.
        let loggedIn = expectation(description: "login completed")
        context.repository.login(email: "fixture@example.test", password: "password-123")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Login failed: \(error)")
                    }
                },
                receiveValue: { _ in loggedIn.fulfill() }
            )
            .store(in: &cancellables)
        wait(for: [loggedIn], timeout: 2)

        releaseStartup.signal()
        wait(for: [superseded], timeout: 2)

        // The superseded flight never started a provider refresh request,
        // so nothing could have consumed or rotated the refresh token
        // behind the fresh login session.
        XCTAssertEqual(RefreshURLProtocol.refreshTokens, [])
        XCTAssertEqual(context.tokenStore.fetchAccessToken(), "login-access")
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "login-refresh")
        XCTAssertEqual(context.apiClient.userAuthToken, "login-access")

        // The slot was released when the suppressed startup resolved: a
        // fresh refresh starts exactly one request with the login-rotated
        // token instead of reusing the abandoned flight.
        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "new-access", refreshToken: "new-refresh")
        )
        let refreshed = expectation(description: "fresh refresh succeeds")
        context.repository.refreshSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Fresh refresh failed: \(error)")
                    }
                },
                receiveValue: { _ in refreshed.fulfill() }
            )
            .store(in: &cancellables)
        wait(for: [refreshed], timeout: 2)

        XCTAssertEqual(RefreshURLProtocol.refreshTokens, ["login-refresh"])
        XCTAssertEqual(context.tokenStore.fetchAccessToken(), "new-access")
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "new-refresh")
    }

    // MARK: - Subscription-driven flight ownership

    func testRefreshPublisherWithoutSubscriptionStartsNoRequestAndDoesNotOccupySlot() {
        let startupLock = NSLock()
        var startupCount = 0
        let context = makeContext(
            initialRefreshToken: "old-refresh",
            refreshUpstreamWillStart: {
                startupLock.lock()
                startupCount += 1
                startupLock.unlock()
            }
        )
        defer { context.session.invalidateAndCancel() }

        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "new-access", refreshToken: "new-refresh")
        )

        // Obtain a refresh publisher but never subscribe to it. Creating the
        // publisher alone must not begin startup or start a provider request.
        let unsubscribedPublisher = context.repository.refreshSession()

        startupLock.lock()
        XCTAssertEqual(startupCount, 0, "An unsubscribed refresh publisher must not begin startup.")
        startupLock.unlock()
        XCTAssertEqual(RefreshURLProtocol.requestCount, 0)

        // The shared-flight slot must still be free: an actual subscriber
        // creates its own flight and completes with exactly one request. If
        // the unsubscribed publisher had occupied the slot with a flight
        // that never starts, this refresh would join it and never complete.
        let refreshed = expectation(description: "subscribed refresh succeeds")
        context.repository.refreshSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Subscribed refresh failed: \(error)")
                    }
                },
                receiveValue: { _ in refreshed.fulfill() }
            )
            .store(in: &cancellables)
        wait(for: [refreshed], timeout: 2)

        startupLock.lock()
        XCTAssertEqual(startupCount, 1, "Exactly one startup may run, owned by the actual subscriber.")
        startupLock.unlock()
        XCTAssertEqual(RefreshURLProtocol.requestCount, 1)
        XCTAssertEqual(RefreshURLProtocol.refreshTokens, ["old-refresh"])
        XCTAssertEqual(context.tokenStore.fetchAccessToken(), "new-access")
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "new-refresh")
        withExtendedLifetime(unsubscribedPublisher) {}
    }

    func testDelayedSubscriberIsNotFailedByAnotherSubscriberCancellation() {
        let context = makeContext(initialRefreshToken: "old-refresh")
        defer { context.session.invalidateAndCancel() }

        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "new-access", refreshToken: "new-refresh")
        )

        // Caller A obtains its refresh publisher first but delays its
        // subscription past another caller's entire subscribe/cancel cycle.
        let delayedPublisher = context.repository.refreshSession()

        // Caller B subscribes (creating and owning its own flight) and then
        // cancels as that flight's only waiter, abandoning it.
        RefreshURLProtocol.responseDelay = 5
        let requestStarted = expectation(description: "B's refresh request started")
        RefreshURLProtocol.signalNextStartLoading { requestStarted.fulfill() }
        let cancelledWaiter = context.repository.refreshSession()
            .sink(
                receiveCompletion: { _ in
                    XCTFail("A cancelled waiter must not receive a completion.")
                },
                receiveValue: { _ in
                    XCTFail("A cancelled waiter must not receive a session.")
                }
            )
        wait(for: [requestStarted], timeout: 2)

        let cancellationIssued = expectation(description: "B's upstream cancellation issued")
        RefreshURLProtocol.signalNextStopLoading { cancellationIssued.fulfill() }
        cancelledWaiter.cancel()
        wait(for: [cancellationIssued], timeout: 2)

        XCTAssertEqual(RefreshURLProtocol.requestCount, 1)
        XCTAssertEqual(RefreshURLProtocol.stopLoadingCount, 1)

        // A subscribes afterward. A never registered with B's flight, so
        // B's abandonment must not fail A with .unauthorized; A runs its
        // own single valid request and succeeds.
        RefreshURLProtocol.responseDelay = 0
        let delayedReceived = expectation(description: "delayed subscriber receives a fresh session")
        delayedPublisher
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Delayed subscriber must not inherit the cancelled flight: \(error)")
                    }
                },
                receiveValue: { session in
                    XCTAssertEqual(session.refreshToken, "new-refresh")
                    delayedReceived.fulfill()
                }
            )
            .store(in: &cancellables)
        wait(for: [delayedReceived], timeout: 2)

        XCTAssertEqual(RefreshURLProtocol.requestCount, 2, "B's abandoned request plus exactly one valid request for A.")
        XCTAssertEqual(RefreshURLProtocol.refreshTokens, ["old-refresh", "old-refresh"])
        XCTAssertEqual(context.tokenStore.fetchAccessToken(), "new-access")
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "new-refresh")
        XCTAssertEqual(context.apiClient.userAuthToken, "new-access")
    }

    func testConcurrentFirstSubscriptionsShareExactlyOneRequest() {
        let context = makeContext(initialRefreshToken: "old-refresh")
        defer { context.session.invalidateAndCancel() }

        RefreshURLProtocol.responseDelay = 0.5
        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "new-access", refreshToken: "new-refresh")
        )

        let backgroundCancellables = LockedCancellableStore()
        let resultLock = NSLock()
        var receivedRefreshTokens: [String] = []
        let readyBarrier = DispatchSemaphore(value: 0)
        let startBarrier = DispatchSemaphore(value: 0)
        let firstReceived = expectation(description: "first concurrent subscriber receives the session")
        let secondReceived = expectation(description: "second concurrent subscriber receives the session")

        // Two subscribers race their first subscriptions from separate
        // threads, released through a shared barrier.
        for received in [firstReceived, secondReceived] {
            DispatchQueue.global().async {
                readyBarrier.signal()
                XCTAssertEqual(startBarrier.wait(timeout: .now() + 4), .success)
                let cancellable = context.repository.refreshSession()
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                XCTFail("Concurrent refresh failed: \(error)")
                            }
                        },
                        receiveValue: { session in
                            resultLock.lock()
                            receivedRefreshTokens.append(session.refreshToken)
                            resultLock.unlock()
                            received.fulfill()
                        }
                    )
                backgroundCancellables.store(cancellable)
            }
        }
        XCTAssertEqual(readyBarrier.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(readyBarrier.wait(timeout: .now() + 2), .success)
        startBarrier.signal()
        startBarrier.signal()

        wait(for: [firstReceived, secondReceived], timeout: 4)

        XCTAssertEqual(RefreshURLProtocol.requestCount, 1, "Concurrent first subscriptions must share one request.")
        XCTAssertEqual(RefreshURLProtocol.refreshTokens, ["old-refresh"])
        resultLock.lock()
        XCTAssertEqual(receivedRefreshTokens, ["new-refresh", "new-refresh"])
        resultLock.unlock()
        XCTAssertEqual(context.tokenStore.fetchAccessToken(), "new-access")
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "new-refresh")
    }

    func testWaiterCancellationDuringStartupDoesNotAbandonCreatingSubscriber() {
        let startupParked = DispatchSemaphore(value: 0)
        let releaseStartup = DispatchSemaphore(value: 0)
        let parkFirstStartup = ParkOnce(parked: startupParked, release: releaseStartup)
        let context = makeContext(
            initialRefreshToken: "old-refresh",
            refreshUpstreamWillStart: { parkFirstStartup.parkIfFirst() }
        )
        defer { context.session.invalidateAndCancel() }

        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "new-access", refreshToken: "new-refresh")
        )

        // The creating subscriber parks during startup: its waiter
        // registration exists, but the provider request is not installed.
        let backgroundCancellables = LockedCancellableStore()
        let creatorReceived = expectation(description: "creating subscriber receives the shared result")
        DispatchQueue.global().async {
            let cancellable = context.repository.refreshSession()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            XCTFail("Creating subscriber failed: \(error)")
                        }
                    },
                    receiveValue: { session in
                        XCTAssertEqual(session.refreshToken, "new-refresh")
                        creatorReceived.fulfill()
                    }
                )
            backgroundCancellables.store(cancellable)
        }
        XCTAssertEqual(startupParked.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(RefreshURLProtocol.requestCount, 0)

        // Join the starting flight and cancel. The parked creating
        // subscriber still owns a waiter registration, so this cancellation
        // must neither abandon the flight nor suppress the provider request.
        let joiner = context.repository.refreshSession()
            .sink(
                receiveCompletion: { _ in
                    XCTFail("A cancelled waiter must not receive a completion.")
                },
                receiveValue: { _ in
                    XCTFail("A cancelled waiter must not receive a session.")
                }
            )
        joiner.cancel()

        releaseStartup.signal()
        wait(for: [creatorReceived], timeout: 2)

        XCTAssertEqual(RefreshURLProtocol.requestCount, 1)
        XCTAssertEqual(RefreshURLProtocol.refreshTokens, ["old-refresh"])
        XCTAssertEqual(context.tokenStore.fetchAccessToken(), "new-access")
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "new-refresh")
        XCTAssertEqual(context.apiClient.userAuthToken, "new-access")
    }

    func testReplacementRefreshWaitsUntilAbandonedUpstreamCancellationIsIssued() {
        let cancelParked = DispatchSemaphore(value: 0)
        let releaseCancel = DispatchSemaphore(value: 0)
        let context = makeContext(
            initialRefreshToken: "old-refresh",
            refreshUpstreamWillCancel: {
                cancelParked.signal()
                _ = releaseCancel.wait(timeout: .now() + 4)
            }
        )
        defer { context.session.invalidateAndCancel() }

        RefreshURLProtocol.responseDelay = 5
        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "abandoned-access", refreshToken: "abandoned-refresh")
        )

        let requestStarted = expectation(description: "first refresh request started")
        RefreshURLProtocol.signalNextStartLoading { requestStarted.fulfill() }

        let onlyWaiter = context.repository.refreshSession()
            .sink(
                receiveCompletion: { _ in
                    XCTFail("A cancelled waiter must not receive a completion.")
                },
                receiveValue: { _ in
                    XCTFail("A cancelled waiter must not receive a session.")
                }
            )
        wait(for: [requestStarted], timeout: 2)

        // Cancel from a background thread: the abandoning transition parks
        // in the barrier right before issuing the upstream cancellation.
        let cancelIssued = expectation(description: "waiter cancellation returned")
        DispatchQueue.global().async {
            onlyWaiter.cancel()
            cancelIssued.fulfill()
        }
        XCTAssertEqual(cancelParked.wait(timeout: .now() + 2), .success)

        // A replacement refresh requested inside this window must not start
        // a second provider request while the old rotating request is live.
        RefreshURLProtocol.responseDelay = 0
        let replacementSucceeded = expectation(description: "replacement refresh succeeds")
        context.repository.refreshSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Replacement refresh failed: \(error)")
                    }
                },
                receiveValue: { _ in replacementSucceeded.fulfill() }
            )
            .store(in: &cancellables)

        XCTAssertEqual(
            RefreshURLProtocol.requestCount, 1,
            "No replacement request may start before the abandoned upstream cancellation is issued."
        )

        // Once the cancellation is released and finalized, exactly one new
        // request starts, still carrying the unconsumed refresh token.
        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "new-access", refreshToken: "new-refresh")
        )
        releaseCancel.signal()

        wait(for: [cancelIssued, replacementSucceeded], timeout: 4)

        XCTAssertEqual(RefreshURLProtocol.requestCount, 2)
        XCTAssertEqual(RefreshURLProtocol.refreshTokens, ["old-refresh", "old-refresh"])
        XCTAssertEqual(context.tokenStore.fetchAccessToken(), "new-access")
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "new-refresh")
        XCTAssertEqual(context.apiClient.userAuthToken, "new-access")
    }

    func testAllWaitersCancellingIssuesSingleCancellationAndDetachesOnce() {
        let context = makeContext(initialRefreshToken: "old-refresh")
        defer { context.session.invalidateAndCancel() }

        RefreshURLProtocol.responseDelay = 5
        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "abandoned-access", refreshToken: "abandoned-refresh")
        )

        let requestStarted = expectation(description: "refresh request started")
        RefreshURLProtocol.signalNextStartLoading { requestStarted.fulfill() }
        let cancellationIssued = expectation(description: "upstream cancellation issued")
        RefreshURLProtocol.signalNextStopLoading { cancellationIssued.fulfill() }

        let authenticatedNotifications = SessionChangeCounter(authenticated: true)
        defer { authenticatedNotifications.stop() }
        let unauthenticatedNotifications = SessionChangeCounter(authenticated: false)
        defer { unauthenticatedNotifications.stop() }

        let firstWaiter = context.repository.refreshSession()
            .sink(
                receiveCompletion: { _ in
                    XCTFail("A cancelled waiter must not receive a completion.")
                },
                receiveValue: { _ in
                    XCTFail("A cancelled waiter must not receive a session.")
                }
            )
        let secondWaiter = context.repository.refreshSession()
            .sink(
                receiveCompletion: { _ in
                    XCTFail("A cancelled waiter must not receive a completion.")
                },
                receiveValue: { _ in
                    XCTFail("A cancelled waiter must not receive a session.")
                }
            )
        wait(for: [requestStarted], timeout: 2)

        firstWaiter.cancel()
        secondWaiter.cancel()

        wait(for: [cancellationIssued], timeout: 2)

        XCTAssertEqual(RefreshURLProtocol.requestCount, 1)
        XCTAssertEqual(RefreshURLProtocol.stopLoadingCount, 1, "Cancellation must be issued exactly once.")
        XCTAssertNil(context.tokenStore.fetchAccessToken())
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "old-refresh")
        XCTAssertNil(context.apiClient.userAuthToken)
        XCTAssertNil(context.userStore.fetchUser())
        XCTAssertEqual(authenticatedNotifications.count, 0)
        XCTAssertEqual(unauthenticatedNotifications.count, 0)

        // The flight detached exactly once and is not reused: a later
        // refresh starts exactly one new request with the unconsumed token.
        RefreshURLProtocol.responseDelay = 0
        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "new-access", refreshToken: "new-refresh")
        )
        let refreshed = expectation(description: "fresh refresh succeeds")
        context.repository.refreshSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Fresh refresh failed: \(error)")
                    }
                },
                receiveValue: { _ in refreshed.fulfill() }
            )
            .store(in: &cancellables)
        wait(for: [refreshed], timeout: 2)

        XCTAssertEqual(RefreshURLProtocol.requestCount, 2)
        XCTAssertEqual(RefreshURLProtocol.refreshTokens, ["old-refresh", "old-refresh"])
        XCTAssertEqual(context.tokenStore.fetchAccessToken(), "new-access")
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "new-refresh")
    }

    func testCancelStartCompleteRaceKeepsSingleFlightConsistent() {
        let context = makeContext(initialRefreshToken: "refresh-0")
        defer { context.session.invalidateAndCancel() }

        // Each round races one waiter's cancellation against the shared
        // request completing for a surviving waiter. Every interleaving must
        // deliver exactly one value to the survivor, rotate the token once,
        // and start exactly one provider request.
        for round in 0..<8 {
            RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
                statusCode: 200,
                data: Self.authResponseJSON(
                    accessToken: "access-\(round + 1)",
                    refreshToken: "refresh-\(round + 1)"
                )
            )

            let cancelledWaiter = context.repository.refreshSession()
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

            let survivorReceived = expectation(description: "survivor receives value in round \(round)")
            context.repository.refreshSession()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            XCTFail("Round \(round) failed: \(error)")
                        }
                    },
                    receiveValue: { _ in survivorReceived.fulfill() }
                )
                .store(in: &cancellables)

            let cancelFinished = expectation(description: "cancel finished in round \(round)")
            DispatchQueue.global().async {
                cancelledWaiter.cancel()
                cancelFinished.fulfill()
            }

            wait(for: [survivorReceived, cancelFinished], timeout: 4)

            XCTAssertEqual(RefreshURLProtocol.requestCount, round + 1, "Round \(round) must start exactly one request.")
            XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "refresh-\(round + 1)")
            XCTAssertEqual(context.tokenStore.fetchAccessToken(), "access-\(round + 1)")
        }

        XCTAssertEqual(
            RefreshURLProtocol.refreshTokens,
            (0..<8).map { "refresh-\($0)" },
            "Every round must consume exactly the previously rotated token."
        )
    }

    func testLateSuccessCannotPersistSessionAfterLastWaiterCancelled() {
        let resolveEntered = DispatchSemaphore(value: 0)
        let releaseResolve = DispatchSemaphore(value: 0)
        let resolveFinished = DispatchSemaphore(value: 0)
        let context = makeContext(
            initialRefreshToken: "old-refresh",
            refreshWillResolve: {
                resolveEntered.signal()
                _ = releaseResolve.wait(timeout: .now() + 4)
            },
            refreshDidResolve: { resolveFinished.signal() }
        )
        defer { context.session.invalidateAndCancel() }

        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "late-access", refreshToken: "late-refresh")
        )

        let onlyWaiter = context.repository.refreshSession()
            .sink(
                receiveCompletion: { _ in
                    XCTFail("A cancelled waiter must not receive a completion.")
                },
                receiveValue: { _ in
                    XCTFail("A cancelled waiter must not receive a session.")
                }
            )

        // The decoded refresh success is parked right before the repository
        // resolves it; the last waiter cancels while it is parked.
        XCTAssertEqual(resolveEntered.wait(timeout: .now() + 2), .success)

        let authenticatedNotifications = SessionChangeCounter(authenticated: true)
        defer { authenticatedNotifications.stop() }

        onlyWaiter.cancel()

        releaseResolve.signal()
        XCTAssertEqual(resolveFinished.wait(timeout: .now() + 2), .success)

        XCTAssertNil(context.tokenStore.fetchAccessToken())
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "old-refresh")
        XCTAssertNil(context.apiClient.userAuthToken)
        XCTAssertNil(context.userStore.fetchUser())
        XCTAssertEqual(authenticatedNotifications.count, 0)
    }

    func testLateFailureCannotClearSessionAfterLastWaiterCancelled() {
        let resolveEntered = DispatchSemaphore(value: 0)
        let releaseResolve = DispatchSemaphore(value: 0)
        let resolveFinished = DispatchSemaphore(value: 0)
        let context = makeContext(
            initialRefreshToken: "old-refresh",
            refreshWillResolve: {
                resolveEntered.signal()
                _ = releaseResolve.wait(timeout: .now() + 4)
            },
            refreshDidResolve: { resolveFinished.signal() }
        )
        defer { context.session.invalidateAndCancel() }

        context.tokenStore.saveAccessToken("old-access")
        context.apiClient.userAuthToken = "old-access"

        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 401,
            data: Data(
                """
                {"success": false, "data": null, "error": {"code": "UNAUTHORIZED", "message": "expired"}}
                """.utf8
            )
        )

        let onlyWaiter = context.repository.refreshSession()
            .sink(
                receiveCompletion: { _ in
                    XCTFail("A cancelled waiter must not receive a completion.")
                },
                receiveValue: { _ in
                    XCTFail("A cancelled waiter must not receive a session.")
                }
            )

        // The refresh failure is parked right before the repository resolves
        // it; the last waiter cancels while it is parked.
        XCTAssertEqual(resolveEntered.wait(timeout: .now() + 2), .success)

        let unauthenticatedNotifications = SessionChangeCounter(authenticated: false)
        defer { unauthenticatedNotifications.stop() }

        onlyWaiter.cancel()

        releaseResolve.signal()
        XCTAssertEqual(resolveFinished.wait(timeout: .now() + 2), .success)

        XCTAssertEqual(context.tokenStore.fetchAccessToken(), "old-access")
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "old-refresh")
        XCTAssertEqual(context.apiClient.userAuthToken, "old-access")
        XCTAssertEqual(unauthenticatedNotifications.count, 0)
    }

    // MARK: - Credential logging privacy

    func testAuthenticationFlowsDoNotLogRawCredentials() {
        let context = makeContext(initialRefreshToken: nil)
        defer { context.session.invalidateAndCancel() }

        let email = "privacy-probe@example.test"
        let password = "super-secret-password-123"
        let loginAccessToken = "PRIVATE-ACCESS-TOKEN-A1B2"
        let loginRefreshToken = "PRIVATE-REFRESH-TOKEN-C3D4"
        let rotatedAccessToken = "PRIVATE-ACCESS-TOKEN-E5F6"
        let rotatedRefreshToken = "PRIVATE-REFRESH-TOKEN-G7H8"

        RefreshURLProtocol.routeResponses["auth/login"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(
                accessToken: loginAccessToken,
                refreshToken: loginRefreshToken,
                email: email
            )
        )
        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(
                accessToken: rotatedAccessToken,
                refreshToken: rotatedRefreshToken,
                email: email
            )
        )

        let capturedOutput = StdoutCapture.capture {
            let loggedIn = expectation(description: "login completed")
            context.repository.login(email: email, password: password)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            XCTFail("Login failed: \(error)")
                        }
                    },
                    receiveValue: { _ in loggedIn.fulfill() }
                )
                .store(in: &cancellables)
            wait(for: [loggedIn], timeout: 2)

            let refreshed = expectation(description: "refresh completed")
            context.repository.refreshSession()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            XCTFail("Refresh failed: \(error)")
                        }
                    },
                    receiveValue: { _ in refreshed.fulfill() }
                )
                .store(in: &cancellables)
            wait(for: [refreshed], timeout: 2)
        }

        XCTAssertTrue(
            capturedOutput.contains("[AuthNetwork]"),
            "Capture failed to observe auth logging; the privacy assertions below would be vacuous."
        )
        XCTAssertFalse(capturedOutput.contains(password), "Password must never be logged.")
        XCTAssertFalse(capturedOutput.contains(email), "Email must never be logged.")
        XCTAssertFalse(capturedOutput.contains(loginAccessToken), "Access token must never be logged.")
        XCTAssertFalse(capturedOutput.contains(loginRefreshToken), "Refresh token must never be logged.")
        XCTAssertFalse(capturedOutput.contains(rotatedAccessToken), "Rotated access token must never be logged.")
        XCTAssertFalse(capturedOutput.contains(rotatedRefreshToken), "Rotated refresh token must never be logged.")
        XCTAssertFalse(capturedOutput.contains("Bearer "), "Authorization header must never be logged.")

        XCTAssertEqual(context.tokenStore.fetchAccessToken(), rotatedAccessToken)
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), rotatedRefreshToken)
    }

    // MARK: - Helpers

    private enum FreshAuthenticationKind {
        case login
        case signUp
        case apple
        case google

        var routeKey: String {
            switch self {
            case .login: return "auth/login"
            case .signUp: return "auth/signup"
            case .apple: return "auth/apple"
            case .google: return "auth/google"
            }
        }
    }

    private func assertFreshAuthenticationSupersedesBlockedRefreshCommit(
        _ kind: FreshAuthenticationKind,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let commitEntered = DispatchSemaphore(value: 0)
        let releaseCommit = DispatchSemaphore(value: 0)
        let commitAttemptFinished = DispatchSemaphore(value: 0)
        let context = makeContext(
            initialRefreshToken: "old-refresh",
            refreshWillResolve: {
                commitEntered.signal()
                _ = releaseCommit.wait(timeout: .now() + 4)
            },
            refreshDidResolve: { commitAttemptFinished.signal() }
        )
        defer { context.session.invalidateAndCancel() }

        RefreshURLProtocol.routeResponses["auth/refresh"] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "stale-access", refreshToken: "stale-refresh")
        )
        RefreshURLProtocol.routeResponses[kind.routeKey] = StubRoute(
            statusCode: 200,
            data: Self.authResponseJSON(accessToken: "fresh-access", refreshToken: "fresh-refresh")
        )

        let refreshSuperseded = expectation(description: "refresh superseded")
        context.repository.refreshSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(.unauthorized) = completion {
                        refreshSuperseded.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Superseded refresh must not deliver a stale session.", file: file, line: line)
                }
            )
            .store(in: &cancellables)

        XCTAssertEqual(
            commitEntered.wait(timeout: .now() + 2), .success,
            "Refresh never reached its commit point.", file: file, line: line
        )

        let authenticatedNotifications = SessionChangeCounter(authenticated: true)
        defer { authenticatedNotifications.stop() }

        let authenticated = expectation(description: "fresh authentication completed")
        performFreshAuthentication(kind, repository: context.repository)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Fresh authentication failed: \(error)", file: file, line: line)
                    }
                },
                receiveValue: { session in
                    XCTAssertEqual(session.accessToken, "fresh-access", file: file, line: line)
                    authenticated.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [authenticated, refreshSuperseded], timeout: 2)

        releaseCommit.signal()
        XCTAssertEqual(
            commitAttemptFinished.wait(timeout: .now() + 2), .success,
            "Stale refresh commit attempt never finished.", file: file, line: line
        )

        XCTAssertEqual(authenticatedNotifications.count, 1, "The stale refresh must not re-announce authentication.", file: file, line: line)
        XCTAssertEqual(context.tokenStore.fetchAccessToken(), "fresh-access", file: file, line: line)
        XCTAssertEqual(context.tokenStore.fetchRefreshToken(), "fresh-refresh", file: file, line: line)
        XCTAssertEqual(context.apiClient.userAuthToken, "fresh-access", file: file, line: line)
        XCTAssertNotNil(context.userStore.fetchUser(), file: file, line: line)
    }

    private func performFreshAuthentication(
        _ kind: FreshAuthenticationKind,
        repository: DefaultAuthRepository
    ) -> AnyPublisher<AuthSession, AuthError> {
        switch kind {
        case .login:
            return repository.login(email: "fixture@example.test", password: "password-123")
        case .signUp:
            return repository.signUp(email: "fixture@example.test", password: "password-123", nickname: "fixture")
        case .apple:
            return repository.loginWithApple(
                credential: AppleLoginCredential(
                    userIdentifier: "apple-user",
                    identityToken: "apple-identity-token",
                    authorizationCode: nil,
                    email: nil,
                    givenName: nil,
                    familyName: nil
                )
            )
        case .google:
            return repository.loginWithGoogle(
                credential: GoogleLoginCredential(
                    idToken: "google-id-token",
                    accessToken: nil,
                    userID: nil,
                    deviceName: nil
                )
            )
        }
    }

    private struct TestContext {
        let repository: DefaultAuthRepository
        let tokenStore: InMemoryTokenStore
        let userStore: TestUserSessionStore
        let apiClient: APIClient
        let session: URLSession
    }

    private func makeContext(
        initialRefreshToken: String?,
        refreshWillResolve: (() -> Void)? = nil,
        refreshDidResolve: (() -> Void)? = nil,
        refreshUpstreamWillStart: (() -> Void)? = nil,
        refreshUpstreamWillCancel: (() -> Void)? = nil
    ) -> TestContext {
        let tokenStore = InMemoryTokenStore(refreshToken: initialRefreshToken)
        let userStore = TestUserSessionStore()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefreshURLProtocol.self]
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 4
        let session = URLSession(
            configuration: configuration,
            delegate: nil,
            delegateQueue: delegateQueue
        )
        let apiClient = APIClient(baseURL: URL(string: "https://example.test")!, session: session)
        let remote = AuthRemoteDataSource(
            baseURL: URL(string: "https://example.test")!,
            tokenStore: tokenStore,
            urlSession: session
        )
        let repository = DefaultAuthRepository(
            authRemoteDataSource: remote,
            tokenStore: tokenStore,
            userSessionStore: userStore,
            apiClient: apiClient,
            refreshWillResolve: refreshWillResolve,
            refreshDidResolve: refreshDidResolve,
            refreshUpstreamWillStart: refreshUpstreamWillStart,
            refreshUpstreamWillCancel: refreshUpstreamWillCancel
        )
        return TestContext(
            repository: repository,
            tokenStore: tokenStore,
            userStore: userStore,
            apiClient: apiClient,
            session: session
        )
    }

    private func assertSessionInvalidationWinsDecodedRefresh(useAccountDeletion: Bool) {
        let tokenStore = InMemoryTokenStore(refreshToken: "old-refresh")
        let userStore = TestUserSessionStore()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefreshURLProtocol.self]
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 4
        let session = URLSession(
            configuration: configuration,
            delegate: nil,
            delegateQueue: delegateQueue
        )
        defer { session.invalidateAndCancel() }
        let apiClient = APIClient(baseURL: URL(string: "https://example.test")!, session: session)
        if useAccountDeletion {
            tokenStore.saveAccessToken("old-access")
            apiClient.userAuthToken = "old-access"
        }
        let remote = AuthRemoteDataSource(
            baseURL: URL(string: "https://example.test")!,
            tokenStore: tokenStore,
            urlSession: session
        )
        let commitEntered = DispatchSemaphore(value: 0)
        let releaseCommit = DispatchSemaphore(value: 0)
        let commitAttemptFinished = DispatchSemaphore(value: 0)
        let observations = RefreshObservationState()
        let repository = DefaultAuthRepository(
            authRemoteDataSource: remote,
            tokenStore: tokenStore,
            userSessionStore: userStore,
            apiClient: apiClient,
            refreshWillResolve: {
                commitEntered.signal()
                _ = releaseCommit.wait(timeout: .now() + 2)
            },
            refreshDidResolve: { commitAttemptFinished.signal() }
        )

        RefreshURLProtocol.responseData = Self.authResponseJSON(
            accessToken: "new-access",
            refreshToken: "new-refresh"
        )

        let refreshCancelled = expectation(description: "refresh invalidated")
        repository.refreshSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(.unauthorized) = completion {
                        refreshCancelled.fulfill()
                    }
                },
                receiveValue: { _ in
                    observations.recordRefreshValue()
                }
            )
            .store(in: &cancellables)

        XCTAssertEqual(commitEntered.wait(timeout: .now() + 1), .success)

        let observer = NotificationCenter.default.addObserver(
            forName: .authSessionDidChange,
            object: nil,
            queue: nil
        ) { notification in
            if notification.userInfo?[AuthSessionChangeUserInfoKey.isAuthenticated] as? Bool == true {
                observations.recordAuthenticatedNotification()
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        if useAccountDeletion {
            let deletionCompleted = expectation(description: "account deletion completed")
            repository.deleteAccount()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            XCTFail("Account deletion failed: \(error)")
                        }
                    },
                    receiveValue: { deletionCompleted.fulfill() }
                )
                .store(in: &cancellables)
            wait(for: [deletionCompleted], timeout: 1)
        } else {
            repository.logout()
        }

        releaseCommit.signal()
        wait(for: [refreshCancelled], timeout: 1)
        XCTAssertEqual(commitAttemptFinished.wait(timeout: .now() + 1), .success)

        XCTAssertFalse(observations.receivedRefreshValue)
        XCTAssertEqual(observations.authenticatedNotificationCount, 0)
        XCTAssertNil(tokenStore.fetchAccessToken())
        XCTAssertNil(tokenStore.fetchRefreshToken())
        XCTAssertNil(apiClient.userAuthToken)
        XCTAssertNil(userStore.fetchUser())
    }

    private static func authResponseJSON(
        accessToken: String,
        refreshToken: String,
        email: String = "fixture@example.test"
    ) -> Data {
        Data(
            """
            {
              "success": true,
              "data": {
                "user": {
                  "id": "00000000-0000-0000-0000-000000000001",
                  "email": "\(email)",
                  "nickname": "fixture",
                  "profileImageUrl": null,
                  "status": "active",
                  "createdAt": "2026-07-13T12:00:00Z",
                  "updatedAt": "2026-07-13T12:00:00Z"
                },
                "tokens": {
                  "accessToken": "\(accessToken)",
                  "refreshToken": "\(refreshToken)"
                }
              },
              "error": null
            }
            """.utf8
        )
    }
}

// Retains cancellables handed over from concurrently subscribing threads
// without racing the test case's main-thread cancellable set.
private final class LockedCancellableStore: @unchecked Sendable {
    private let lock = NSLock()
    private var cancellables: [AnyCancellable] = []

    func store(_ cancellable: AnyCancellable) {
        lock.lock()
        cancellables.append(cancellable)
        lock.unlock()
    }
}

// Parks the first caller on a bounded barrier and lets every later caller
// pass through, so a repository hook can trap exactly one startup.
private final class ParkOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var hasParked = false
    private let parked: DispatchSemaphore
    private let release: DispatchSemaphore

    init(parked: DispatchSemaphore, release: DispatchSemaphore) {
        self.parked = parked
        self.release = release
    }

    func parkIfFirst() {
        lock.lock()
        let shouldPark = hasParked == false
        hasParked = true
        lock.unlock()
        guard shouldPark else { return }
        parked.signal()
        _ = release.wait(timeout: .now() + 4)
    }
}

private final class RefreshObservationState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedReceivedRefreshValue = false
    private var storedAuthenticatedNotificationCount = 0

    var receivedRefreshValue: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storedReceivedRefreshValue
    }

    var authenticatedNotificationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedAuthenticatedNotificationCount
    }

    func recordRefreshValue() {
        lock.lock()
        storedReceivedRefreshValue = true
        lock.unlock()
    }

    func recordAuthenticatedNotification() {
        lock.lock()
        storedAuthenticatedNotificationCount += 1
        lock.unlock()
    }
}

private final class SessionChangeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storedCount = 0
    private var observer: NSObjectProtocol?

    init(authenticated: Bool) {
        observer = NotificationCenter.default.addObserver(
            forName: .authSessionDidChange,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let isAuthenticated = notification.userInfo?[AuthSessionChangeUserInfoKey.isAuthenticated] as? Bool
            guard isAuthenticated == authenticated else { return }
            guard let self else { return }
            self.lock.lock()
            self.storedCount += 1
            self.lock.unlock()
        }
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedCount
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    deinit {
        stop()
    }
}

private enum StdoutCapture {
    static func capture(_ body: () -> Void) -> String {
        fflush(stdout)
        let pipe = Pipe()
        let originalFD = dup(STDOUT_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

        final class Buffer: @unchecked Sendable {
            var data = Data()
        }
        let buffer = Buffer()
        let drained = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            buffer.data = pipe.fileHandleForReading.readDataToEndOfFile()
            drained.signal()
        }

        body()

        fflush(stdout)
        dup2(originalFD, STDOUT_FILENO)
        close(originalFD)
        pipe.fileHandleForWriting.closeFile()
        _ = drained.wait(timeout: .now() + 5)
        return String(data: buffer.data, encoding: .utf8) ?? ""
    }
}

private struct StubRoute {
    let statusCode: Int
    let data: Data
}

private final class RefreshURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var storedRequestCount = 0
    private static var storedStopLoadingCount = 0
    private static var storedRefreshTokens: [String] = []
    private static var storedRouteResponses: [String: StubRoute] = [:]
    private static var storedNextStartLoadingSignal: (() -> Void)?
    private static var storedNextStopLoadingSignal: (() -> Void)?
    static var responseData = Data()
    static var responseDelay: TimeInterval = 0

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedRequestCount
    }

    static var stopLoadingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedStopLoadingCount
    }

    static var refreshTokens: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedRefreshTokens
    }

    static var routeResponses: [String: StubRoute] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedRouteResponses
        }
        set {
            lock.lock()
            storedRouteResponses = newValue
            lock.unlock()
        }
    }

    // One-shot signals so tests can wait for the next startLoading or
    // stopLoading with a bounded XCTest expectation instead of polling.
    static func signalNextStartLoading(_ signal: @escaping () -> Void) {
        lock.lock()
        storedNextStartLoadingSignal = signal
        lock.unlock()
    }

    static func signalNextStopLoading(_ signal: @escaping () -> Void) {
        lock.lock()
        storedNextStopLoadingSignal = signal
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        storedRequestCount = 0
        storedStopLoadingCount = 0
        storedRefreshTokens = []
        storedRouteResponses = [:]
        storedNextStartLoadingSignal = nil
        storedNextStopLoadingSignal = nil
        responseData = Data()
        responseDelay = 0
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""

        Self.lock.lock()
        Self.storedRequestCount += 1
        if path.hasSuffix("auth/refresh"),
           let body = Self.bodyData(for: request),
           let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let refreshToken = object["refreshToken"] as? String {
            Self.storedRefreshTokens.append(refreshToken)
        }
        let matchedRouteKey = Self.storedRouteResponses.keys.first { path.hasSuffix($0) }
        let route = matchedRouteKey.flatMap { Self.storedRouteResponses[$0] }
        let responseData = route?.data ?? Self.responseData
        let statusCode = route?.statusCode ?? 200
        let responseDelay = Self.responseDelay
        let startLoadingSignal = Self.storedNextStartLoadingSignal
        Self.storedNextStartLoadingSignal = nil
        Self.lock.unlock()

        startLoadingSignal?()

        DispatchQueue.global().asyncAfter(deadline: .now() + responseDelay) { [weak self] in
            guard let self, let url = self.request.url else { return }
            let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: responseData)
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
        Self.lock.lock()
        Self.storedStopLoadingCount += 1
        let stopLoadingSignal = Self.storedNextStopLoadingSignal
        Self.storedNextStopLoadingSignal = nil
        Self.lock.unlock()

        stopLoadingSignal?()
    }

    private static func bodyData(for request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while true {
            let bytesRead = stream.read(&buffer, maxLength: buffer.count)
            if bytesRead > 0 {
                body.append(contentsOf: buffer.prefix(bytesRead))
            } else if bytesRead == 0 {
                return body
            } else {
                return nil
            }
        }
    }
}

private final class InMemoryTokenStore: TokenStore {
    private let lock = NSLock()
    private var accessToken: String?
    private var refreshToken: String?

    init(refreshToken: String?) {
        self.refreshToken = refreshToken
    }

    func saveAccessToken(_ token: String) {
        lock.lock()
        accessToken = token
        lock.unlock()
    }

    func saveRefreshToken(_ token: String) {
        lock.lock()
        refreshToken = token
        lock.unlock()
    }

    func fetchAccessToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return accessToken
    }

    func fetchRefreshToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return refreshToken
    }

    func clear() {
        lock.lock()
        accessToken = nil
        refreshToken = nil
        lock.unlock()
    }
}

private final class TestUserSessionStore: UserSessionStore {
    private let lock = NSLock()
    private var user: AuthUser?

    func saveUser(_ user: AuthUser) {
        lock.lock()
        self.user = user
        lock.unlock()
    }

    func fetchUser() -> AuthUser? {
        lock.lock()
        defer { lock.unlock() }
        return user
    }

    func clear() {
        lock.lock()
        user = nil
        lock.unlock()
    }
}
