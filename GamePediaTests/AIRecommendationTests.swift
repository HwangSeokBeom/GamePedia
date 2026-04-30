import XCTest
@testable import GamePedia

final class AIRecommendationTests: XCTestCase {
    func testState_enablesRecommendButtonOnlyForTrimmedQueryWithAtLeastTwoCharactersAndNotLoading() {
        var state = AIRecommendationState()

        state.query = " a "
        XCTAssertFalse(state.isRecommendButtonEnabled)

        state.query = " 힐링 "
        XCTAssertTrue(state.isRecommendButtonEnabled)

        state.isLoading = true
        XCTAssertFalse(state.isRecommendButtonEnabled)
    }

    func testReducer_updatesFavoriteStateAndFavoriteUpdatingFlagForMatchingGameOnly() {
        let firstItem = makeItem(gameId: 1, isFavorite: false)
        let secondItem = makeItem(gameId: 2, isFavorite: false)
        var state = AIRecommendationState(recommendations: [firstItem, secondItem])

        state = AIRecommendationReducer.reduce(state, .setFavorite(gameId: 1, isFavorite: true))
        state = AIRecommendationReducer.reduce(state, .setFavoriteUpdating(gameId: 1, isUpdating: true))

        XCTAssertTrue(state.recommendations[0].isFavorite)
        XCTAssertTrue(state.recommendations[0].isFavoriteUpdating)
        XCTAssertFalse(state.recommendations[1].isFavorite)
        XCTAssertFalse(state.recommendations[1].isFavoriteUpdating)
    }

    func testErrorMapping_usesFinalUserFacingMessagesForServerCodes() {
        XCTAssertEqual(
            AIRecommendationError.from(serverCode: "AI_DAILY_LIMIT_EXCEEDED", message: nil).errorDescription,
            "오늘 사용할 수 있는 AI 추천 횟수를 모두 사용했어요."
        )
        XCTAssertEqual(
            AIRecommendationError.from(serverCode: "VALIDATION_FAILED", message: nil).errorDescription,
            "입력 내용을 확인해 주세요."
        )
        XCTAssertEqual(
            AIRecommendationError.from(serverCode: "CANDIDATE_NOT_FOUND", message: nil).errorDescription,
            "조건에 맞는 게임을 찾지 못했어요. 다른 표현으로 다시 시도해 주세요."
        )
    }

    func testWrapperDTO_decodesFinalServerSuccessContract() throws {
        let json = """
        {
          "success": true,
          "data": {
            "requestId": "ai-rec-test",
            "normalizedQuery": "짧게 즐기는 힐링 게임",
            "intent": {
              "mood": ["relaxing"],
              "sessionLength": "short",
              "playMode": "singleplayer",
              "difficulty": "low",
              "platforms": []
            },
            "items": [
              {
                "gameId": 1942,
                "title": "Stardew Valley",
                "coverUrl": "",
                "platforms": [],
                "genres": [],
                "rating": null,
                "reason": "긴 설명도 카드에서 안전하게 줄 수 제한으로 표시됩니다.",
                "matchTags": [],
                "confidence": 0.91
              }
            ],
            "disclaimer": "AI 추천은 참고용입니다."
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(
            AIRecommendationResponseEnvelopeDTO<AIRecommendationResponseDTO>.self,
            from: json
        )
        let result = AIRecommendationMapper.toEntity(try XCTUnwrap(response.data))

        XCTAssertTrue(response.success)
        XCTAssertEqual(result.requestId, "ai-rec-test")
        XCTAssertEqual(result.items.first?.gameId, 1942)
        XCTAssertNil(result.items.first?.coverURL)
        XCTAssertNil(result.items.first?.rating)
    }

    func testWrapperDTO_decodesPersonalizedMetaAndFallbackFields() throws {
        let json = """
        {
          "success": true,
          "data": {
            "requestId": "ai-rec-personalized",
            "normalizedQuery": "personalized cozy games",
            "intent": {
              "mood": ["relaxing"],
              "genres": ["Simulator"],
              "keywords": ["cozy"]
            },
            "items": [
              {
                "gameId": "1942",
                "name": "Stardew Valley",
                "imageUrl": "https://example.com/image.jpg",
                "genres": ["Simulator"],
                "rating": 89,
                "reason": "genre match",
                "matchTags": ["relaxing"],
                "confidence": 0.91,
                "source": "personalized-profile",
                "personalized": true,
                "fallbackUsed": false
              }
            ],
            "meta": {
              "personalizationUsed": true,
              "personalizationAvailable": true,
              "fallbackUsed": false,
              "source": "personalized-profile",
              "candidateCount": 42,
              "generatedAt": "2026-04-30T10:00:00Z"
            }
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(
            AIRecommendationResponseEnvelopeDTO<AIRecommendationResponseDTO>.self,
            from: json
        )
        let result = AIRecommendationMapper.toEntity(try XCTUnwrap(response.data))

        XCTAssertEqual(result.items.first?.gameId, 1942)
        XCTAssertEqual(result.items.first?.title, "Stardew Valley")
        XCTAssertEqual(result.items.first?.coverURL?.absoluteString, "https://example.com/image.jpg")
        XCTAssertEqual(result.items.first?.rating, 89)
        XCTAssertEqual(result.items.first?.recommendationSource, "personalized-profile")
        XCTAssertTrue(result.items.first?.personalized == true)
        XCTAssertEqual(result.meta?.personalizationUsed, true)
        XCTAssertEqual(result.meta?.candidateCount, 42)
    }

    func testWrapperDTO_decodesLegacyResponseWithoutMeta() throws {
        let json = """
        {
          "success": true,
          "data": {
            "requestId": "legacy",
            "items": [
              {
                "gameId": 10,
                "title": "Legacy Game",
                "coverUrl": null,
                "rating": 77.5,
                "reason": "A good match."
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(
            AIRecommendationResponseEnvelopeDTO<AIRecommendationResponseDTO>.self,
            from: json
        )
        let result = AIRecommendationMapper.toEntity(try XCTUnwrap(response.data))

        XCTAssertEqual(result.items.first?.title, "Legacy Game")
        XCTAssertNil(result.meta)
        XCTAssertFalse(result.items.first?.personalized == true)
    }

    func testMapper_dropsItemsWithEmptyGameId() throws {
        let json = """
        {
          "success": true,
          "data": {
            "requestId": "drop-empty",
            "items": [
              { "gameId": "", "title": "Broken" },
              { "gameId": "21", "title": "Valid" }
            ]
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(
            AIRecommendationResponseEnvelopeDTO<AIRecommendationResponseDTO>.self,
            from: json
        )
        let result = AIRecommendationMapper.toEntity(try XCTUnwrap(response.data))

        XCTAssertEqual(result.items.map(\.title), ["Valid"])
    }

    func testMapper_usesFallbackReasonWhenReasonIsEmpty() throws {
        let json = """
        {
          "success": true,
          "data": {
            "requestId": "empty-reason",
            "items": [
              { "gameId": "21", "title": "Valid", "reason": "   " }
            ]
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(
            AIRecommendationResponseEnvelopeDTO<AIRecommendationResponseDTO>.self,
            from: json
        )
        let result = AIRecommendationMapper.toEntity(try XCTUnwrap(response.data))

        XCTAssertEqual(
            result.items.first?.reason,
            L10n.tr("Localizable", "ai_recommendation_default_reason_query_match")
        )
    }

    func testItemViewState_keepsRawTagsAndUsesLocalizedDisplayTags() {
        let item = AIRecommendationItemViewState(
            gameId: 1942,
            title: "Burgie",
            coverURL: nil,
            platforms: [],
            genres: [],
            ratingText: "—",
            reason: "reason",
            matchTags: ["relaxing", "kitchen", "game"],
            confidence: nil,
            isFavorite: false,
            isFavoriteUpdating: false
        )

        XCTAssertEqual(item.rawMatchTags, ["relaxing", "kitchen", "game"])
        XCTAssertEqual(item.matchTags, ["relaxing", "kitchen", "game"])
        XCTAssertEqual(
            RecommendationTagLocalizer.localizedTags(
                for: item.rawMatchTags,
                language: .korean,
                screen: "Test"
            ),
            ["힐링", "요리", "게임"]
        )
    }

    func testTagLocalizer_normalizesCommonEnglishTagVariants() {
        XCTAssertEqual(RecommendationTagLocalizer.localizedTag(for: " Role-playing (RPG) ", language: .korean, screen: "Test"), "RPG")
        XCTAssertEqual(RecommendationTagLocalizer.localizedTag(for: "role_playing", language: .korean, screen: "Test"), "RPG")
        XCTAssertEqual(RecommendationTagLocalizer.localizedTag(for: "single player", language: .korean, screen: "Test"), "싱글플레이")
        XCTAssertEqual(RecommendationTagLocalizer.localizedTag(for: "story-rich", language: .korean, screen: "Test"), "스토리 중심")
        XCTAssertEqual(RecommendationTagLocalizer.localizedTag(for: "online co-op", language: .korean, screen: "Test"), "온라인 협동")
    }

    func testRecommendationTagLocalizer_supportsFourAppLanguages() {
        let rawTags = ["relaxing", "single player", "Simulation", "story-rich"]

        XCTAssertEqual(
            RecommendationTagLocalizer.localizedTags(for: rawTags, language: .korean, screen: "Test"),
            ["힐링", "싱글플레이", "시뮬레이션", "스토리 중심"]
        )
        XCTAssertEqual(
            RecommendationTagLocalizer.localizedTags(for: rawTags, language: .english, screen: "Test"),
            ["Relaxing", "Singleplayer", "Simulation", "Story Rich"]
        )
        XCTAssertEqual(
            RecommendationTagLocalizer.localizedTags(for: rawTags, language: .japanese, screen: "Test"),
            ["癒やし", "シングルプレイ", "シミュレーション", "物語重視"]
        )
        XCTAssertEqual(
            RecommendationTagLocalizer.localizedTags(for: rawTags, language: .chinese, screen: "Test"),
            ["治愈", "单人", "模拟", "剧情丰富"]
        )
    }

    func testRecommendationTagLocalizer_unknownTagUsesReadableFallback() {
        XCTAssertEqual(
            RecommendationTagLocalizer.localizedTag(for: "experimental-tag", language: .english, screen: "Test"),
            "Experimental Tag"
        )
        XCTAssertEqual(
            RecommendationTagLocalizer.unknownFallbackCount(for: ["relaxing", "experimental-tag"], language: .english),
            1
        )
    }

    func testRecommendationTagLocalizer_localizesKnownRecommendationReason() {
        XCTAssertEqual(
            RecommendationTagLocalizer.localizedKnownRecommendationReason(
                for: "자주 즐기는 장르와 잘 맞아요",
                language: .english,
                screen: "Test"
            ),
            "Matches genres you often play"
        )
        XCTAssertEqual(
            RecommendationTagLocalizer.localizedKnownRecommendationReason(
                for: "matches genres you often play",
                language: .chinese,
                screen: "Test"
            ),
            "与你常玩的类型很匹配"
        )
    }

    func testState_personalizationHelperMessagesFollowMeta() {
        var state = AIRecommendationState()

        state = AIRecommendationReducer.reduce(
            state,
            .setPersonalizationMetadata(
                personalizationUsed: true,
                personalizationAvailable: true,
                fallbackUsed: false,
                recommendationSource: "profile",
                generatedAt: nil
            )
        )
        XCTAssertEqual(state.helperMessage, L10n.tr("Localizable", "ai_recommendation_personalized_notice"))

        state = AIRecommendationReducer.reduce(
            state,
            .setPersonalizationMetadata(
                personalizationUsed: false,
                personalizationAvailable: false,
                fallbackUsed: false,
                recommendationSource: "popular",
                generatedAt: nil
            )
        )
        XCTAssertEqual(state.helperMessage, L10n.tr("Localizable", "ai_recommendation_personalization_unavailable_notice"))

        state = AIRecommendationReducer.reduce(
            state,
            .setPersonalizationMetadata(
                personalizationUsed: false,
                personalizationAvailable: true,
                fallbackUsed: true,
                recommendationSource: "fallback",
                generatedAt: nil
            )
        )
        XCTAssertEqual(state.helperMessage, L10n.tr("Localizable", "ai_recommendation_fallback_notice"))
    }

    func testViewModel_buildsDisplayTagsFromMatchTagsAndGenresAndMarksReviewChangesStale() async {
        let useCase = ImmediateAIRecommendationUseCase()
        let viewModel = AIRecommendationViewModel(
            fetchAIRecommendationsUseCase: useCase,
            fetchMyFavoritesUseCase: FetchMyFavoritesUseCase(favoriteRepository: EmptyFavoriteRepository()),
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: EmptyFavoriteRepository())
        )

        viewModel.send(.queryChanged("퇴근 후 힐링 게임"))
        viewModel.send(.recommendButtonTapped)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.state.recommendations.first?.displayTags, ["맞춤", "힐링", "시뮬레이션"])
        XCTAssertEqual(viewModel.state.helperMessage, L10n.tr("Localizable", "ai_recommendation_personalized_notice"))

        NotificationCenter.default.post(name: .reviewDidChange, object: nil)
        try? await Task.sleep(nanoseconds: 30_000_000)

        XCTAssertTrue(viewModel.state.isStale)
        XCTAssertEqual(viewModel.state.helperMessage, L10n.tr("Localizable", "ai_recommendation_stale_notice"))
    }

    func testViewModel_localizesServerDisplayTagsAndFallbackTag() async {
        let useCase = EnglishTagAIRecommendationUseCase()
        let viewModel = AIRecommendationViewModel(
            fetchAIRecommendationsUseCase: useCase,
            fetchMyFavoritesUseCase: FetchMyFavoritesUseCase(favoriteRepository: EmptyFavoriteRepository()),
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: EmptyFavoriteRepository())
        )

        viewModel.send(.queryChanged("짧은 비주얼 노벨"))
        viewModel.send(.recommendButtonTapped)
        await waitForRecommendationCount(1, in: viewModel)

        let displayTags = viewModel.state.recommendations.first?.displayTags
        XCTAssertEqual(displayTags, ["힐링 비주얼 노벨", "짧은 인터랙티브 스토리", "비주얼 노벨"])
        XCTAssertFalse(displayTags?.contains("relaxing visual novel") == true)
        XCTAssertFalse(displayTags?.contains("short interactive story") == true)
        XCTAssertFalse(displayTags?.contains("Visual Novel") == true)
    }

    func testViewModel_localizesFallbackRankingAndLimitsTags() async {
        let useCase = FallbackAIRecommendationUseCase()
        let viewModel = AIRecommendationViewModel(
            fetchAIRecommendationsUseCase: useCase,
            fetchMyFavoritesUseCase: FetchMyFavoritesUseCase(favoriteRepository: EmptyFavoriteRepository()),
            toggleFavoriteUseCase: ToggleFavoriteUseCase(favoriteRepository: EmptyFavoriteRepository())
        )

        viewModel.send(.queryChanged("추천"))
        viewModel.send(.recommendButtonTapped)
        await waitForRecommendationCount(1, in: viewModel)

        XCTAssertEqual(viewModel.state.recommendations.first?.displayTags, ["힐링", "RPG", "기본 정렬"])
    }

    private func makeItem(gameId: Int, isFavorite: Bool) -> AIRecommendationItemViewState {
        AIRecommendationItemViewState(
            gameId: gameId,
            title: "Game \(gameId)",
            coverURL: nil,
            platforms: [],
            genres: [],
            ratingText: "—",
            reason: "reason",
            matchTags: [],
            confidence: nil,
            isFavorite: isFavorite,
            isFavoriteUpdating: false
        )
    }

    private func waitForRecommendationCount(
        _ expectedCount: Int,
        in viewModel: AIRecommendationViewModel,
        retryCount: Int = 50
    ) async {
        for _ in 0..<retryCount {
            if viewModel.state.recommendations.count == expectedCount {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private final class ImmediateAIRecommendationUseCase: FetchAIRecommendationsUseCase {
    func execute(query: String) async throws -> AIRecommendationResult {
        AIRecommendationResult(
            requestId: "immediate",
            normalizedQuery: query,
            intent: nil,
            items: [
                AIRecommendation(
                    gameId: 1942,
                    title: "Stardew Valley",
                    coverURL: nil,
                    platforms: ["PC"],
                    genres: ["Simulator", "experimental-tag"],
                    rating: nil,
                    reason: "reason",
                    matchTags: ["relaxing"],
                    confidence: nil,
                    recommendationSource: "test",
                    personalized: true,
                    fallbackUsed: false
                )
            ],
            meta: AIRecommendationMeta(
                personalizationUsed: true,
                personalizationAvailable: true,
                fallbackUsed: false,
                source: "test",
                candidateCount: 1,
                generatedAt: nil
            ),
            disclaimer: nil
        )
    }
}

private final class EnglishTagAIRecommendationUseCase: FetchAIRecommendationsUseCase {
    func execute(query: String) async throws -> AIRecommendationResult {
        AIRecommendationResult(
            requestId: "english-tags",
            normalizedQuery: query,
            intent: nil,
            items: [
                AIRecommendation(
                    gameId: 77,
                    title: "Story Game",
                    coverURL: nil,
                    platforms: [],
                    genres: ["Visual Novel"],
                    rating: nil,
                    reason: "reason",
                    matchTags: ["relaxing visual novel", "short interactive story", "Visual Novel"],
                    displayTags: ["Visual Novel"],
                    canonicalTags: ["visual_novel"],
                    keywords: ["interactive_story"],
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

private final class FallbackAIRecommendationUseCase: FetchAIRecommendationsUseCase {
    func execute(query: String) async throws -> AIRecommendationResult {
        AIRecommendationResult(
            requestId: "fallback-tags",
            normalizedQuery: query,
            intent: nil,
            items: [
                AIRecommendation(
                    gameId: 88,
                    title: "Fallback Game",
                    coverURL: nil,
                    platforms: [],
                    genres: ["RPG"],
                    rating: nil,
                    reason: "reason",
                    matchTags: ["relaxing", "rpg", "RPG"],
                    confidence: nil,
                    recommendationSource: "fallback",
                    personalized: false,
                    fallbackUsed: true
                )
            ],
            meta: AIRecommendationMeta(
                personalizationUsed: false,
                personalizationAvailable: true,
                fallbackUsed: true,
                source: "fallback",
                candidateCount: 1,
                generatedAt: nil
            ),
            disclaimer: nil
        )
    }
}

private struct EmptyFavoriteRepository: FavoriteRepository {
    func addFavorite(gameId: String) async throws -> FavoriteMutationResult {
        FavoriteMutationResult(gameId: Int(gameId) ?? 0, isFavorite: true)
    }

    func removeFavorite(gameId: String) async throws -> FavoriteMutationResult {
        FavoriteMutationResult(gameId: Int(gameId) ?? 0, isFavorite: false)
    }

    func fetchMyFavorites(sort: FavoriteSortOption?) async throws -> [FavoriteItem] {
        []
    }

    func fetchFavoriteStatus(gameId: String) async throws -> FavoriteStatus {
        FavoriteStatus(isFavorite: false)
    }
}
