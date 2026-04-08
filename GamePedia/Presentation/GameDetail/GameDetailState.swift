import Foundation

// MARK: - GameDetailState

struct GameDetailState {
    static let reviewPreviewLimit = 5

    var isLoading: Bool = false
    var game: GameDetail? = nil
    var reviews: [Review] = []
    var reviewSummary: ReviewSummary? = nil
    var isFavorite: Bool = false
    var isFavoriteLoading: Bool = false
    var errorMessage: String? = nil
    var blockingLoadErrorMessage: String? = nil
    var inlineNoticeMessage: String? = nil
    var translatedSummary: String? = nil
    var translatedStoryline: String? = nil
    var isTranslationLoading: Bool = false
    var isShowingTranslated: Bool = false
    var translationRequest: TranslationBatchRequest? = nil

    var title: String { game?.title ?? "" }
    var hasRenderableContent: Bool { game != nil }

    var originalSummary: String {
        let originalSummary = game?.summary.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if originalSummary.isEmpty == false {
            return originalSummary
        }
        let originalStoryline = game?.storyline.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if originalStoryline.isEmpty == false {
            return originalStoryline
        }
        return ""
    }

    var displayedTranslatedSummary: String? {
        let originalSummary = game?.summary.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if originalSummary.isEmpty == false {
            return translatedSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return translatedStoryline?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var summary: String {
        if isShowingTranslated,
           let displayedTranslatedSummary,
           displayedTranslatedSummary.isEmpty == false {
            return displayedTranslatedSummary
        }
        return originalSummary
    }

    var storyline: String { translatedStoryline ?? game?.resolvedStoryline ?? game?.storyline ?? "" }

    var resolvedTitle: String { title }
    var resolvedSummary: String { summary }
    var resolvedStoryline: String { storyline }
    var isTranslationAvailable: Bool {
        hasTranslation || translationRequest != nil || isTranslationLoading
    }
    var hasTranslation: Bool {
        guard let displayedTranslatedSummary else { return false }
        return displayedTranslatedSummary.isEmpty == false
    }
    var isTranslated: Bool {
        isShowingTranslated && hasTranslation
    }
    var translationToggleTitle: String {
        isShowingTranslated ? L10n.Translation.Action.showOriginal : L10n.Translation.Action.showTranslated
    }

    /// Game Detail preview policy:
    /// 1. Show community reviews first in the lower "유저 리뷰" section.
    /// 2. If community reviews are fewer than the preview limit, backfill with the
    ///    remaining review feed so the section can still render up to 5 cards.
    /// 3. Duplicates are avoided within the preview section itself, but the same
    ///    review can still appear in "나의 기록" and the lower preview when used
    ///    as fallback content.
    var previewReviews: [Review] {
        let communityReviews = communityPreviewReviews
        guard communityReviews.count < Self.reviewPreviewLimit else {
            return communityReviews
        }

        let selectedReviewIDs = Set(communityReviews.map(\.id))
        let remainingSlots = max(0, Self.reviewPreviewLimit - communityReviews.count)
        let fallbackReviews = reviews.filter { !selectedReviewIDs.contains($0.id) }

        return communityReviews + Array(fallbackReviews.prefix(remainingSlots))
    }

    var myReviews: [Review] {
        reviews.filter(\.isMine)
    }

    var communityPreviewReviews: [Review] {
        Array(reviews.filter { !$0.isMine }.prefix(Self.reviewPreviewLimit))
    }

    var hasMyReviews: Bool {
        !myReviews.isEmpty
    }

    var writeReviewButtonTitle: String {
        hasMyReviews
            ? L10n.tr("Localizable", "detail.button.writeAnotherReview")
            : L10n.Detail.Button.writeReview
    }

    var reviewSummaryText: String {
        if let reviewSummary {
            return reviewSummary.summaryText
        }
        return reviews.isEmpty ? L10n.Detail.Review.none : L10n.Detail.Review.userReviews
    }

    var shouldShowReviewSeeMore: Bool {
        !previewReviews.isEmpty
    }

    var showSteamReviewLinkage: Bool {
        game?.hasSteamReview == true
    }
}
