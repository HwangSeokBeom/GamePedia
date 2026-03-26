import Foundation

enum ReviewMapper {

    static func toEntity(_ dto: ReviewDTO) -> Review {
        Review(
            id: dto.id,
            gameId: dto.gameId,
            rating: dto.rating,
            content: dto.content,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            author: ReviewAuthor(
                id: dto.author.id,
                nickname: dto.author.nickname,
                profileImageUrl: dto.author.profileImageUrl
            ),
            isMine: dto.isMine
        )
    }

    static func toSummaryEntity(_ dto: ReviewSummaryDTO) -> ReviewSummary {
        ReviewSummary(
            reviewCount: dto.reviewCount,
            averageRating: dto.averageRating
        )
    }

    static func toFeedEntity(_ dataDTO: ReviewListResponseDataDTO) -> GameReviewFeed {
        GameReviewFeed(
            reviews: dataDTO.reviews.map(toEntity),
            summary: toSummaryEntity(dataDTO.meta)
        )
    }

    static func toDeletionResult(_ dto: DeleteReviewResponseDataDTO) -> ReviewDeletionResult {
        ReviewDeletionResult(
            deleted: dto.deleted,
            reviewId: dto.reviewId
        )
    }
}
