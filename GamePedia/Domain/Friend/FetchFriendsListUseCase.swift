import Foundation

final class FetchFriendsListUseCase {
    private let repository: any FriendRepository

    init(repository: any FriendRepository) {
        self.repository = repository
    }

    func execute() async throws -> [FriendUserSummary] {
        try await repository.fetchFriends()
    }
}
