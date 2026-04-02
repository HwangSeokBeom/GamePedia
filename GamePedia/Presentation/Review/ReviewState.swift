import Foundation

enum ReviewComposerMode: Equatable {
    case create
    case edit(reviewId: String)
}

// MARK: - ReviewState

struct ReviewState {
    private enum ValidationConstants {
        static let minimumReviewLength = 10
    }

    let gameId: Int
    let gameName: String
    let gameSubtitle: String
    let gameThumbnailURL: String
    let maxChars: Int
    let mode: ReviewComposerMode

    var rating: Float
    var reviewText: String
    var charCount: Int
    var isSubmitting: Bool
    var isDeleting: Bool
    var submitEnabled: Bool
    var didSubmitSuccessfully: Bool
    var didDeleteSuccessfully: Bool
    var errorMessage: String?

    init(
        gameId: Int,
        gameName: String,
        gameSubtitle: String = "",
        gameThumbnailURL: String,
        existingReview: Review? = nil,
        maxChars: Int = 500
    ) {
        self.gameId = gameId
        self.gameName = gameName
        self.gameSubtitle = gameSubtitle
        self.gameThumbnailURL = gameThumbnailURL
        self.maxChars = maxChars
        self.mode = existingReview.map { .edit(reviewId: $0.id) } ?? .create
        self.rating = Float(existingReview?.rating ?? 0)
        self.reviewText = existingReview?.content ?? ""
        self.charCount = self.reviewText.count
        self.isSubmitting = false
        self.isDeleting = false
        self.submitEnabled = self.rating > 0
            && self.reviewText.trimmingCharacters(in: .whitespacesAndNewlines).count >= ValidationConstants.minimumReviewLength
        self.didSubmitSuccessfully = false
        self.didDeleteSuccessfully = false
        self.errorMessage = nil
    }

    var formattedRating: String {
        L10n.tr("Localizable", "review.rating.outOfFive", LocalizedNumberFormatter.oneFraction(Double(rating)))
    }

    var formattedCharCount: String {
        L10n.Review.Count.characters(charCount, maxChars)
    }

    var trimmedReviewText: String {
        reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasSelectedRating: Bool {
        rating > 0
    }

    var hasValidReviewText: Bool {
        trimmedReviewText.count >= ValidationConstants.minimumReviewLength
    }

    var validationMessage: String? {
        if !hasSelectedRating {
            return L10n.Review.Validation.selectRating
        }

        if trimmedReviewText.isEmpty {
            return L10n.Review.Validation.enterContent
        }

        if trimmedReviewText.count < ValidationConstants.minimumReviewLength {
            return L10n.Review.Validation.minLength(ValidationConstants.minimumReviewLength)
        }

        return nil
    }

    var isEditing: Bool {
        if case .edit = mode {
            return true
        }
        return false
    }

    var reviewId: String? {
        if case .edit(let reviewId) = mode {
            return reviewId
        }
        return nil
    }

    var navigationTitle: String {
        isEditing ? L10n.Review.Navigation.edit : L10n.Review.Navigation.create
    }

    var submitButtonTitle: String {
        isEditing ? L10n.Review.Button.save : L10n.Review.Button.submit
    }

    var submitLoadingTitle: String {
        isEditing ? L10n.Review.Button.saving : L10n.Review.Button.submitting
    }

    var deleteButtonTitle: String {
        isDeleting ? L10n.Review.Button.deleting : L10n.Review.Button.delete
    }

    var isProcessing: Bool {
        isSubmitting || isDeleting
    }
}
