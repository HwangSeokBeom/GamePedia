import Foundation

// MARK: - GameDetailState

struct GameDetailState {
    var isLoading: Bool = false
    var game: GameDetail? = nil
    var reviews: [Review] = []
    var reviewSummary: ReviewSummary? = nil
    var myReview: Review? = nil
    var isFavorite: Bool = false
    var isFavoriteLoading: Bool = false
    var errorMessage: String? = nil
    var translatedTitle: String? = nil
    var translatedSummary: String? = nil
    var translatedStoryline: String? = nil

    var title: String { translatedTitle ?? game?.resolvedTitle ?? game?.title ?? "" }
    var summary: String { translatedSummary ?? game?.resolvedSummary ?? game?.summary ?? "" }
    var storyline: String { translatedStoryline ?? game?.resolvedStoryline ?? game?.storyline ?? "" }

    var resolvedTitle: String { title }
    var resolvedSummary: String { summary }
    var resolvedStoryline: String { storyline }

    var previewReviews: [Review] {
        Array(reviews.prefix(3))
    }

    var writeReviewButtonTitle: String {
        myReview == nil ? "리뷰 작성" : "리뷰 수정"
    }

    var reviewSummaryText: String {
        if let reviewSummary {
            return reviewSummary.summaryText
        }
        return reviews.isEmpty ? "아직 리뷰가 없어요" : "유저 리뷰"
    }

    var shouldShowReviewSeeMore: Bool {
        !reviews.isEmpty
    }
}
