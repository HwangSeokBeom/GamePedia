import Foundation

enum ReviewSortOption: String, CaseIterable {
    case latest
    case oldest
    case ratingDescending = "rating_desc"
    case ratingAscending = "rating_asc"
}
