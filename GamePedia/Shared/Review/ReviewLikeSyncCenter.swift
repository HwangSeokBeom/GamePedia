import Combine
import Foundation

struct ReviewLikeSyncEvent: Equatable {
    let reviewId: String
    let gameId: String
    let likeCount: Int
    let isLikedByCurrentUser: Bool
}

enum ReviewLikeSyncCenter {
    static let events = PassthroughSubject<ReviewLikeSyncEvent, Never>()

    static func send(_ event: ReviewLikeSyncEvent) {
        events.send(event)
    }
}
