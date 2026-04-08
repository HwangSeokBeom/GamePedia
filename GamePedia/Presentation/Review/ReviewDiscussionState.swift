import Foundation

struct ReviewDiscussionHeaderState: Equatable {
    let review: Review
    let gameId: Int
    let gameTitle: String
    let isLikeLoading: Bool
}

enum ReviewDiscussionContentState: Equatable {
    case loading
    case empty
    case populated

    var isEmpty: Bool {
        if case .empty = self {
            return true
        }
        return false
    }
}

struct ReviewDiscussionSectionState: Equatable {
    let commentCount: Int
    let contentState: ReviewDiscussionContentState
    let sortTitle: String
}

struct ReviewDiscussionComposerState: Equatable {
    let text: String
    let mode: ReviewDiscussionComposerMode
    let isSubmitting: Bool
    let canSubmit: Bool
    let placeholder: String
    let contextText: String?
    let submitTitle: String
}

struct ReviewDiscussionState: Equatable {
    let gameId: Int
    let initialGameTitle: String?
    let reviewId: String
    let initialHighlightCommentId: String?

    var review: Review? = nil
    var resolvedGameTitle: String? = nil
    var isLoading: Bool = false
    var allComments: [ReviewComment] = []
    var comments: [ReviewComment] = []
    var sortOption: ReviewCommentSortOption = .latest
    var expandedParentCommentIds: Set<String> = []
    var composerText: String = ""
    var composerMode: ReviewDiscussionComposerMode = .comment
    var isSubmitting: Bool = false
    var reactingReviewIds: Set<String> = []
    var reactingCommentIds: Set<String> = []
    var errorMessage: String? = nil
    var inlineNoticeMessage: String? = nil
    var highlightedCommentId: String? = nil
    var highlightToken: Int = 0

    init(
        gameId: Int,
        initialGameTitle: String?,
        reviewId: String,
        initialHighlightCommentId: String? = nil
    ) {
        self.gameId = gameId
        self.initialGameTitle = initialGameTitle
        self.reviewId = reviewId
        self.initialHighlightCommentId = initialHighlightCommentId
        self.highlightedCommentId = initialHighlightCommentId
        if initialHighlightCommentId != nil {
            self.highlightToken = 1
        }
    }

    var navigationTitle: String {
        resolvedGameTitle ?? initialGameTitle ?? L10n.tr("Localizable", "review.discussion.navigation")
    }

    var discussionContext: ReviewDiscussionContext? {
        guard let review else { return nil }
        return ReviewDiscussionContext(
            gameId: gameId,
            gameTitle: resolvedGameTitle ?? initialGameTitle ?? L10n.Common.Label.untitledGame,
            review: review
        )
    }

    var reviewHeaderState: ReviewDiscussionHeaderState? {
        guard let review else { return nil }
        return ReviewDiscussionHeaderState(
            review: review,
            gameId: gameId,
            gameTitle: navigationTitle,
            isLikeLoading: reactingReviewIds.contains(review.id)
        )
    }

    var discussionContentState: ReviewDiscussionContentState {
        guard review != nil else { return .loading }
        if isLoading && allComments.isEmpty {
            return .loading
        }
        return activeDiscussionCount == 0 ? .empty : .populated
    }

    var totalDiscussionCount: Int {
        if isLoading && allComments.isEmpty {
            return review?.commentCount ?? 0
        }
        return activeDiscussionCount
    }

    private var activeDiscussionCount: Int {
        comments.reduce(into: 0) { count, comment in
            if !comment.isDeleted {
                count += 1
            }
        }
    }

    var discussionSectionState: ReviewDiscussionSectionState? {
        guard review != nil else { return nil }
        return ReviewDiscussionSectionState(
            commentCount: totalDiscussionCount,
            contentState: discussionContentState,
            sortTitle: sortOption.displayTitle
        )
    }

    var composerState: ReviewDiscussionComposerState {
        ReviewDiscussionComposerState(
            text: composerText,
            mode: composerMode,
            isSubmitting: isSubmitting,
            canSubmit: canSubmit,
            placeholder: composerPlaceholder,
            contextText: composerContextText,
            submitTitle: composerSubmitTitle
        )
    }

    var canSubmit: Bool {
        !isSubmitting && !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && review != nil
    }

    var emptyMessage: String {
        L10n.tr("Localizable", "review.comment.empty")
    }

    var emptyStateActionTitle: String {
        totalDiscussionCount == 0
            ? L10n.tr("Localizable", "review.comment.empty.cta")
            : L10n.tr("Localizable", "review.comment.empty.nonEmptyCta")
    }

    var composerContextText: String? {
        switch composerMode {
        case .comment:
            return nil
        case .reply(_, let parentNickname, let isSelfReply):
            return isSelfReply
                ? L10n.tr("Localizable", "review.comment.composer.selfReplying")
                : L10n.tr("Localizable", "review.comment.composer.replyingTo", parentNickname)
        case .edit:
            return L10n.tr("Localizable", "review.comment.composer.editing")
        }
    }

    var composerPlaceholder: String {
        switch composerMode {
        case .comment:
            return L10n.tr("Localizable", "review.comment.composer.placeholder")
        case .reply:
            return L10n.tr("Localizable", "review.comment.composer.replyPlaceholder")
        case .edit:
            return L10n.tr("Localizable", "review.comment.composer.editPlaceholder")
        }
    }

    var composerSubmitTitle: String {
        switch composerMode {
        case .edit:
            return L10n.Common.Button.save
        case .comment, .reply:
            return L10n.tr("Localizable", "review.comment.action.send")
        }
    }
}
