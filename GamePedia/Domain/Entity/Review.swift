import Foundation

struct ReviewAuthor: Equatable {
    let id: String
    let nickname: String
    let profileImageUrl: String?
}

struct ReviewSummary: Equatable {
    let reviewCount: Int
    let averageRating: Double?

    var formattedAverageRating: String {
        guard let averageRating else { return "—" }
        return LocalizedNumberFormatter.oneFraction(averageRating)
    }

    var summaryText: String {
        if reviewCount == 0 {
            return L10n.tr("Localizable", "review.summary.empty")
        }
        return L10n.tr(
            "Localizable",
            "review.summary.averageAndCount",
            formattedAverageRating,
            L10n.Common.Count.reviews(reviewCount)
        )
    }
}

struct GameReviewFeed: Equatable {
    let reviews: [Review]
    let summary: ReviewSummary

    var myReviews: [Review] {
        reviews.filter(\.isMine)
    }
}

struct ReviewDeletionResult: Equatable {
    let deleted: Bool
    let reviewId: String
}

struct ReviewLikeMutationResult: Equatable {
    let reviewId: String
    let likeCount: Int
    let isLikedByCurrentUser: Bool
}

// MARK: - Review

struct Review: Equatable {
    let id: String
    let gameId: String
    let rating: Double
    let content: String
    let createdAt: String
    let updatedAt: String
    let author: ReviewAuthor
    let isMine: Bool
    let likeCount: Int
    let commentCount: Int
    let isLikedByCurrentUser: Bool

    var authorName: String {
        author.nickname
    }

    var authorAvatarURL: URL? {
        author.profileImageUrl.flatMap(URL.init(string:))
    }

    var body: String {
        content
    }

    var formattedDate: String {
        updatedAt.toRelativeDateString()
    }

    func updatingCommentCount(_ commentCount: Int) -> Review {
        Review(
            id: id,
            gameId: gameId,
            rating: rating,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            author: author,
            isMine: isMine,
            likeCount: likeCount,
            commentCount: max(0, commentCount),
            isLikedByCurrentUser: isLikedByCurrentUser
        )
    }

    func updatingLikeState(likeCount: Int, isLikedByCurrentUser: Bool) -> Review {
        Review(
            id: id,
            gameId: gameId,
            rating: rating,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            author: author,
            isMine: isMine,
            likeCount: max(0, likeCount),
            commentCount: commentCount,
            isLikedByCurrentUser: isLikedByCurrentUser
        )
    }

    func togglingLikeOptimistically() -> Review {
        let nextLikedState = !isLikedByCurrentUser
        let nextLikeCount = max(0, likeCount + (nextLikedState ? 1 : -1))
        return updatingLikeState(
            likeCount: nextLikeCount,
            isLikedByCurrentUser: nextLikedState
        )
    }

    func mergingDiscussionCount(localCount: Int) -> Review {
        updatingCommentCount(max(commentCount, localCount))
    }

    func resolvingDiscussionCount(localCount: Int?) -> Review {
        guard let localCount else { return self }
        return updatingCommentCount(localCount)
    }
}
