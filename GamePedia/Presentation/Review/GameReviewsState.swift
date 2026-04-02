import Foundation

struct GameReviewsState {
    let gameId: Int
    let gameTitle: String

    var isLoading: Bool = false
    var deletingReviewId: String? = nil
    var reportingReviewId: String? = nil
    var blockingUserId: String? = nil
    var reviews: [Review] = []
    var reviewSummary: ReviewSummary? = nil
    var errorMessage: String? = nil
    var successMessage: String? = nil

    var myReview: Review? {
        reviews.first(where: { $0.isMine })
    }

    var isModerationActionInProgress: Bool {
        reportingReviewId != nil || blockingUserId != nil
    }

    var composeButtonTitle: String {
        myReview == nil ? L10n.Review.Compose.create : L10n.Review.Compose.edit
    }

    var summaryText: String {
        reviewSummary?.summaryText ?? L10n.Review.Empty.noReviews
    }

    var emptyMessage: String {
        L10n.Review.Empty.firstReview
    }
}
