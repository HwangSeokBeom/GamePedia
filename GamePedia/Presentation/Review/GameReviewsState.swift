import Foundation

struct GameReviewsState {
    let gameId: Int
    let gameTitle: String

    var isLoading: Bool = false
    var deletingReviewId: String? = nil
    var reviews: [Review] = []
    var reviewSummary: ReviewSummary? = nil
    var errorMessage: String? = nil

    var myReview: Review? {
        reviews.first(where: { $0.isMine })
    }

    var composeButtonTitle: String {
        myReview == nil ? "작성" : "수정"
    }

    var summaryText: String {
        reviewSummary?.summaryText ?? "아직 리뷰가 없어요"
    }

    var emptyMessage: String {
        "아직 작성된 리뷰가 없어요.\n첫 리뷰를 남겨보세요."
    }
}
