import XCTest
@testable import GamePedia

// MARK: - AIRecommendationViewModel gesture ownership (iOS 2.4 follow-up)
//
// Mirror of LibraryCuratorOwnershipTests for the AI recommendation screen:
// synchronous gesture-time capture, engine-only authenticated route, guest
// boundary via `.guestOnly`, and refusals that never rewrite a newer
// gesture's or another account's UI. Deterministic throughout — enqueues
// park on continuations, scope transitions are synchronous, no sleeps.
final class AIRecommendationOwnershipTests: XCTestCase {

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

    private final class StubRecommendationsUseCase: FetchAIRecommendationsUseCase {
        func execute(query: String) async throws -> AIRecommendationResult {
            AIRecommendationResult(
                requestId: "ownership-tests",
                normalizedQuery: query,
                intent: nil,
                items: [
                    AIRecommendation(
                        gameId: 1942,
                        title: "Stardew Valley",
                        coverURL: nil,
                        platforms: ["PC"],
                        genres: ["Simulator"],
                        rating: nil,
                        reason: "reason",
                        matchTags: ["relaxing"],
                        confidence: nil,
                        recommendationSource: "test",
                        personalized: false,
                        fallbackUsed: false
                    )
                ],
                meta: nil,
                disclaimer: nil
            )
        }
    }

    private func makeLoadedViewModel(
        repository: RecordingFavoriteRepository,
        router: MockLibraryMutationRouter
    ) async -> AIRecommendationViewModel {
        let viewModel = AIRecommendationViewModel(
            fetchAIRecommendationsUseCase: StubRecommendationsUseCase(),
            fetchMyFavoritesUseCase: FetchMyFavoritesUseCase(favoriteRepository: repository),
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: repository),
            librarySync: router
        )
        let loaded = expectation(description: "recommendations loaded")
        viewModel.onStateChanged = { state in
            if state.recommendations.count == 1, !state.isLoading {
                loaded.fulfill()
            }
        }
        viewModel.send(.queryChanged("힐링 게임 추천"))
        viewModel.send(.recommendButtonTapped)
        await fulfillment(of: [loaded], timeout: 10)
        viewModel.onStateChanged = nil
        return viewModel
    }

    private func itemIsFavorite(_ viewModel: AIRecommendationViewModel) -> Bool? {
        viewModel.state.recommendations.first { $0.gameId == 1942 }?.isFavorite
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

    func testCapturesOwnershipSynchronouslyAndRoutesThroughEngine() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        let viewModel = await makeLoadedViewModel(repository: repository, router: router)

        let enqueued = expectation(description: "enqueue recorded")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.favoriteTapped(gameId: 1942))

        XCTAssertEqual(router.capturedOwnerships.count, 1)
        XCTAssertEqual(router.capturedOwnerships[0].entityKey, LibrarySyncEntityKey.favorite(gameID: "1942"))
        XCTAssertEqual(router.capturedOwnerships[0].intendedState, .favorite(isFavorite: true))
        XCTAssertEqual(itemIsFavorite(viewModel), true, "the optimistic flip applies immediately")

        await fulfillment(of: [enqueued], timeout: 10)
        await drainConcurrentWork()
        XCTAssertEqual(router.enqueuedOwnerships, router.capturedOwnerships)
        XCTAssertEqual(repository.mutationCount, 0, "an authenticated gesture must never call the repository")
    }

    // MARK: 30. Switch before enqueue cannot mutate the new account

    func testSwitchBeforeEnqueueCannotMutateTheNewAccount() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.holdEnqueues = true
        let viewModel = await makeLoadedViewModel(repository: repository, router: router)
        let recorder = NotificationRecorder(center: .default, names: [.favoriteDidChange])

        let enqueued = expectation(description: "enqueue parked")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.favoriteTapped(gameId: 1942))
        await fulfillment(of: [enqueued], timeout: 10)

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

    // MARK: 31/36. Switch after request start publishes no stale UI state

    func testSwitchAfterRequestStartPublishesNoStaleStateOrNotification() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.holdEnqueues = true
        let viewModel = await makeLoadedViewModel(repository: repository, router: router)
        let recorder = NotificationRecorder(center: .default, names: [.favoriteDidChange])

        let enqueued = expectation(description: "enqueue parked")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.favoriteTapped(gameId: 1942))
        await fulfillment(of: [enqueued], timeout: 10)
        let stateBeforeRefusal = itemIsFavorite(viewModel)

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

    // MARK: 32/33. Logout and account deletion invalidate the operation

    func testLogoutAndDeletionInvalidateTheParkedOperation() async {
        for transition in ["logout", "deletion"] {
            let repository = RecordingFavoriteRepository()
            let router = MockLibraryMutationRouter()
            router.holdEnqueues = true
            let viewModel = await makeLoadedViewModel(repository: repository, router: router)
            let recorder = NotificationRecorder(center: .default, names: [.favoriteDidChange])

            let enqueued = expectation(description: "\(transition): enqueue parked")
            router.onEnqueue = { enqueued.fulfill() }
            viewModel.send(.favoriteTapped(gameId: 1942))
            await fulfillment(of: [enqueued], timeout: 10)

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

    // MARK: 34. A → B → A does not revive old ownership

    func testAToBToADoesNotReviveOldOwnership() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.holdEnqueues = true
        let viewModel = await makeLoadedViewModel(repository: repository, router: router)

        let enqueued = expectation(description: "enqueue parked")
        router.onEnqueue = { enqueued.fulfill() }
        viewModel.send(.favoriteTapped(gameId: 1942))
        await fulfillment(of: [enqueued], timeout: 10)
        let oldScopeID = router.capturedOwnerships[0].scopeID

        router.advanceScope()
        router.advanceScope()
        router.resolveHeldEnqueue(
            entityKey: LibrarySyncEntityKey.favorite(gameID: "1942"),
            sequence: 1,
            with: .staleOwnership
        )
        await drainConcurrentWork()
        XCTAssertEqual(repository.mutationCount, 0)

        router.holdEnqueues = false
        let freshEnqueued = expectation(description: "fresh enqueue recorded")
        router.onEnqueue = { freshEnqueued.fulfill() }
        viewModel.send(.favoriteTapped(gameId: 1942))
        await fulfillment(of: [freshEnqueued], timeout: 10)
        XCTAssertEqual(router.capturedOwnerships.count, 2)
        XCTAssertNotEqual(router.capturedOwnerships[1].scopeID, oldScopeID, "old ownership must not revive")
    }

    // MARK: 35. Rapid add/remove keeps the gesture-time order

    func testRapidGesturesCarryStrictlyIncreasingSequencesInGestureOrder() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        let viewModel = await makeLoadedViewModel(repository: repository, router: router)

        let bothEnqueued = expectation(description: "both gestures enqueued")
        bothEnqueued.expectedFulfillmentCount = 2
        router.onEnqueue = { bothEnqueued.fulfill() }
        viewModel.send(.favoriteTapped(gameId: 1942)) // add
        viewModel.send(.favoriteTapped(gameId: 1942)) // remove (newest)

        XCTAssertEqual(router.capturedOwnerships.map(\.sequence), [1, 2])
        XCTAssertEqual(router.capturedOwnerships[0].intendedState, .favorite(isFavorite: true))
        XCTAssertEqual(router.capturedOwnerships[1].intendedState, .favorite(isFavorite: false))
        XCTAssertEqual(itemIsFavorite(viewModel), false, "the newest gesture governs the optimistic state")

        await fulfillment(of: [bothEnqueued], timeout: 10)
        await drainConcurrentWork()
        XCTAssertEqual(repository.mutationCount, 0)
    }

    // MARK: storageBlocked reconciles to the last acknowledged state

    func testStorageBlockedReconcilesOptimisticStateAndSurfacesRetryableError() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.enqueueResult = .storageBlocked
        let viewModel = await makeLoadedViewModel(repository: repository, router: router)

        let reconciled = expectation(description: "optimistic flip reconciled")
        viewModel.onStateChanged = { state in
            let item = state.recommendations.first { $0.gameId == 1942 }
            if item?.isFavorite == false, state.errorMessage != nil {
                reconciled.fulfill()
            }
        }
        viewModel.send(.favoriteTapped(gameId: 1942))
        await fulfillment(of: [reconciled], timeout: 10)
        await drainConcurrentWork()

        XCTAssertEqual(itemIsFavorite(viewModel), false, "the last acknowledged state is restored")
        XCTAssertNotNil(viewModel.state.errorMessage, "the failure must be visible and retryable")
        XCTAssertEqual(repository.mutationCount, 0, "no second transport path")
    }

    // MARK: Permanent engine failure reconciles against the intended state

    func testEngineFailureNotificationReconcilesAgainstIntendedState() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        let viewModel = await makeLoadedViewModel(repository: repository, router: router)

        let reconciled = expectation(description: "failure reconciled")
        viewModel.onStateChanged = { state in
            let item = state.recommendations.first { $0.gameId == 1942 }
            if item?.isFavorite == false, state.errorMessage != nil {
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
                LibrarySyncFailureUserInfoKey.intendedIsFavorite: true,
                LibrarySyncFailureUserInfoKey.supersededByNewerIntent: false
            ]
        )
        await fulfillment(of: [reconciled], timeout: 10)
    }

    // MARK: Guest boundary: `.guestOnly`, never the engine

    func testGuestGestureUsesGuestOnlyAuthorizationAndNeverEntersTheQueue() async {
        let repository = RecordingFavoriteRepository()
        let router = MockLibraryMutationRouter()
        router.accountID = nil // guest: capture fails
        let viewModel = await makeLoadedViewModel(repository: repository, router: router)

        viewModel.send(.favoriteTapped(gameId: 1942))
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

    func testStaleRefusalInterleavingRepeated50Times() async {
        for iteration in 0..<50 {
            let repository = RecordingFavoriteRepository()
            let router = MockLibraryMutationRouter()
            router.holdEnqueues = true
            let viewModel = await makeLoadedViewModel(repository: repository, router: router)

            let enqueued = expectation(description: "iteration \(iteration): enqueue parked")
            router.onEnqueue = { enqueued.fulfill() }
            viewModel.send(.favoriteTapped(gameId: 1942))
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
