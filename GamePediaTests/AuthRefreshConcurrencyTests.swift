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
        RefreshURLProtocol.responseData = Data(
            """
            {
              "success": true,
              "data": {
                "user": {
                  "id": "00000000-0000-0000-0000-000000000001",
                  "email": "fixture@example.test",
                  "nickname": "fixture",
                  "profileImageUrl": null,
                  "status": "active",
                  "createdAt": "2026-07-13T12:00:00Z",
                  "updatedAt": "2026-07-13T12:00:00Z"
                },
                "tokens": {
                  "accessToken": "new-access",
                  "refreshToken": "new-refresh"
                }
              },
              "error": null
            }
            """.utf8
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
        RefreshURLProtocol.responseData = Data(
            """
            {
              "success": true,
              "data": {
                "user": {
                  "id": "00000000-0000-0000-0000-000000000001",
                  "email": "fixture@example.test",
                  "nickname": "fixture",
                  "profileImageUrl": null,
                  "status": "active",
                  "createdAt": "2026-07-13T12:00:00Z",
                  "updatedAt": "2026-07-13T12:00:00Z"
                },
                "tokens": {
                  "accessToken": "new-access",
                  "refreshToken": "new-refresh"
                }
              }
            }
            """.utf8
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
            refreshWillCommit: {
                commitEntered.signal()
                _ = releaseCommit.wait(timeout: .now() + 2)
            },
            refreshDidAttemptCommit: { commitAttemptFinished.signal() }
        )

        RefreshURLProtocol.responseData = Self.authResponseData

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

    private static let authResponseData = Data(
        """
        {
          "success": true,
          "data": {
            "user": {
              "id": "00000000-0000-0000-0000-000000000001",
              "email": "fixture@example.test",
              "nickname": "fixture",
              "profileImageUrl": null,
              "status": "active",
              "createdAt": "2026-07-13T12:00:00Z",
              "updatedAt": "2026-07-13T12:00:00Z"
            },
            "tokens": {
              "accessToken": "new-access",
              "refreshToken": "new-refresh"
            }
          }
        }
        """.utf8
    )
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

private final class RefreshURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var storedRequestCount = 0
    private static var storedRefreshTokens: [String] = []
    static var responseData = Data()
    static var responseDelay: TimeInterval = 0

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedRequestCount
    }

    static var refreshTokens: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedRefreshTokens
    }

    static func reset() {
        lock.lock()
        storedRequestCount = 0
        storedRefreshTokens = []
        responseData = Data()
        responseDelay = 0
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.storedRequestCount += 1
        if let body = Self.bodyData(for: request),
           let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let refreshToken = object["refreshToken"] as? String {
            Self.storedRefreshTokens.append(refreshToken)
        }
        let responseData = Self.responseData
        let responseDelay = Self.responseDelay
        Self.lock.unlock()

        DispatchQueue.global().asyncAfter(deadline: .now() + responseDelay) { [weak self] in
            guard let self, let url = self.request.url else { return }
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: responseData)
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

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
