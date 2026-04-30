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
        XCTAssertEqual(item.displayTags, ["힐링", "요리", "게임"])
    }

    func testTagLocalizer_normalizesCommonEnglishTagVariants() {
        XCTAssertEqual(TagLocalizer.localizedTag(for: " Role-playing (RPG) ", screen: "Test"), "RPG")
        XCTAssertEqual(TagLocalizer.localizedTag(for: "role_playing", screen: "Test"), "RPG")
        XCTAssertEqual(TagLocalizer.localizedTag(for: "single player", screen: "Test"), "싱글플레이")
        XCTAssertEqual(TagLocalizer.localizedTag(for: "story-rich", screen: "Test"), "스토리 중심")
        XCTAssertEqual(TagLocalizer.localizedTag(for: "online co-op", screen: "Test"), "온라인 협동")
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
}
