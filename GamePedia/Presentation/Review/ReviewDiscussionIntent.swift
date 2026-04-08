import Foundation

enum ReviewDiscussionIntent {
    case viewDidLoad
    case didTapRetry
    case didTapReviewLike(reviewId: String)
    case didTapDiscussionArea
    case didTapReply(commentId: String)
    case didTapEdit(commentId: String)
    case didTapDelete(commentId: String)
    case didTapReport(commentId: String)
    case didTapLike(commentId: String)
    case didTapDislike(commentId: String)
    case didTapToggleReplies(parentCommentId: String)
    case didChangeSort(ReviewCommentSortOption)
    case didChangeComposerText(String)
    case didTapCancelComposerMode
    case didTapSubmit
}
