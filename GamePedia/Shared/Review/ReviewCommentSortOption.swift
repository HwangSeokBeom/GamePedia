import Foundation

enum ReviewCommentSortOption: String, CaseIterable, Equatable {
    case latest
    case oldest
    case likeDescending = "like_desc"
    case likeAscending = "like_asc"

    var displayTitle: String {
        switch self {
        case .latest:
            return L10n.tr("Localizable", "review.comment.sort.latest")
        case .oldest:
            return L10n.tr("Localizable", "review.comment.sort.oldest")
        case .likeDescending:
            return L10n.tr("Localizable", "review.comment.sort.likeDescending")
        case .likeAscending:
            return L10n.tr("Localizable", "review.comment.sort.likeAscending")
        }
    }
}
