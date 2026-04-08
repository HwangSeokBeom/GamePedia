import Foundation

enum ReviewDiscussionThreadPresentation {
    static let summaryReplyLimit = 3
}

enum ReviewDiscussionScreenType: Equatable {
    case discussion
    case commentDetail(parentCommentId: String)
    case replyDetail(parentCommentId: String, highlightedCommentId: String)

    var focusedParentCommentId: String? {
        switch self {
        case .discussion:
            return nil
        case .commentDetail(let parentCommentId), .replyDetail(let parentCommentId, _):
            return parentCommentId
        }
    }

    var allowsThreadCTA: Bool {
        if case .discussion = self {
            return true
        }
        return false
    }

    var usesLatestReplySummary: Bool {
        true
    }

    var prefersToggleAboveReplies: Bool {
        true
    }

    var isFocusedThreadScreen: Bool {
        switch self {
        case .discussion:
            return false
        case .commentDetail, .replyDetail:
            return true
        }
    }
}

struct ReviewDiscussionCommentThreadState: Equatable {
    let rootComment: ReviewComment
    let allReplies: [ReviewComment]
    let summaryReplies: [ReviewComment]
    let visibleReplies: [ReviewComment]
    let isCollapsed: Bool
    let hiddenOlderRepliesCount: Int
    let shouldShowExpandButton: Bool
    let shouldShowCollapseButton: Bool
    let shouldShowThreadCTA: Bool
    let threadCTAAnchorCommentId: String?
    let threadCTATargetCommentId: String?
    let threadCTATitle: String?
    let lastVisibleReplyId: String?
    let isFocusedThread: Bool

    var parentCommentId: String {
        rootComment.id
    }

    func isLastVisibleReply(commentId: String) -> Bool {
        lastVisibleReplyId == commentId
    }
}

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
    let contextPreviewText: String?
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
        let screenType = discussionScreenType
        let focusedParentCommentId = screenType.focusedParentCommentId

        return comments.reduce(into: 0) { count, comment in
            guard !comment.isDeleted else { return }
            guard let focusedParentCommentId else {
                count += 1
                return
            }

            if comment.id == focusedParentCommentId || comment.parentCommentId == focusedParentCommentId {
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
            contextPreviewText: composerContextPreviewText,
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
        case .reply(let context):
            return context.isSelfReply
                ? L10n.tr("Localizable", "review.comment.composer.selfReplying")
                : L10n.tr("Localizable", "review.comment.composer.replyingTo", context.targetNickname)
        case .edit:
            return L10n.tr("Localizable", "review.comment.composer.editing")
        }
    }

    var composerContextPreviewText: String? {
        switch composerMode {
        case .reply(let context):
            return context.targetPreviewText
        case .comment, .edit:
            return nil
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

    var discussionScreenType: ReviewDiscussionScreenType {
        guard let initialHighlightCommentId else { return .discussion }
        let highlightedComment = comments.first(where: { $0.id == initialHighlightCommentId })
            ?? allComments.first(where: { $0.id == initialHighlightCommentId })

        guard let highlightedComment else { return .discussion }

        if let parentCommentId = highlightedComment.parentCommentId {
            return .replyDetail(parentCommentId: parentCommentId, highlightedCommentId: highlightedComment.id)
        }

        return .commentDetail(parentCommentId: highlightedComment.id)
    }

    var commentThreadStates: [ReviewDiscussionCommentThreadState] {
        let screenType = discussionScreenType
        let focusedParentCommentId = screenType.focusedParentCommentId
        let topLevelComments = comments.filter { $0.parentCommentId == nil }
        let visibleTopLevelComments: [ReviewComment]
        if let focusedParentCommentId {
            visibleTopLevelComments = topLevelComments.filter { $0.id == focusedParentCommentId }
        } else {
            visibleTopLevelComments = topLevelComments
        }
        let repliesByParentId = Dictionary(
            grouping: comments.filter { $0.parentCommentId != nil },
            by: { $0.parentCommentId ?? "" }
        )

        return visibleTopLevelComments.map { rootComment in
            let replies = (repliesByParentId[rootComment.id] ?? []).sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id < rhs.id
            }
            let isFocusedThread = focusedParentCommentId == rootComment.id
            let summaryReplies = summarizedReplies(from: replies)
            let isExpanded = expandedParentCommentIds.contains(rootComment.id)
            let isCollapsed = !isExpanded && replies.count > summaryReplies.count
            let visibleReplies = isExpanded ? replies : summaryReplies
            let hiddenOlderRepliesCount = isCollapsed ? max(0, replies.count - visibleReplies.count) : 0
            let threadCTA = threadCTA(
                rootComment: rootComment,
                replies: replies,
                visibleReplies: visibleReplies,
                screenType: screenType
            )

            return ReviewDiscussionCommentThreadState(
                rootComment: rootComment,
                allReplies: replies,
                summaryReplies: summaryReplies,
                visibleReplies: visibleReplies,
                isCollapsed: isCollapsed,
                hiddenOlderRepliesCount: hiddenOlderRepliesCount,
                shouldShowExpandButton: hiddenOlderRepliesCount > 0,
                shouldShowCollapseButton: false,
                shouldShowThreadCTA: threadCTA.anchorCommentId != nil && threadCTA.targetCommentId != nil && threadCTA.title != nil,
                threadCTAAnchorCommentId: threadCTA.anchorCommentId,
                threadCTATargetCommentId: threadCTA.targetCommentId,
                threadCTATitle: threadCTA.title,
                lastVisibleReplyId: visibleReplies.last?.id,
                isFocusedThread: isFocusedThread
            )
        }
    }

    private func summarizedReplies(from replies: [ReviewComment]) -> [ReviewComment] {
        guard replies.count > ReviewDiscussionThreadPresentation.summaryReplyLimit else {
            return replies
        }

        return Array(replies.suffix(ReviewDiscussionThreadPresentation.summaryReplyLimit))
    }

    private func threadCTA(
        rootComment: ReviewComment,
        replies: [ReviewComment],
        visibleReplies: [ReviewComment],
        screenType: ReviewDiscussionScreenType
    ) -> (anchorCommentId: String?, targetCommentId: String?, title: String?) {
        guard screenType.allowsThreadCTA else {
            return (nil, nil, nil)
        }

        if visibleReplies.isEmpty {
            guard rootComment.canReply else { return (nil, nil, nil) }
            return (
                anchorCommentId: rootComment.id,
                targetCommentId: rootComment.id,
                title: L10n.tr("Localizable", "review.comment.replyPrompt.root")
            )
        }

        if let target = visibleReplies.last(where: { $0.canReply }) {
            return (
                anchorCommentId: visibleReplies.last?.id,
                targetCommentId: target.id,
                title: L10n.tr("Localizable", "review.comment.replyPrompt.reply")
            )
        }

        if let target = replies.last(where: { $0.canReply }) {
            return (
                anchorCommentId: visibleReplies.last?.id,
                targetCommentId: target.id,
                title: L10n.tr("Localizable", "review.comment.replyPrompt.reply")
            )
        }

        guard rootComment.canReply else { return (nil, nil, nil) }
        return (
            anchorCommentId: visibleReplies.last?.id,
            targetCommentId: rootComment.id,
            title: L10n.tr("Localizable", "review.comment.replyPrompt.reply")
        )
    }
}
