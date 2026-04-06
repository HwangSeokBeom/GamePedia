import Foundation

struct ProfileCommentsState: Equatable {
    var isLoading: Bool = false
    var items: [MyReviewCommentEntry] = []
    var errorMessage: String? = nil

    var isEmpty: Bool {
        !isLoading && items.isEmpty && errorMessage == nil
    }
}
