import Foundation

enum SocialActivityRoute: Hashable {
    case friendActivityFeed
    case friendRequests
    case friendProfile(String)
    case gameDetail(Int)
    case review(gameID: Int, reviewID: String?, commentID: String?)
}
