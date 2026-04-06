import Foundation

// MARK: - GameDetailState

struct GameDetailState {
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

    var previewReviews: [Review] {
        let myReviews = reviews.filter(\.isMine)
        guard !myReviews.isEmpty else {
            return Array(reviews.prefix(3))
        }

        var preview = Array(myReviews.prefix(3))
        let selectedReviewIDs = Set(preview.map(\.id))
        let remainingSlots = max(0, 3 - preview.count)

        if remainingSlots > 0 {
            preview.append(contentsOf: reviews.filter { !selectedReviewIDs.contains($0.id) }.prefix(remainingSlots))
        }

        return preview
    }

    var writeReviewButtonTitle: String {
        reviews.contains(where: \.isMine)
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
        !reviews.isEmpty
    }

    var showSteamReviewLinkage: Bool {
        game?.hasSteamReview == true
    }
}
