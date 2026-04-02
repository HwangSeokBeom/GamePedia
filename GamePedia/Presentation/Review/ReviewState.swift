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
        String(format: "%.1f / 5.0", rating)
    }

    var formattedCharCount: String {
        "\(charCount) / \(maxChars)자"
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
            return "별점을 선택해주세요."
        }

        if trimmedReviewText.isEmpty {
            return "리뷰 내용을 입력해주세요."
        }

        if trimmedReviewText.count < ValidationConstants.minimumReviewLength {
            return "리뷰 내용은 10자 이상 작성해주세요."
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
        isEditing ? "리뷰 수정" : "리뷰 작성"
    }

    var submitButtonTitle: String {
        isEditing ? "저장" : "리뷰 작성하기"
    }

    var submitLoadingTitle: String {
        isEditing ? "저장 중..." : "작성 중..."
    }

    var deleteButtonTitle: String {
        isDeleting ? "삭제 중..." : "삭제"
    }

    var isProcessing: Bool {
        isSubmitting || isDeleting
    }
}
