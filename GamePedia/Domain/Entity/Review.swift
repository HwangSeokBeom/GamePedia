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

    var myReview: Review? {
        reviews.first(where: { $0.isMine })
    }
}

struct ReviewDeletionResult: Equatable {
    let deleted: Bool
    let reviewId: String
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
}
