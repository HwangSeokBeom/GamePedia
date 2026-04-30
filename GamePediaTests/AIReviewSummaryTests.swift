import XCTest
@testable import GamePedia

final class AIReviewSummaryTests: XCTestCase {
    func testDTO_decodesStringFallbackDataAsSummary() throws {
        let json = """
        {
          "success": true,
          "data": "AI 리뷰 요약을 불러오지 못했어요. 잠시 후 다시 시도해주세요."
        }
        """

        let response = try JSONDecoder().decode(
            AIReviewSummaryResponseEnvelopeDTO<AIReviewSummaryResponseDTO>.self,
            from: Data(json.utf8)
        )
        let dto = try XCTUnwrap(response.data)
        let summary = AIReviewSummaryMapper.toEntity(dto, fallbackGameId: 376092)

        XCTAssertTrue(response.success)
        XCTAssertEqual(summary.gameId, 376092)
        XCTAssertEqual(summary.summary, "AI 리뷰 요약을 불러오지 못했어요. 잠시 후 다시 시도해주세요.")
        XCTAssertTrue(AIReviewSummaryMapper.hasDisplayableContent(dto))
    }

    func testDTO_decodesFailureEnvelopeWithFallbackSummaryData() throws {
        let json = """
        {
          "success": false,
          "data": {
            "summary": "리뷰가 아직 적어 핵심 의견만 간단히 요약했어요.",
            "reviewCount": "1"
          },
          "error": {
            "code": "AI_REVIEW_SUMMARY_FAILED",
            "message": "model unavailable"
          }
        }
        """

        let response = try JSONDecoder().decode(
            AIReviewSummaryResponseEnvelopeDTO<AIReviewSummaryResponseDTO>.self,
            from: Data(json.utf8)
        )
        let dto = try XCTUnwrap(response.data)
        let summary = AIReviewSummaryMapper.toEntity(dto, fallbackGameId: 376092)

        XCTAssertFalse(response.success)
        XCTAssertEqual(summary.summary, "리뷰가 아직 적어 핵심 의견만 간단히 요약했어요.")
        XCTAssertEqual(summary.reviewCount, 1)
        XCTAssertTrue(AIReviewSummaryMapper.hasDisplayableContent(dto))
    }

    func testDTO_decodesTopLevelFallbackSummaryWhenEnvelopeIsOmitted() throws {
        let json = """
        {
          "summary": "대체 요약입니다.",
          "gameId": "376092",
          "keywords": "소규모 리뷰"
        }
        """

        let response = try JSONDecoder().decode(
            AIReviewSummaryResponseEnvelopeDTO<AIReviewSummaryResponseDTO>.self,
            from: Data(json.utf8)
        )
        let summary = AIReviewSummaryMapper.toEntity(try XCTUnwrap(response.data))

        XCTAssertTrue(response.success)
        XCTAssertEqual(summary.gameId, 376092)
        XCTAssertEqual(summary.summary, "대체 요약입니다.")
        XCTAssertEqual(summary.keywords, ["소규모 리뷰"])
    }

    func testDTO_decodesServerFallbackEnvelope() throws {
        let json = """
        {
          "success": true,
          "data": {
            "gameId": "328386",
            "status": "fallback",
            "reason": "AI_SUMMARY_UNAVAILABLE",
            "fallbackUsed": true,
            "reviewCount": 5,
            "summary": "AI 요약을 일시적으로 생성하지 못했어요. 등록된 리뷰를 기준으로 다시 시도할 수 있습니다.",
            "highlights": null,
            "pros": null,
            "cons": [],
            "generatedAt": "2026-04-30T08:19:28.000Z"
          }
        }
        """

        let response = try JSONDecoder().decode(
            AIReviewSummaryResponseEnvelopeDTO<AIReviewSummaryResponseDTO>.self,
            from: Data(json.utf8)
        )
        let summary = AIReviewSummaryMapper.toEntity(try XCTUnwrap(response.data))

        XCTAssertTrue(response.success)
        XCTAssertEqual(summary.gameId, 328386)
        XCTAssertEqual(summary.status, "fallback")
        XCTAssertEqual(summary.reason, "AI_SUMMARY_UNAVAILABLE")
        XCTAssertTrue(summary.fallbackUsed)
        XCTAssertEqual(summary.reviewCount, 5)
        XCTAssertEqual(summary.summary, "AI 요약을 일시적으로 생성하지 못했어요. 등록된 리뷰를 기준으로 다시 시도할 수 있습니다.")
        XCTAssertEqual(summary.highlights, [])
        XCTAssertEqual(summary.pros, [])
        XCTAssertEqual(summary.cons, [])
    }

    func testDTO_decodesNestedSummaryObjectFromServerFallback() throws {
        let json = """
        {
          "success": true,
          "data": {
            "gameId": 245754,
            "status": "fallback",
            "reason": "AI_SUMMARY_UNAVAILABLE",
            "reviewCount": 5,
            "fallbackUsed": true,
            "summary": {
              "headline": "플레이어 반응이 대체로 긍정적인 게임",
              "overview": "5개의 리뷰와 평균 4.3점을 기준으로 플레이어 반응을 요약했습니다.",
              "pros": ["긍정적인 플레이 경험 언급"],
              "cons": [],
              "keywords": ["player reviews", "review summary"],
              "reviewCount": 5
            }
          }
        }
        """

        let response = try JSONDecoder().decode(
            AIReviewSummaryResponseEnvelopeDTO<AIReviewSummaryResponseDTO>.self,
            from: Data(json.utf8)
        )
        let summary = AIReviewSummaryMapper.toEntity(try XCTUnwrap(response.data))

        XCTAssertEqual(summary.status, "fallback")
        XCTAssertEqual(summary.reviewCount, 5)
        XCTAssertTrue(summary.summary.contains("플레이어 반응이 대체로 긍정적인 게임"))
        XCTAssertEqual(summary.pros, ["긍정적인 플레이 경험 언급"])
        XCTAssertEqual(summary.cons, [])
        XCTAssertEqual(summary.keywords, ["player reviews", "review summary"])
    }

    func testDTO_emptyNoReviewsBuildsDisplayableMessage() throws {
        let json = """
        {
          "success": true,
          "data": {
            "gameId": 328386,
            "status": "empty",
            "reason": "NO_REVIEWS",
            "fallbackUsed": false,
            "reviewCount": 0,
            "summary": null
          }
        }
        """

        let response = try JSONDecoder().decode(
            AIReviewSummaryResponseEnvelopeDTO<AIReviewSummaryResponseDTO>.self,
            from: Data(json.utf8)
        )
        let summary = AIReviewSummaryMapper.toEntity(try XCTUnwrap(response.data))

        XCTAssertEqual(summary.status, "empty")
        XCTAssertFalse(summary.fallbackUsed)
        XCTAssertEqual(summary.reviewCount, 0)
        XCTAssertEqual(summary.summary, "아직 요약할 리뷰가 없어요.")
    }
}
