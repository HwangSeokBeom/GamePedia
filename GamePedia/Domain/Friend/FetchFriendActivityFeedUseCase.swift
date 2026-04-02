import Foundation

final class FetchFriendActivityFeedUseCase {
    private let repository: any FriendRepository

    init(repository: any FriendRepository) {
        self.repository = repository
    }

    func execute(cursor: String? = nil) async throws -> FriendActivityFeedPage {
        try await repository.fetchFriendActivityFeed(cursor: cursor)
    }
}
