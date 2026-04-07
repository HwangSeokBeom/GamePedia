import Foundation

struct ProfileReviewsState: Equatable {
    var isLoading: Bool = false
    var sortOption: ReviewSortOption = .latest
    var items: [ReviewedGame] = []
    var deletingReviewId: String? = nil
    var errorMessage: String? = nil

    var isEmpty: Bool {
        !isLoading && items.isEmpty && errorMessage == nil
    }

    var reviewCountText: String {
        L10n.tr("Localizable", "profile.reviews.count", items.count)
    }
}
