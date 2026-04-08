import Foundation

struct ProfileCommentsState: Equatable {
    var isLoading: Bool = false
    var allItems: [MyReviewCommentEntry] = []
    var items: [MyReviewCommentEntry] = []
    var sortOption: ReviewCommentSortOption = .latest
    var reactingCommentIds: Set<String> = []
    var errorMessage: String? = nil

    var isEmpty: Bool {
        !isLoading && items.isEmpty && errorMessage == nil
    }

    var countText: String {
        L10n.tr("Localizable", "profile.comments.count", items.count)
    }
}
