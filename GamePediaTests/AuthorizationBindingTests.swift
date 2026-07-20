import XCTest
@testable import GamePedia

// MARK: - Atomic authorization binding (iOS 2.4 review follow-up)
//
// An operation validated for account A must either bind A's currently valid
// credential snapshot or fail before request transmission — it must never
// read B's mutable current token after validating A. These tests cover the
// authority's atomic bind semantics, the park-immediately-before-binding
// interleavings (switch / logout / deletion / A → B → A between validation
// and bind), same-account refresh, and the engine→transport integration
// that stamps every remote execution with the adoption-time expectation.
//
// Deterministic throughout: the "park" points are explicit continuations or
// plain code between two synchronous calls — no sleeps, no wall-clock
// synchronization. Expectation timeouts are failure watchdogs only.
final class AuthorizationBindingTests: XCTestCase {

    private func assertUnauthorized(
        _ error: Error,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case NetworkError.unauthorized = error else {
            XCTFail("expected NetworkError.unauthorized, got \(error)", file: file, line: line)
            return
        }
    }

    // MARK: - Recording repositories (the transport's network boundary)

    private final class RecordingFavoriteRepository: FavoriteRepository, @unchecked Sendable {
        private let lock = NSLock()
        private(set) var mutations: [(gameID: String, authorization: RequestAuthorization)] = []

        var mutationCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return mutations.count
        }

        func addFavorite(gameId: String, authorization: RequestAuthorization) async throws -> FavoriteMutationResult {
            lock.lock()
            mutations.append((gameId, authorization))
            lock.unlock()
            return FavoriteMutationResult(gameId: Int(gameId) ?? -1, isFavorite: true)
        }

        func removeFavorite(gameId: String, authorization: RequestAuthorization) async throws -> FavoriteMutationResult {
            lock.lock()
            mutations.append((gameId, authorization))
            lock.unlock()
            return FavoriteMutationResult(gameId: Int(gameId) ?? -1, isFavorite: false)
        }

        func fetchMyFavorites(sort: FavoriteSortOption?) async throws -> [FavoriteItem] { [] }

        func fetchFavoriteStatus(gameId: String) async throws -> FavoriteStatus {
            FavoriteStatus(isFavorite: false)
        }
    }

    private final class RecordingLibraryStatusRepository: LibraryRepository, @unchecked Sendable {
        private let lock = NSLock()
        private(set) var mutations: [(externalGameID: String, authorization: RequestAuthorization)] = []

        var mutationCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return mutations.count
        }

        func updateGameStatus(
            request: LibraryGameStatusUpdateRequest,
            authorization: RequestAuthorization
        ) async throws -> LibraryGameStatusMutationResult {
            lock.lock()
            mutations.append((request.externalGameId, authorization))
            lock.unlock()
            return LibraryGameStatusMutationResult(identifier: request.identifier, status: request.status)
        }

        func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverview {
            throw LibraryError.network
        }
        func fetchOwnedLibrary() async throws -> OwnedLibraryCollection { throw LibraryError.network }
        func fetchPlayingLibrary() async throws -> [LibraryGameSummary] { [] }
        func fetchRecentlyPlayedLibrary() async throws -> [LibraryGameSummary] { [] }
        func fetchPlaytimeRecommendations() async throws -> [PlaytimeRecommendation] { [] }
        func fetchInAppFriendRecommendations() async throws -> [SteamFriendRecommendation] { [] }
        func fetchSteamFriendRecommendations() async throws -> [SteamFriendRecommendation] { [] }
        func fetchSteamLinkStatus() async throws -> SteamLinkStatus { throw LibraryError.network }
        func startSteamLink() async throws -> URL { throw LibraryError.network }
        func unlinkSteamAccount() async throws -> SteamUnlinkResult { throw LibraryError.network }
        func syncOwnedSteamLibrary() async throws -> SteamOwnedLibrarySyncResult { throw LibraryError.network }
    }

    private func makeOperation(accountID: String, gameID: String = "42") -> LibrarySyncOperation {
        LibrarySyncOperation(
            id: UUID(),
            accountID: accountID,
            kind: .setFavorite(gameID: gameID, isFavorite: true),
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
    }

    private func makeStatusOperation(accountID: String) -> LibrarySyncOperation {
        LibrarySyncOperation(
            id: UUID(),
            accountID: accountID,
            kind: .setLibraryStatus(
                LibraryStatusSyncPayload(
                    source: .steam,
                    externalGameID: "570",
                    canonicalGameID: nil,
                    title: "Dota 2",
                    coverURL: nil,
                    status: .playing
                )
            ),
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
    }

    // MARK: - Authority: atomic bind semantics

    func testBindReturnsTheExpectedAccountsCurrentCredential() {
        let authority = SessionCredentialAuthority()
        authority.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a")

        let expectation = authority.expectation(accountID: "user-a")
        XCTAssertNotNil(expectation)
        let snapshot = authority.bindCredential(expectation: expectation!)
        XCTAssertEqual(snapshot?.accountID, "user-a")
        XCTAssertEqual(snapshot?.accessToken, "token-a")
    }

    func testExpectationIsUnavailableForAForeignAccount() {
        let authority = SessionCredentialAuthority()
        authority.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a")
        XCTAssertNil(authority.expectation(accountID: "user-b"))
    }

    // MARK: 2/3. Park immediately before binding, switch A → B, release

    func testExpectationCapturedUnderANeverBindsBsToken() {
        let authority = SessionCredentialAuthority()
        authority.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a")

        // Validation happened; the operation "parks" here (plain code
        // between two synchronous calls — the deterministic park point).
        let parked = authority.expectation(accountID: "user-a")!

        // B replaces A, then the parked operation resumes and binds.
        authority.adoptAuthenticatedSession(accountID: "user-b", accessToken: "token-b")

        XCTAssertNil(
            authority.bindCredential(expectation: parked),
            "an expectation validated for A must fail after B took the session — never read B's token"
        )
    }

    // MARK: 4. Logout invalidates the parked expectation

    func testExpectationCapturedUnderAFailsAfterLogout() {
        let authority = SessionCredentialAuthority()
        authority.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a")
        let parked = authority.expectation(accountID: "user-a")!

        authority.clearSession()

        XCTAssertNil(authority.bindCredential(expectation: parked))
    }

    // MARK: 5. Account deletion invalidates the parked expectation

    func testExpectationCapturedUnderAFailsAfterAccountDeletion() {
        let authority = SessionCredentialAuthority()
        authority.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a")
        let parked = authority.expectation(accountID: "user-a")!

        // Deletion clears the stored session exactly like logout does at
        // the credential boundary.
        authority.clearSession()

        XCTAssertNil(authority.bindCredential(expectation: parked))
        // Even a later re-login of a DIFFERENT account can never revive it.
        authority.adoptAuthenticatedSession(accountID: "user-b", accessToken: "token-b")
        XCTAssertNil(authority.bindCredential(expectation: parked))
    }

    // MARK: 6. A → B → A does not revive the old expectation

    func testAToBToADoesNotReviveTheOldExpectation() {
        let authority = SessionCredentialAuthority()
        authority.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a1")
        let parked = authority.expectation(accountID: "user-a")!

        authority.adoptAuthenticatedSession(accountID: "user-b", accessToken: "token-b")
        authority.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a2")

        XCTAssertNil(
            authority.bindCredential(expectation: parked),
            "A → B → A re-issues A's session under a new epoch; the old context must stay dead"
        )
        // A fresh expectation under the new A session binds the new token.
        let fresh = authority.expectation(accountID: "user-a")!
        XCTAssertEqual(authority.bindCredential(expectation: fresh)?.accessToken, "token-a2")
    }

    // MARK: 7. Same-account refresh preserves the expectation, binds the new token

    func testSameAccountRefreshBindsTheRefreshedTokenUnderTheSameExpectation() {
        let authority = SessionCredentialAuthority()
        authority.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a1")
        let parked = authority.expectation(accountID: "user-a")!

        // Single-flight refresh committed a new credential for the SAME
        // account: the epoch (and the parked expectation) stays valid.
        authority.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a2")

        let snapshot = authority.bindCredential(expectation: parked)
        XCTAssertEqual(snapshot?.accessToken, "token-a2", "the refreshed credential must be provided")
        XCTAssertEqual(snapshot?.accountID, "user-a")
    }

    // MARK: - APIClient: bind failure means no transmission

    func testAPIClientFailsBeforeTransmissionWhenExpectationIsStale() async {
        // A URLProtocol that records (and would fail) any transmitted
        // request: the assertion is that NOTHING reaches it.
        RequestRecordingURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RequestRecordingURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let apiClient = APIClient(baseURL: URL(string: "https://example.test")!, session: session)

        apiClient.credentialAuthority.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a")
        let parked = apiClient.credentialAuthority.expectation(accountID: "user-a")!
        apiClient.credentialAuthority.adoptAuthenticatedSession(accountID: "user-b", accessToken: "token-b")

        do {
            _ = try await apiClient.request(
                .addFavorite(body: AddFavoriteRequestDTO(gameId: "42")),
                as: FavoriteResponseEnvelopeDTO<FavoriteMutationResponseDataDTO>.self,
                authorization: .boundAccount(parked)
            )
            XCTFail("a stale expectation must fail before transmission")
        } catch {
            assertUnauthorized(error)
        }
        XCTAssertEqual(RequestRecordingURLProtocol.requestCount, 0, "no request may be transmitted")
    }

    func testAPIClientBindsTheExpectedAccountsTokenIntoTheRequest() async throws {
        RequestRecordingURLProtocol.reset()
        RequestRecordingURLProtocol.responseData = Data(
            #"{"success":true,"data":{"favorite":{"gameId":42,"isFavorite":true}}}"#.utf8
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RequestRecordingURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let apiClient = APIClient(baseURL: URL(string: "https://example.test")!, session: session)

        apiClient.credentialAuthority.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a1")
        let expectation = apiClient.credentialAuthority.expectation(accountID: "user-a")!
        // Same-account refresh AFTER capture: the bind must pick up the
        // refreshed token, still under the same expectation.
        apiClient.credentialAuthority.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a2")

        _ = try? await apiClient.request(
            .addFavorite(body: AddFavoriteRequestDTO(gameId: "42")),
            as: FavoriteResponseEnvelopeDTO<FavoriteMutationResponseDataDTO>.self,
            authorization: .boundAccount(expectation)
        )

        XCTAssertEqual(RequestRecordingURLProtocol.requestCount, 1)
        XCTAssertEqual(
            RequestRecordingURLProtocol.authorizationHeaders,
            ["Bearer token-a2"],
            "the request must carry the expected account's current credential"
        )
    }

    func testGuestOnlyAuthorizationNeverTransmitsEvenWhenALoginRacedIn() async {
        RequestRecordingURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RequestRecordingURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let apiClient = APIClient(baseURL: URL(string: "https://example.test")!, session: session)

        // The exact guest boundary: the gesture happened as guest, then a
        // login raced in before the request was built. `.guestOnly` must
        // not be able to obtain the new bearer token.
        apiClient.credentialAuthority.adoptAuthenticatedSession(accountID: "user-b", accessToken: "token-b")

        do {
            _ = try await apiClient.request(
                .addFavorite(body: AddFavoriteRequestDTO(gameId: "42")),
                as: FavoriteResponseEnvelopeDTO<FavoriteMutationResponseDataDTO>.self,
                authorization: .guestOnly
            )
            XCTFail("a guest-owned mutation must never transmit")
        } catch {
            assertUnauthorized(error)
        }
        XCTAssertEqual(RequestRecordingURLProtocol.requestCount, 0)
    }

    // MARK: - Transport: expectation is mandatory and account-matched

    func testTransportRefusesToPerformWithoutAnExpectation() async {
        let favorites = RecordingFavoriteRepository()
        let transport = RESTLibrarySyncTransport(
            favoriteRepository: favorites,
            libraryRepository: RecordingLibraryStatusRepository()
        )

        do {
            _ = try await transport.perform(makeOperation(accountID: "user-a"), authorization: nil)
            XCTFail("no expectation → no request")
        } catch {
            assertUnauthorized(error)
        }
        XCTAssertEqual(favorites.mutationCount, 0)
    }

    func testTransportRefusesAForeignAccountsExpectation() async {
        let favorites = RecordingFavoriteRepository()
        let transport = RESTLibrarySyncTransport(
            favoriteRepository: favorites,
            libraryRepository: RecordingLibraryStatusRepository()
        )
        let foreign = AuthorizationExpectation(accountID: "user-b", sessionEpoch: 7)

        do {
            _ = try await transport.perform(makeOperation(accountID: "user-a"), authorization: foreign)
            XCTFail("an expectation for another account must never authorize this operation")
        } catch {
            assertUnauthorized(error)
        }
        XCTAssertEqual(favorites.mutationCount, 0)
    }

    func testTransportStampsFavoriteAndStatusMutationsWithTheBoundExpectation() async throws {
        let favorites = RecordingFavoriteRepository()
        let statuses = RecordingLibraryStatusRepository()
        let transport = RESTLibrarySyncTransport(
            favoriteRepository: favorites,
            libraryRepository: statuses
        )
        let expectation = AuthorizationExpectation(accountID: "user-a", sessionEpoch: 3)

        _ = try await transport.perform(makeOperation(accountID: "user-a"), authorization: expectation)
        _ = try await transport.perform(makeStatusOperation(accountID: "user-a"), authorization: expectation)

        XCTAssertEqual(favorites.mutations.count, 1)
        XCTAssertEqual(favorites.mutations[0].authorization, .boundAccount(expectation))
        XCTAssertEqual(statuses.mutations.count, 1)
        XCTAssertEqual(statuses.mutations[0].authorization, .boundAccount(expectation))
    }

    // MARK: - Engine integration: adoption-time expectation stamps executions

    private func makeEngineContext(
        authority: SessionCredentialAuthority
    ) -> (engine: LibrarySyncEngine, transport: MockLibrarySyncTransport, store: InMemorySyncOperationStore) {
        let transport = MockLibrarySyncTransport()
        let store = InMemorySyncOperationStore()
        var configuration = LibrarySyncEngine.Configuration()
        configuration.retryPolicy = ReconnectPolicy(baseDelay: 2, multiplier: 2, maxDelay: 60, maxJitterFraction: 0.25)
        configuration.maxAutomaticAttempts = 3
        let engine = LibrarySyncEngine(
            store: store,
            transport: transport,
            configuration: configuration,
            jitterSource: FixedJitterSource(unitValue: 0),
            sleeper: TestRealtimeSleeper(autoResume: true),
            notificationCenter: NotificationCenter(),
            now: { Date(timeIntervalSince1970: 1_000) },
            authorizationProvider: { accountID in authority.expectation(accountID: accountID) }
        )
        return (engine, transport, store)
    }

    func testEngineStampsRemoteExecutionWithTheAdoptionTimeExpectation() async throws {
        let authority = SessionCredentialAuthority()
        authority.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a")
        let (engine, transport, _) = makeEngineContext(authority: authority)

        let performed = expectation(description: "operation performed")
        transport.onCall = { _ in performed.fulfill() }
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")
        let result = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        XCTAssertEqual(result, .accepted)
        await fulfillment(of: [performed], timeout: 10)

        let expected = authority.expectation(accountID: "user-a")
        XCTAssertEqual(transport.calls.count, 1)
        XCTAssertEqual(transport.calls[0].authorization, expected)
    }

    func testEngineExpectationSurvivesSameAccountRefreshAndDiesOnReplacement() async throws {
        let authority = SessionCredentialAuthority()
        authority.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a1")
        let (engine, transport, _) = makeEngineContext(authority: authority)
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")
        let originalExpectation = authority.expectation(accountID: "user-a")

        // Same-account refresh: same epoch, refreshed credential.
        authority.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a2")
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        let performed = expectation(description: "operation performed")
        transport.onCall = { _ in performed.fulfill() }
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [performed], timeout: 10)
        XCTAssertEqual(transport.calls[0].authorization, originalExpectation, "a refresh must not advance the expectation")

        // Replacement: the authority's epoch advances; a NEW adoption gets
        // a different expectation than the original.
        authority.adoptAuthenticatedSession(accountID: "user-b", accessToken: "token-b")
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-b")
        let bExpectation = authority.expectation(accountID: "user-b")
        XCTAssertNotNil(bExpectation)
        XCTAssertNotEqual(bExpectation, originalExpectation)
    }

    // MARK: 1–6, 10. Park immediately before authorization binding: the held
    // in-flight request resolves only after the account transition, and the
    // stale expectation can no longer bind — no request uses B's token.

    func testParkedBeforeBindingInterleavingsNeverBindAForeignToken() async {
        struct Transition {
            let name: String
            let apply: (SessionCredentialAuthority) -> Void
            /// Expected bind result for a FRESH A expectation captured
            /// after the transition (nil when A no longer owns a session).
            let freshTokenAfterTransition: String?
        }
        let transitions: [Transition] = [
            Transition(name: "switch-to-B", apply: {
                $0.adoptAuthenticatedSession(accountID: "user-b", accessToken: "token-b")
            }, freshTokenAfterTransition: nil),
            Transition(name: "logout", apply: {
                $0.clearSession()
            }, freshTokenAfterTransition: nil),
            Transition(name: "account-deletion", apply: {
                $0.clearSession()
            }, freshTokenAfterTransition: nil),
            Transition(name: "A-B-A", apply: {
                $0.adoptAuthenticatedSession(accountID: "user-b", accessToken: "token-b")
                $0.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a2")
            }, freshTokenAfterTransition: "token-a2")
        ]

        // Repeated 50 times per transition — the critical interleaving is
        // pure synchronous state, so every iteration is exact (test 40).
        for iteration in 0..<50 {
            for transition in transitions {
                let authority = SessionCredentialAuthority()
                authority.adoptAuthenticatedSession(accountID: "user-a", accessToken: "token-a1")
                // Validation for A completes; the operation parks here.
                let parked = authority.expectation(accountID: "user-a")!

                transition.apply(authority)

                // Released: the parked bind must fail — B's (or the new
                // session's) token is unreachable through the old context.
                let snapshot = authority.bindCredential(expectation: parked)
                XCTAssertNil(
                    snapshot,
                    "\(transition.name) iteration \(iteration): stale context must not bind"
                )

                if let freshToken = transition.freshTokenAfterTransition {
                    let fresh = authority.expectation(accountID: "user-a")
                    XCTAssertEqual(
                        fresh.flatMap { authority.bindCredential(expectation: $0) }?.accessToken,
                        freshToken,
                        "\(transition.name) iteration \(iteration): the NEW session binds its own credential"
                    )
                } else {
                    XCTAssertNil(authority.expectation(accountID: "user-a"))
                }
            }
        }
    }
}

// MARK: - Request-recording URLProtocol

/// Records every request that actually reaches the URL loading system —
/// the definitive "was anything transmitted" oracle. Responds with the
/// scripted body (default: 200 + empty JSON).
final class RequestRecordingURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var recorded: [URLRequest] = []
    static var responseData = Data("{}".utf8)

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return recorded.count
    }

    static var authorizationHeaders: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded.compactMap { $0.value(forHTTPHeaderField: "Authorization") }
    }

    static func reset() {
        lock.lock()
        recorded = []
        responseData = Data("{}".utf8)
        lock.unlock()
    }

    override static func canInit(with request: URLRequest) -> Bool {
        lock.lock()
        recorded.append(request)
        lock.unlock()
        return true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
