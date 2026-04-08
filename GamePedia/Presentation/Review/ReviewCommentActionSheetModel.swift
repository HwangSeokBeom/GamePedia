import Foundation

struct ReviewCommentActionSheetModel: Equatable {
    let commentId: String
    let reviewId: String
    let authorId: String
    let authorNickname: String
    let authorProfileImageUrl: String?
    let content: String
    let createdAt: Date
    let likeCount: Int
    let isReply: Bool
    let parentCommentId: String?
    let isOwnedByCurrentUser: Bool

    var avatarURL: URL? {
        authorProfileImageUrl.flatMap(URL.init(string:))
    }

    var avatarText: String {
        String(authorNickname.first ?? " ")
    }

    var title: String {
        isOwnedByCurrentUser
            ? L10n.tr("Localizable", "review.comment.sheet.mineTitle")
            : L10n.tr("Localizable", "review.comment.sheet.otherTitle", authorNickname)
    }

    var metadata: String {
        let relativeDate = RelativeDateTimeFormatter().localizedString(for: createdAt, relativeTo: Date())
        return L10n.tr("Localizable", "review.comment.sheet.meta", relativeDate, likeCount)
    }

    var actionKinds: [ReviewCommentActionSheetViewController.Context.Action.Kind] {
        if isOwnedByCurrentUser {
            return [.reply, .edit, .delete]
        }
        return [.reply, .report]
    }
}
