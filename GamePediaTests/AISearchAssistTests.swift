import XCTest
@testable import GamePedia

final class AISearchAssistTests: XCTestCase {
    func testDTO_decodesWrapperSuccessResponse() throws {
        let json = """
        {
          "success": true,
          "data": {
            "requestId": "ai-search-test",
            "originalQuery": "퇴근 후 30분 정도 할 수 있는 힐링 게임",
            "normalizedQuery": "짧게 즐길 수 있는 힐링 게임",
            "intent": {
              "mood": ["relaxing", "cozy"],
              "sessionLength": "short",
              "playMode": "singleplayer",
              "difficulty": "low",
              "platforms": ["PC", "Nintendo Switch"],
              "genres": ["Simulation", "Adventure"],
              "keywords": ["힐링", "짧은 세션"]
            },
            "suggestedQueries": ["짧게 즐기는 힐링 게임"],
            "items": [
              {
                "gameId": 1942,
                "title": "Stardew Valley",
                "coverUrl": "https://example.com/cover.jpg",
                "platforms": ["PC"],
                "genres": ["Simulator"],
                "rating": 89.2,
                "matchReason": "짧은 세션으로도 농장 관리를 즐길 수 있어요.",
                "matchTags": ["힐링"],
                "confidence": 0.91
              }
            ],
            "fallbackUsed": false,
            "disclaimer": "AI 검색 보조 결과는 참고용입니다."
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(
            AISearchAssistResponseEnvelopeDTO<AISearchAssistResponseDTO>.self,
            from: json
        )
        let result = AISearchAssistMapper.toEntity(try XCTUnwrap(response.data))

        XCTAssertTrue(response.success)
        XCTAssertEqual(result.requestId, "ai-search-test")
        XCTAssertEqual(result.intent?.keywords, ["힐링", "짧은 세션"])
        XCTAssertEqual(result.suggestedQueries, ["짧게 즐기는 힐링 게임"])
        XCTAssertEqual(result.items.first?.gameId, 1942)
        XCTAssertEqual(result.items.first?.confidence, 0.91)
    }

    func testErrorMapping_usesSearchAssistMessages() {
        XCTAssertEqual(
            AISearchAssistError.from(serverCode: "AI_SEARCH_DAILY_LIMIT_EXCEEDED", message: nil).errorDescription,
            "오늘 사용할 수 있는 AI 검색 보조 횟수를 모두 사용했어요."
        )
        XCTAssertEqual(
            AISearchAssistError.from(serverCode: "VALIDATION_FAILED", message: nil).errorDescription,
            "검색어를 조금 더 구체적으로 입력해주세요."
        )
        XCTAssertEqual(
            AISearchAssistError.from(serverCode: "UNAUTHORIZED", message: nil).errorDescription,
            "로그인이 필요해요."
        )
        XCTAssertEqual(
            AISearchAssistError.from(serverCode: "CANDIDATE_NOT_FOUND", message: nil).errorDescription,
            "조건에 맞는 게임을 찾지 못했어요. 검색어를 조금 바꿔보세요."
        )
    }

    func testReducer_transitionsFromTypingToLoaded() {
        var state = AISearchAssistState()

        state = AISearchAssistReducer.reduce(state, .setQuery("퇴근 후 힐링 게임"))
        XCTAssertEqual(state.status, .typing)
        XCTAssertTrue(state.canRequestAISearch)

        state = AISearchAssistReducer.reduce(state, .setLoading(true))
        XCTAssertEqual(state.status, .loading)
        XCTAssertTrue(state.isLoading)

        state = AISearchAssistReducer.reduce(
            state,
            .setLoaded(
                items: [makeItem(gameId: 1942)],
                suggestedQueries: ["짧게 즐기는 힐링 게임"],
                intentChips: ["힐링"],
                normalizedQuery: "짧게 즐길 수 있는 힐링 게임",
                fallbackUsed: true,
                disclaimer: "참고용",
                requestSignature: "퇴근 후 힐링 게임"
            )
        )

        XCTAssertEqual(state.status, .loaded)
        XCTAssertFalse(state.isLoading)
        XCTAssertEqual(state.items.first?.gameId, 1942)
        XCTAssertTrue(state.fallbackUsed)
    }

    func testItemViewState_visibleMatchTagsFiltersEmptyDuplicatesAndLimitsToThree() {
        let item = AISearchAssistItemViewState(
            gameId: 1,
            title: "Game",
            coverURL: nil,
            platforms: [],
            genres: [],
            ratingText: "—",
            matchReason: "reason",
            matchTags: ["힐링", " ", "힐링", "Cozy", "cozy", "짧은 세션", "추가"],
            confidence: nil
        )

        XCTAssertEqual(item.matchTags, ["힐링", " ", "힐링", "Cozy", "cozy", "짧은 세션", "추가"])
        XCTAssertEqual(item.visibleMatchTags, ["힐링", "아늑한", "짧은 세션"])
    }

    func testViewModel_preventsDuplicateRequestForSameInFlightQuery() async {
        let useCase = DelayedAISearchAssistUseCase()
        let viewModel = AISearchAssistViewModel(fetchAISearchAssistUseCase: useCase)

        viewModel.send(.queryChanged("퇴근 후 30분 힐링 게임"))
        viewModel.send(.aiAssistTapped)
        viewModel.send(.aiAssistTapped)

        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(useCase.requestCount, 1)
    }

    func testViewModel_staleResponseDoesNotOverwriteLatestState() async {
        let useCase = ControlledAISearchAssistUseCase()
        let viewModel = AISearchAssistViewModel(fetchAISearchAssistUseCase: useCase)

        viewModel.send(.queryChanged("퇴근 후 30분 힐링 게임"))
        viewModel.send(.aiAssistTapped)
        await useCase.waitForRequestCount(1)

        viewModel.send(.queryChanged("친구랑 할 수 있는 협동 게임"))
        viewModel.send(.aiAssistTapped)
        await useCase.waitForRequestCount(2)

        await useCase.resume(at: 1, with: makeResult(requestId: "new", title: "New Game"))
        try? await Task.sleep(nanoseconds: 30_000_000)
        await useCase.resume(at: 0, with: makeResult(requestId: "old", title: "Old Game"))
        try? await Task.sleep(nanoseconds: 30_000_000)

        XCTAssertEqual(viewModel.state.items.first?.title, "New Game")
    }

    func testViewModel_itemTapRoutesToGameDetail() async {
        let useCase = ImmediateAISearchAssistUseCase()
        let viewModel = AISearchAssistViewModel(fetchAISearchAssistUseCase: useCase)
        var routedGameId: Int?
        viewModel.onRouteToGameDetail = { routedGameId = $0 }

        viewModel.send(.queryChanged("퇴근 후 30분 힐링 게임"))
        viewModel.send(.aiAssistTapped)
        try? await Task.sleep(nanoseconds: 30_000_000)
        viewModel.send(.itemTapped(gameId: 1942))

        XCTAssertEqual(routedGameId, 1942)
    }

    private func makeItem(gameId: Int) -> AISearchAssistItemViewState {
        AISearchAssistItemViewState(
            gameId: gameId,
            title: "Game \(gameId)",
            coverURL: nil,
            platforms: [],
            genres: [],
            ratingText: "—",
            matchReason: "reason",
            matchTags: [],
            confidence: nil
        )
    }

    private func makeResult(requestId: String, title: String) -> AISearchAssistResult {
        AISearchAssistResult(
            requestId: requestId,
            originalQuery: title,
            normalizedQuery: title,
            intent: nil,
            suggestedQueries: [],
            items: [
                AISearchAssistItem(
                    gameId: requestId == "new" ? 2 : 1,
                    title: title,
                    coverURL: nil,
                    platforms: [],
                    genres: [],
                    rating: nil,
                    matchReason: "reason",
                    matchTags: [],
                    confidence: nil
                )
            ],
            fallbackUsed: false,
            disclaimer: nil
        )
    }
}

private final class ImmediateAISearchAssistUseCase: FetchAISearchAssistUseCase {
    func execute(query: String, platforms: [String], genres: [String]) async throws -> AISearchAssistResult {
        AISearchAssistResult(
            requestId: "immediate",
            originalQuery: query,
            normalizedQuery: query,
            intent: nil,
            suggestedQueries: [],
            items: [
                AISearchAssistItem(
                    gameId: 1942,
                    title: "Stardew Valley",
                    coverURL: nil,
                    platforms: [],
                    genres: [],
                    rating: nil,
                    matchReason: "reason",
                    matchTags: [],
                    confidence: nil
                )
            ],
            fallbackUsed: false,
            disclaimer: nil
        )
    }
}

private final class DelayedAISearchAssistUseCase: FetchAISearchAssistUseCase {
    private let lock = NSLock()
    private(set) var requestCount = 0

    func execute(query: String, platforms: [String], genres: [String]) async throws -> AISearchAssistResult {
        lock.lock()
        requestCount += 1
        lock.unlock()
        try await Task.sleep(nanoseconds: 200_000_000)
        return AISearchAssistResult(
            requestId: "delayed",
            originalQuery: query,
            normalizedQuery: query,
            intent: nil,
            suggestedQueries: [],
            items: [],
            fallbackUsed: false,
            disclaimer: nil
        )
    }
}

private actor ControlledAISearchAssistUseCase: FetchAISearchAssistUseCase {
    private var continuations: [CheckedContinuation<AISearchAssistResult, Error>] = []

    func execute(query: String, platforms: [String], genres: [String]) async throws -> AISearchAssistResult {
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitForRequestCount(_ count: Int) async {
        while continuations.count < count {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func resume(at index: Int, with result: AISearchAssistResult) {
        continuations[index].resume(returning: result)
    }
}
