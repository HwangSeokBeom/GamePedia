import Foundation

enum ReviewCommentReaction: String, Codable, CaseIterable, Hashable {
    case like
    case dislike
}

struct ReviewCommentAuthor: Codable, Equatable, Hashable {
    let id: String
    let nickname: String
    let profileImageUrl: String?

    var avatarURL: URL? {
        profileImageUrl.flatMap(URL.init(string:))
    }
}

struct ReviewDiscussionContext: Equatable {
    let gameId: Int
    let gameTitle: String
    let reviewId: String
    let reviewSnippet: String
    let reviewAuthor: ReviewAuthor

    init(
        gameId: Int,
        gameTitle: String,
        reviewId: String,
        reviewSnippet: String,
        reviewAuthor: ReviewAuthor
    ) {
        self.gameId = gameId
        self.gameTitle = gameTitle
        self.reviewId = reviewId
        self.reviewSnippet = reviewSnippet
        self.reviewAuthor = reviewAuthor
    }

    init(gameId: Int, gameTitle: String, review: Review) {
        self.gameId = gameId
        self.gameTitle = gameTitle
        self.reviewId = review.id
        self.reviewSnippet = review.content
        self.reviewAuthor = review.author
    }
}

struct ReviewCommentDraft: Equatable {
    let parentCommentId: String?
    let content: String
}

struct ReviewComment: Equatable, Hashable, Identifiable {
    let id: String
    let reviewId: String
    let gameId: Int
    let gameTitle: String
    let reviewSnippet: String
    let parentCommentId: String?
    let depth: Int
    let author: ReviewCommentAuthor
    let content: String
    let createdAt: Date
    let updatedAt: Date?
    let isMine: Bool
    let isReviewAuthor: Bool
    let isDeleted: Bool
    let isEdited: Bool
    let replyCount: Int
    let likeCount: Int
    let dislikeCount: Int
    let myReaction: ReviewCommentReaction?

    var canEdit: Bool {
        isMine && !isDeleted
    }

    var canDelete: Bool {
        isMine && !isDeleted
    }

    var canReport: Bool {
        !isMine && !isDeleted
    }

    var canReply: Bool {
        !isDeleted
    }

    var formattedDate: String {
        let relativeText = RelativeDateTimeFormatter().localizedString(for: createdAt, relativeTo: Date())
        if isEdited, let updatedAt {
            let editedText = RelativeDateTimeFormatter().localizedString(for: updatedAt, relativeTo: Date())
            return L10n.tr("Localizable", "review.comment.editedDate", relativeText, editedText)
        }
        return relativeText
    }
}

struct MyReviewCommentEntry: Equatable, Hashable, Identifiable {
    let id: String
    let reviewId: String
    let gameId: Int
    let gameTitle: String
    let reviewSnippet: String
    let commentContent: String
    let createdAt: Date
    let updatedAt: Date?
    let depth: Int
    let isDeleted: Bool
    let likeCount: Int
    let dislikeCount: Int
    let myReaction: ReviewCommentReaction?
    let comment: ReviewComment

    var formattedDate: String {
        comment.formattedDate
    }

    var isMine: Bool {
        comment.isMine
    }

    var isReviewAuthor: Bool {
        comment.isReviewAuthor
    }
}
