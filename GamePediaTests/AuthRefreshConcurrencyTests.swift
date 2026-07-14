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

        let noDelivery = expectation(description: "abandoned waiter receives nothing")
        noDelivery.isInverted = true
        let onlyWaiter = context.repository.refreshSession()
            .sink(
                receiveCompletion: { _ in noDelivery.fulfill() },
                receiveValue: { _ in noDelivery.fulfill() }
            )

        // Cancelling immediately can beat the URLSession task's own startup,
        // in which case the protocol never starts loading at all. Wait until
        // the request is genuinely in flight so the test exercises the
        // cancellation of live provider work.
        let requestStarted = expectation(description: "refresh request started")
        DispatchQueue.global().async {
            while RefreshURLProtocol.requestCount < 1 {
                usleep(10_000)
            }
            requestStarted.fulfill()
        }
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
        refreshDidResolve: (() -> Void)? = nil
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
            refreshDidResolve: refreshDidResolve
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

    static func reset() {
        lock.lock()
        storedRequestCount = 0
        storedStopLoadingCount = 0
        storedRefreshTokens = []
        storedRouteResponses = [:]
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
        Self.lock.unlock()

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
        Self.lock.unlock()
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
