import Foundation

// MARK: - GameDetailIntent

enum GameDetailIntent {
    case viewDidLoad(gameId: Int)
    case didTapHaveIt
    case didTapWriteReview
    case didTapReviewLike(reviewId: String)
    case didTapSeeAllReviews
    case didTapShare
    case didTapTranslationToggle
    case didReceiveTranslationResults([TranslationResultItem])
    case aiReviewSummaryRequested
    case aiReviewSummaryRetryTapped
    case aiReviewSummaryExpandTapped
}
