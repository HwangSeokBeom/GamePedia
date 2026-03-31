import Foundation

final class FetchFriendActivityFeedUseCase {
    private let repository: any FriendRepository

    init(repository: any FriendRepository) {
        self.repository = repository
    }

    func execute() async throws -> [FriendActivityItem] {
        try await repository.fetchFriendActivityFeed()
    }
}
