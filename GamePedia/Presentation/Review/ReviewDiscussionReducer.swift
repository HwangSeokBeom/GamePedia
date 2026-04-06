import Foundation

enum ReviewDiscussionReducer {
    static func reduce(_ state: ReviewDiscussionState, _ mutation: ReviewDiscussionMutation) -> ReviewDiscussionState {
        var state = state

        switch mutation {
        case .setLoading(let isLoading):
            state.isLoading = isLoading
            if isLoading {
                state.errorMessage = nil
            }
        case .setReview(let review, let gameTitle):
            state.review = review
            state.resolvedGameTitle = gameTitle
            state.errorMessage = nil
        case .setComments(let comments):
            state.comments = comments
        case .setExpandedParentCommentIds(let ids):
            state.expandedParentCommentIds = ids
        case .setComposerText(let text):
            state.composerText = text
        case .setComposerMode(let mode):
            state.composerMode = mode
            if case .comment = mode {
                state.composerText = ""
            }
        case .setSubmitting(let isSubmitting):
            state.isSubmitting = isSubmitting
        case .setReactionLoading(let commentId, let isLoading):
            if isLoading {
                state.reactingCommentIds.insert(commentId)
            } else {
                state.reactingCommentIds.remove(commentId)
            }
        case .replaceComment(let updatedComment):
            if let index = state.comments.firstIndex(where: { $0.id == updatedComment.id }) {
                state.comments[index] = updatedComment
            }
        case .setError(let message):
            state.errorMessage = message
            state.isLoading = false
            state.isSubmitting = false
        case .setInlineNotice(let message):
            state.inlineNoticeMessage = message
        case .triggerHighlight(let commentId):
            state.highlightedCommentId = commentId
            state.highlightToken += 1
        }

        return state
    }
}
