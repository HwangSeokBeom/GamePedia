import Foundation

struct GameReviewsState {
    let gameId: Int
    let gameTitle: String

    var isLoading: Bool = false
    var deletingReviewId: String? = nil
    var reportingReviewId: String? = nil
    var blockingUserId: String? = nil
    var reactingReviewIds: Set<String> = []
    var reviews: [Review] = []
    var reviewSummary: ReviewSummary? = nil
    var errorMessage: String? = nil
    var successMessage: String? = nil

    var hasWrittenReview: Bool {
        reviews.contains(where: \.isMine)
    }

    var isModerationActionInProgress: Bool {
        reportingReviewId != nil || blockingUserId != nil
    }

    var composeButtonTitle: String {
        hasWrittenReview
            ? L10n.tr("Localizable", "review.compose.createAnother")
            : L10n.Review.Compose.create
    }

    var summaryText: String {
        reviewSummary?.summaryText ?? L10n.Review.Empty.noReviews
    }

    var emptyMessage: String {
        L10n.Review.Empty.firstReview
    }
}
