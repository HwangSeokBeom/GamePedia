import XCTest
@testable import GamePedia

// MARK: - LibraryCuratorViewModel gesture ownership (iOS 2.4 review follow-up)
//
// The curator screen's favorite action uses the same gesture-time ownership
// and LibrarySyncEngine route as every other authenticated ViewModel:
// synchronous capture before the submission Task, enqueue through
// LibraryMutationSyncing, no authenticated direct repository call, and
// refusals that never rewrite a newer gesture's or another account's UI.
//
// Deterministic throughout: enqueues park on continuations, scope
// transitions are explicit synchronous calls, and negative assertions run
// behind yield drains — no sleeps.
final class LibraryCuratorOwnershipTests: XCTestCase {

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

    private final class StubCuratorUseCase: FetchLibraryCuratorUseCase {
        let result: LibraryCuratorResult
        init(result: LibraryCuratorResult) { self.result = result }
        func execute(request: LibraryCuratorRequest) async throws -> LibraryCuratorResult { result }
    }

    /// Loaded curator result with one game ("1942", already favorite).
    private func makeResult() throws -> LibraryCuratorResult {
        let json = """
        {
          "success": true,
          "data": {
            "mode": "today",
            "source": "llm",
            "summary": { "title": "Today", "body": "Pick this next.", "bullets": ["Short"] },
            "tasteProfile": {
              "topGenres": ["RPG"], "topThemes": ["story"],
              "preferredSession": "short_session", "playStyleTags": ["rediscover"],
              "ratingStyle": "high_rating_preference"
            },
            "sections": [
              {
                "id": "today", "title": "Today", "description": "For now",
                "items": [
                  { "gameId": "1942", "reason": "Good match", "matchTags": ["match"], "confidence": 0.91 }
                ]
              }
            ],
            "games": [
              {
                "gameId": "1942", "title": "Stardew Valley",
                "coverUrl": "https://example.com/cover.jpg",
                "genres": ["RPG"], "platforms": ["PC"], "rating": 89.5,
                "source": "owned", "playtimeMinutes": 120,
                "lastPlayedAt": "2026-04-30T10:00:00Z",
                "isFavorite": true, "hasReview": true, "userRating": 4.5
              }
            ],
            "meta": {
              "candidateCount": 10, "selectedCount": 1,
              "generatedAt": "2026-04-30T10:00:00Z", "locale": "ko"
            }
          }
        }
        """.data(using: .utf8)!
        let envelope = try JSONDecoder().decode(LibraryCuratorResponseEnvelopeDTO.self, from: json)
        return LibraryCuratorMapper.toEntity(try XCTUnwrap(envelope.data))
    }

    private func makeLoadedViewModel(
        repository: RecordingFavoriteRepository,
        router: MockLibraryMutationRouter
    ) async throws -> LibraryCuratorViewModel {
        let viewModel = LibraryCuratorViewModel(
            fetchLibraryCuratorUseCase: StubCuratorUseCase(result: try makeResult()),
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: repository),
            librarySync: router
        )
        let loaded = expectation(description: "curator result loaded")
        viewModel.onStateChanged = { state in
            if state.hasLoadedOnce, !state.isLoading {
                loaded.fulfill()
            }
        }
        viewModel.send(.analyzeTapped)
        await fulfillment(of: [loaded], timeout: 10)
        viewModel.onStateChanged = nil
        return viewModel
    }

    private func itemIsFavorite(_ viewModel: LibraryCuratorViewModel) -> Bool? {
        viewModel.state.sections.flatMap(\.items).first { $0.gameId == "1942" }?.isFavorite
    }

    private func drainConcurrentWork() async {
        for _ in 0..<200 {
            await Task.yield()
        }
        await MainActor.run {}
        for _ in 0..<200 {
            await Task.yield()
        }
    }

    // MARK: Capture at gesture, enqueue through the engine, no repository

    func testCapturesOwnershipSynchronouslyAndRoutesThroughEngine() async throws {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        let viewModel = try await makeLoadedViewModel(repository: repository, router: router)

        let enqueued = expectation(description: "enqueue recorded")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.favoriteTapped("1942"))

        // Captured synchronously inside the gesture handler, before any
        // Task ran; the item is favorite, so the intent is removal.
        XCTAssertEqual(router.capturedOwnerships.count, 1)
        XCTAssertEqual(router.capturedOwnerships[0].entityKey, LibrarySyncEntityKey.favorite(gameID: "1942"))
        XCTAssertEqual(router.capturedOwnerships[0].intendedState, .favorite(isFavorite: false))
        XCTAssertEqual(itemIsFavorite(viewModel), false, "the optimistic flip applies immediately")

        await fulfillment(of: [enqueued], timeout: 10)
        await drainConcurrentWork()
        XCTAssertEqual(router.enqueuedOwnerships, router.capturedOwnerships)
        XCTAssertEqual(repository.mutationCount, 0, "an authenticated gesture must never call the repository")
    }

    // MARK: 23. Switch before enqueue cannot mutate the new account

    func testSwitchBeforeEnqueueCannotMutateTheNewAccount() async throws {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.holdEnqueues = true
        let viewModel = try await makeLoadedViewModel(repository: repository, router: router)
        let recorder = NotificationRecorder(center: .default, names: [.favoriteDidChange])

        let enqueued = expectation(description: "enqueue parked")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.favoriteTapped("1942"))
        await fulfillment(of: [enqueued], timeout: 10)

        // The account switches while the submission is parked; the engine
        // then reports the capture as stale.
        router.advanceScope()
        router.resolveHeldEnqueue(
            entityKey: LibrarySyncEntityKey.favorite(gameID: "1942"),
            sequence: 1,
            with: .staleOwnership
        )
        await drainConcurrentWork()

        XCTAssertEqual(repository.mutationCount, 0, "the stale intent must never reach any transport")
        XCTAssertEqual(recorder.count(of: .favoriteDidChange), 0)
        XCTAssertNil(viewModel.state.errorMessage, "a stale intent is dropped silently")
    }

    // MARK: 24/29. Switch after request start publishes no stale UI state

    func testSwitchAfterRequestStartPublishesNoStaleStateOrNotification() async throws {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.holdEnqueues = true
        let viewModel = try await makeLoadedViewModel(repository: repository, router: router)
        let recorder = NotificationRecorder(center: .default, names: [.favoriteDidChange])

        let enqueued = expectation(description: "enqueue parked")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.favoriteTapped("1942"))
        await fulfillment(of: [enqueued], timeout: 10)
        let stateBeforeRefusal = itemIsFavorite(viewModel)

        // The request already started when the account switches; the
        // refusal that eventually arrives belongs to a dead scope.
        router.advanceScope()
        router.resolveHeldEnqueue(
            entityKey: LibrarySyncEntityKey.favorite(gameID: "1942"),
            sequence: 1,
            with: .storageBlocked
        )
        await drainConcurrentWork()

        XCTAssertEqual(itemIsFavorite(viewModel), stateBeforeRefusal, "a stale refusal must not rewrite UI state")
        XCTAssertNil(viewModel.state.errorMessage)
        XCTAssertEqual(recorder.count(of: .favoriteDidChange), 0, "no global notification for a stale completion")
        XCTAssertEqual(repository.mutationCount, 0)
    }

    // MARK: 25/26. Logout and account deletion invalidate the operation

    func testLogoutAndDeletionInvalidateTheParkedOperation() async throws {
        for transition in ["logout", "deletion"] {
            let repository = RecordingFavoriteRepository()
            let router = MockLibraryMutationRouter()
            router.holdEnqueues = true
            let viewModel = try await makeLoadedViewModel(repository: repository, router: router)
            let recorder = NotificationRecorder(center: .default, names: [.favoriteDidChange])

            let enqueued = expectation(description: "\(transition): enqueue parked")
            router.onEnqueue = { enqueued.fulfill() }
            viewModel.send(.favoriteTapped("1942"))
            await fulfillment(of: [enqueued], timeout: 10)

            // Logout/deletion end the owning scope (the ownership authority
            // treats both as scope invalidation).
            router.ownershipIsCurrent = false
            router.resolveHeldEnqueue(
                entityKey: LibrarySyncEntityKey.favorite(gameID: "1942"),
                sequence: 1,
                with: .staleOwnership
            )
            await drainConcurrentWork()

            XCTAssertEqual(repository.mutationCount, 0, "\(transition): the invalidated intent must never transmit")
            XCTAssertEqual(recorder.count(of: .favoriteDidChange), 0, transition)
            XCTAssertNil(viewModel.state.errorMessage, transition)
        }
    }

    // MARK: 27. A → B → A does not revive old ownership

    func testAToBToADoesNotReviveOldOwnership() async throws {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.holdEnqueues = true
        let viewModel = try await makeLoadedViewModel(repository: repository, router: router)

        let enqueued = expectation(description: "enqueue parked")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.favoriteTapped("1942"))
        await fulfillment(of: [enqueued], timeout: 10)
        let oldScopeID = router.capturedOwnerships[0].scopeID

        // A → B → A: two scope advances; ids are never reused.
        router.advanceScope()
        router.advanceScope()
        router.resolveHeldEnqueue(
            entityKey: LibrarySyncEntityKey.favorite(gameID: "1942"),
            sequence: 1,
            with: .staleOwnership
        )
        await drainConcurrentWork()
        XCTAssertEqual(repository.mutationCount, 0)

        // A fresh gesture under the re-issued A scope captures a NEW scope
        // id and proceeds normally.
        router.holdEnqueues = false
        let freshEnqueued = expectation(description: "fresh enqueue recorded")
        router.onEnqueue = { freshEnqueued.fulfill() }
        viewModel.send(.favoriteTapped("1942"))
        await fulfillment(of: [freshEnqueued], timeout: 10)
        XCTAssertEqual(router.capturedOwnerships.count, 2)
        XCTAssertNotEqual(router.capturedOwnerships[1].scopeID, oldScopeID, "old ownership must not revive")
    }

    // MARK: 28. Rapid add/remove keeps the gesture-time order

    func testRapidGesturesCarryStrictlyIncreasingSequencesInGestureOrder() async throws {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        let viewModel = try await makeLoadedViewModel(repository: repository, router: router)

        let bothEnqueued = expectation(description: "both gestures enqueued")
        bothEnqueued.expectedFulfillmentCount = 2
        router.onEnqueue = { bothEnqueued.fulfill() }
        viewModel.send(.favoriteTapped("1942")) // remove (was favorite)
        viewModel.send(.favoriteTapped("1942")) // add back (newest)

        // Sequences are assigned synchronously at gesture time, in user
        // order, regardless of Task scheduling.
        XCTAssertEqual(router.capturedOwnerships.map(\.sequence), [1, 2])
        XCTAssertEqual(router.capturedOwnerships[0].intendedState, .favorite(isFavorite: false))
        XCTAssertEqual(router.capturedOwnerships[1].intendedState, .favorite(isFavorite: true))
        XCTAssertEqual(itemIsFavorite(viewModel), true, "the newest gesture governs the optimistic state")

        await fulfillment(of: [bothEnqueued], timeout: 10)
        await drainConcurrentWork()
        XCTAssertEqual(repository.mutationCount, 0)
    }

    // MARK: storageBlocked reconciles to the last acknowledged state

    func testStorageBlockedReconcilesOptimisticStateAndSurfacesRetryableError() async throws {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .storageBlocked
        let viewModel = try await makeLoadedViewModel(repository: repository, router: router)

        let reconciled = expectation(description: "optimistic flip reconciled")
        viewModel.onStateChanged = { state in
            let item = state.sections.flatMap(\.items).first { $0.gameId == "1942" }
            if item?.isFavorite == true, state.errorMessage != nil {
                reconciled.fulfill()
            }
        }
        viewModel.send(.favoriteTapped("1942"))
        await fulfillment(of: [reconciled], timeout: 10)
        await drainConcurrentWork()

        XCTAssertEqual(itemIsFavorite(viewModel), true, "the last acknowledged state is restored")
        XCTAssertNotNil(viewModel.state.errorMessage, "the failure must be visible and retryable")
        XCTAssertEqual(repository.mutationCount, 0, "no second transport path")
    }

    // MARK: Permanent engine failure reconciles against the intended state

    func testEngineFailureNotificationReconcilesAgainstIntendedState() async throws {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        let viewModel = try await makeLoadedViewModel(repository: repository, router: router)

        let reconciled = expectation(description: "failure reconciled")
        viewModel.onStateChanged = { state in
            let item = state.sections.flatMap(\.items).first { $0.gameId == "1942" }
            if item?.isFavorite == true, state.errorMessage != nil {
                reconciled.fulfill()
            }
        }
        NotificationCenter.default.post(
            name: .librarySyncOperationDidFail,
            object: nil,
            userInfo: [
                LibrarySyncFailureUserInfoKey.entityKind: LibrarySyncEntityKind.favorite.rawValue,
                LibrarySyncFailureUserInfoKey.gameID: "1942",
                LibrarySyncFailureUserInfoKey.errorCode: "INVALID_GAME_ID",
                LibrarySyncFailureUserInfoKey.operationID: UUID().uuidString,
                LibrarySyncFailureUserInfoKey.intendedIsFavorite: false,
                LibrarySyncFailureUserInfoKey.supersededByNewerIntent: false
            ]
        )
        await fulfillment(of: [reconciled], timeout: 10)
    }

    // MARK: Guest boundary: `.guestOnly`, never the engine

    func testGuestGestureUsesGuestOnlyAuthorizationAndNeverEntersTheQueue() async throws {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.accountID = nil // guest: capture fails
        let viewModel = try await makeLoadedViewModel(repository: repository, router: router)

        viewModel.send(.favoriteTapped("1942"))
        for _ in 0..<10_000 {
            if repository.mutationCount == 1 { break }
            await Task.yield()
        }
        await drainConcurrentWork()

        XCTAssertEqual(repository.mutationCount, 1)
        XCTAssertEqual(
            repository.mutations.first?.authorization, .guestOnly,
            "a guest gesture must never be able to attach a bearer token"
        )
        XCTAssertTrue(router.favoriteChanges.isEmpty, "guest gestures never enter the queue")
    }

    // MARK: 40. Critical switch interleaving repeated 50 times

    func testStaleRefusalInterleavingRepeated50Times() async throws {
        for iteration in 0..<50 {
            let repository = RecordingFavoriteRepository()
            let router = MockLibraryMutationRouter()
            router.holdEnqueues = true
            let viewModel = try await makeLoadedViewModel(repository: repository, router: router)

            let enqueued = expectation(description: "iteration \(iteration): enqueue parked")
            router.onEnqueue = { enqueued.fulfill() }
            viewModel.send(.favoriteTapped("1942"))
            await fulfillment(of: [enqueued], timeout: 10)

            router.advanceScope()
            router.resolveHeldEnqueue(
                entityKey: LibrarySyncEntityKey.favorite(gameID: "1942"),
                sequence: 1,
                with: iteration.isMultiple(of: 2) ? .staleOwnership : .storageBlocked
            )
            await drainConcurrentWork()

            XCTAssertEqual(repository.mutationCount, 0, "iteration \(iteration)")
            XCTAssertNil(viewModel.state.errorMessage, "iteration \(iteration): stale refusals stay silent")
        }
    }
}
