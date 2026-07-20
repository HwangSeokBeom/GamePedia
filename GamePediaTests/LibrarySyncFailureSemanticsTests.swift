import XCTest
@testable import GamePedia

// H3 — ambiguous post-write failures.
//
// A response that is missing, empty, or undecodable AFTER the transport
// succeeded is never a permanent rejection: the server may have committed,
// so the operation is retried (bounded, parkable) and reconciled from the
// authoritative server response. Deterministic pre-send and validation
// failures stay permanent; auth failures stay auth-owned.
final class LibrarySyncFailureSemanticsTests: XCTestCase {

    private var store: InMemorySyncOperationStore!
    private var transport: MockLibrarySyncTransport!
    private var center: NotificationCenter!

    override func setUp() {
        super.setUp()
        store = InMemorySyncOperationStore()
        transport = MockLibrarySyncTransport()
        center = NotificationCenter()
    }

    // MARK: - Classification

    func testAmbiguousPostSendFailuresClassifyAsRetryable() {
        let ambiguous: [Error] = [
            FavoriteError.invalidResponse,
            LibraryError.invalidResponse,
            NetworkError.noData,
            NetworkError.decodingFailed(NSError(domain: "test", code: 1))
        ]
        for error in ambiguous {
            let failure = LibrarySyncFailureClassifier.classify(error)
            XCTAssertEqual(
                failure, .transient(code: "AMBIGUOUS_RESPONSE"),
                "\(error) is post-send ambiguity and must stay retryable"
            )
        }
    }

    func testDeterministicPreSendAndValidationFailuresStayPermanent() {
        XCTAssertEqual(
            LibrarySyncFailureClassifier.classify(NetworkError.invalidURL),
            .permanent(code: "INVALID_REQUEST_URL")
        )
        XCTAssertEqual(
            LibrarySyncFailureClassifier.classify(FavoriteError.validationFailed(message: "invalid")),
            .permanent(code: "VALIDATION_ERROR")
        )
        XCTAssertEqual(
            LibrarySyncFailureClassifier.classify(FavoriteError.invalidGameId),
            .permanent(code: "INVALID_GAME_ID")
        )
    }

    func testAuthFailuresStayAuthOwnedIncludingTokenRevoked() {
        XCTAssertEqual(
            LibrarySyncFailureClassifier.classify(FavoriteError.unauthorized),
            .authRequired(code: "UNAUTHORIZED")
        )
        XCTAssertEqual(
            LibrarySyncFailureClassifier.classify(
                NetworkError.serverError(statusCode: 401, code: "TOKEN_REVOKED", message: nil)
            ),
            .authRequired(code: "TOKEN_REVOKED")
        )
    }

    // MARK: - Engine flows

    func testResponseBodyLostThenRetrySucceedsWithSameOperationAndNoRollback() async {
        // Call 0: transport succeeded but the response was lost. Call 1:
        // the retry receives the server's absolute state.
        transport.behavior = { _, index in
            index == 0 ? .failure(FavoriteError.invalidResponse) : .success(nil)
        }
        let engine = makeSyncEngine(store: store, transport: transport, notificationCenter: center)
        let failureRecorder = NotificationRecorder(center: center, names: [.librarySyncOperationDidFail])
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        let reconciled = notificationExpectation(.favoriteDidChange, center: center)
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [reconciled], timeout: 10)

        XCTAssertEqual(transport.calls.count, 2)
        XCTAssertEqual(
            transport.calls[0].operation.id, transport.calls[1].operation.id,
            "the retry must reuse the identical idempotent operation"
        )
        XCTAssertEqual(
            failureRecorder.count(of: .librarySyncOperationDidFail), 0,
            "a lost response body must never roll back the optimistic state"
        )
        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 0)
    }

    func testDecodeFailureThenAlreadyExistingAbsoluteStateResponseReconciles() async {
        transport.behavior = { operation, index in
            if index == 0 {
                return .failure(NetworkError.decodingFailed(NSError(domain: "test", code: 2)))
            }
            // The server had already committed: the retry answers with the
            // existing absolute state.
            guard case .setFavorite(let gameID, let isFavorite) = operation.kind else {
                return .success(nil)
            }
            return .success(.favorite(FavoriteMutationResult(gameId: Int(gameID) ?? -1, isFavorite: isFavorite)))
        }
        let engine = makeSyncEngine(store: store, transport: transport, notificationCenter: center)
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        let reconciled = notificationExpectation(.favoriteDidChange, center: center) { notification in
            (notification.userInfo?[FavoriteChangeUserInfoKey.isFavorite] as? Bool) == true
        }
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [reconciled], timeout: 10)

        XCTAssertEqual(transport.calls.count, 2)
    }

    func testAmbiguousFailuresRemainBoundedByParking() async {
        // Endless ambiguity must not retry forever: after the automatic
        // attempt cap the entity parks, work preserved for manual retry.
        transport.behavior = { _, _ in .failure(FavoriteError.invalidResponse) }
        let engine = makeSyncEngine(
            store: store,
            transport: transport,
            notificationCenter: center,
            maxAutomaticAttempts: 2
        )
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        let parked = notificationExpectation(.librarySyncQueueDidChange, center: center) { notification in
            (notification.userInfo?[LibrarySyncQueueUserInfoKey.parkedCount] as? Int) == 1
        }
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [parked], timeout: 10)

        XCTAssertEqual(transport.calls.count, 2)
        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 1, "parked ambiguous work is preserved, not dropped")
    }

    func testDeterministic400StyleValidationFailureIsDroppedAndSurfacedOnce() async {
        transport.behavior = { _, _ in .failure(FavoriteError.validationFailed(message: "invalid")) }
        let engine = makeSyncEngine(store: store, transport: transport, notificationCenter: center)
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        let dropped = notificationExpectation(.librarySyncOperationDidFail, center: center) { notification in
            (notification.userInfo?[LibrarySyncFailureUserInfoKey.errorCode] as? String) == "VALIDATION_ERROR"
        }
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [dropped], timeout: 10)

        XCTAssertEqual(transport.calls.count, 1, "a deterministic rejection must never retry")
        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 0)
    }

    func testTokenRevokedPausesTheQueueAndPreservesWork() async {
        transport.behavior = { _, _ in
            .failure(NetworkError.serverError(statusCode: 401, code: "TOKEN_REVOKED", message: nil))
        }
        let engine = makeSyncEngine(store: store, transport: transport, notificationCenter: center)
        await engine.sessionDidChange(isAuthenticated: true, userID: "user-a")

        let paused = notificationExpectation(.librarySyncQueueDidChange, center: center)
        _ = await engine.enqueueFavoriteChange(gameID: "42", isFavorite: true)
        await fulfillment(of: [paused], timeout: 10)

        // Deterministic settle point: wait until the engine reports the
        // auth pause, then verify nothing was dropped or retried.
        for _ in 0..<10_000 {
            let snapshot = await engine.diagnosticsSnapshot()
            if snapshot.isBlockedOnAuth { break }
            await Task.yield()
        }
        let snapshot = await engine.diagnosticsSnapshot()
        XCTAssertTrue(snapshot.isBlockedOnAuth)
        XCTAssertEqual(snapshot.lastSafeErrorCode, "TOKEN_REVOKED")
        XCTAssertEqual(transport.calls.count, 1)
        let pending = await engine.pendingOperationCount
        XCTAssertEqual(pending, 1)
    }
}
