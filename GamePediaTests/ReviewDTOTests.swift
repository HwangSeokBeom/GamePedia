import XCTest
@testable import GamePedia

final class ReviewDTOTests: XCTestCase {
    func testReviewDTO_decodesFlatAuthorFallbackFields() throws {
        let json = """
        {
          "id": "review-1",
          "gameId": "376092",
          "rating": 4.5,
          "content": "bb review",
          "createdAt": "2026-04-07T00:00:00Z",
          "updatedAt": "2026-04-07T00:00:00Z",
          "authorId": "user-bb",
          "authorNickname": "bb",
          "authorProfileImageUrl": "https://example.com/bb.png",
          "isMine": false,
          "likeCount": 3,
          "commentCount": 2,
          "isLikedByCurrentUser": true
        }
        """

        let dto = try JSONDecoder().decode(ReviewDTO.self, from: Data(json.utf8))

        XCTAssertEqual(dto.id, "review-1")
        XCTAssertEqual(dto.author.id, "user-bb")
        XCTAssertEqual(dto.author.nickname, "bb")
        XCTAssertEqual(dto.author.profileImageUrl, "https://example.com/bb.png")
        XCTAssertEqual(dto.likeCount, 3)
        XCTAssertEqual(dto.commentCount, 2)
        XCTAssertTrue(dto.isLikedByCurrentUser)
    }

    func testReview_togglingLikeOptimisticallyUpdatesState() {
        let review = Review(
            id: "review-1",
            gameId: "376092",
            rating: 4.0,
            content: "review",
            createdAt: "2026-04-07T00:00:00Z",
            updatedAt: "2026-04-07T00:00:00Z",
            author: ReviewAuthor(id: "user-bb", nickname: "bb", profileImageUrl: nil),
            isMine: false,
            likeCount: 4,
            commentCount: 1,
            isLikedByCurrentUser: false
        )

        let likedReview = review.togglingLikeOptimistically()
        XCTAssertTrue(likedReview.isLikedByCurrentUser)
        XCTAssertEqual(likedReview.likeCount, 5)

        let unlikedReview = likedReview.togglingLikeOptimistically()
        XCTAssertFalse(unlikedReview.isLikedByCurrentUser)
        XCTAssertEqual(unlikedReview.likeCount, 4)
    }
}
