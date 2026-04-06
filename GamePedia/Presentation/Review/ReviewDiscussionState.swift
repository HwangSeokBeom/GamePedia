import Foundation

struct ReviewDiscussionState: Equatable {
    let gameId: Int
    let initialGameTitle: String?
    let reviewId: String
    let initialHighlightCommentId: String?

    var review: Review? = nil
    var resolvedGameTitle: String? = nil
    var isLoading: Bool = false
    var comments: [ReviewComment] = []
    var expandedParentCommentIds: Set<String> = []
    var composerText: String = ""
    var composerMode: ReviewDiscussionComposerMode = .comment
    var isSubmitting: Bool = false
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

    var canSubmit: Bool {
        !isSubmitting && !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && review != nil
    }

    var emptyMessage: String {
        L10n.tr("Localizable", "review.comment.empty")
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
