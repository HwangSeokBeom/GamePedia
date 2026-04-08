import Combine
import Foundation

struct ReviewCommentSyncEvent: Equatable {
    enum Action: Equatable {
        case created
        case updated
        case deleted
        case reacted
    }

    let action: Action
    let reviewId: String
    let gameId: Int
    let commentId: String
    let comment: ReviewComment?
}

enum ReviewCommentSyncCenter {
    static let events = PassthroughSubject<ReviewCommentSyncEvent, Never>()

    static func send(_ event: ReviewCommentSyncEvent) {
        events.send(event)
    }
}
