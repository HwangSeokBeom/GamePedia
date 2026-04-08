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
        case .replaceReview(let review):
            state.review = review
        case .setComments(let comments):
            state.allComments = comments
            state.comments = sortComments(comments, by: state.sortOption)
        case .setSortOption(let sortOption):
            state.sortOption = sortOption
            state.comments = sortComments(state.allComments, by: sortOption)
        case .setExpandedParentCommentIds(let ids):
            state.expandedParentCommentIds = ids
        case .setComposerText(let text):
            state.composerText = text
        case .setComposerMode(let mode):
            state.composerMode = mode
            if case .comment = mode {
                state.composerText = ""
            }
        case .setComposerModePreservingText(let mode):
            state.composerMode = mode
        case .setSubmitting(let isSubmitting):
            state.isSubmitting = isSubmitting
        case .setReviewReactionLoading(let reviewId, let isLoading):
            if isLoading {
                state.reactingReviewIds.insert(reviewId)
            } else {
                state.reactingReviewIds.remove(reviewId)
            }
        case .setReactionLoading(let commentId, let isLoading):
            if isLoading {
                state.reactingCommentIds.insert(commentId)
            } else {
                state.reactingCommentIds.remove(commentId)
            }
        case .replaceComment(let updatedComment):
            if let index = state.allComments.firstIndex(where: { $0.id == updatedComment.id }) {
                state.allComments[index] = updatedComment
            }
            state.comments = sortComments(state.allComments, by: state.sortOption)
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

    private static func sortComments(_ comments: [ReviewComment], by option: ReviewCommentSortOption) -> [ReviewComment] {
        let rootComments = comments.filter { $0.parentCommentId == nil }
        let repliesByParentId = Dictionary(grouping: comments.filter { $0.parentCommentId != nil }, by: { $0.parentCommentId ?? "" })

        let sortedRoots = rootComments.sorted { lhs, rhs in
            switch option {
            case .latest:
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            case .oldest:
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            case .likeDescending:
                if lhs.likeCount != rhs.likeCount { return lhs.likeCount > rhs.likeCount }
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            case .likeAscending:
                if lhs.likeCount != rhs.likeCount { return lhs.likeCount < rhs.likeCount }
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            }
            return lhs.id < rhs.id
        }

        return sortedRoots.flatMap { comment in
            let replies = (repliesByParentId[comment.id] ?? []).sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                return lhs.id < rhs.id
            }
            return [comment] + replies
        }
    }
}
