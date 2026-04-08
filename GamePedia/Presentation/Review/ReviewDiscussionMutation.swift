import Foundation

struct ReviewDiscussionReplyContext: Equatable {
    let parentCommentId: String
    let targetCommentId: String
    let targetNickname: String
    let targetPreviewText: String
    let isSelfReply: Bool
}

enum ReviewDiscussionComposerMode: Equatable {
    case comment
    case reply(ReviewDiscussionReplyContext)
    case edit(commentId: String)

    var parentCommentId: String? {
        switch self {
        case .comment:
            return nil
        case .reply(let context):
            return context.parentCommentId
        case .edit:
            return nil
        }
    }
}

enum ReviewDiscussionMutation {
    case setLoading(Bool)
    case setReview(Review, gameTitle: String)
    case replaceReview(Review)
    case setComments([ReviewComment])
    case setSortOption(ReviewCommentSortOption)
    case setExpandedParentCommentIds(Set<String>)
    case setComposerText(String)
    case setComposerMode(ReviewDiscussionComposerMode)
    case setComposerModePreservingText(ReviewDiscussionComposerMode)
    case setSubmitting(Bool)
    case setReviewReactionLoading(reviewId: String, isLoading: Bool)
    case setReactionLoading(commentId: String, isLoading: Bool)
    case replaceComment(ReviewComment)
    case setError(String?)
    case setInlineNotice(String?)
    case triggerHighlight(commentId: String?)
}
