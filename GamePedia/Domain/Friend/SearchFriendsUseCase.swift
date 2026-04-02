import Foundation

final class SearchFriendsUseCase {
    private let repository: any FriendRepository

    init(repository: any FriendRepository) {
        self.repository = repository
    }

    func execute(keyword: String) async throws -> [FriendUserSummary] {
        try await repository.searchFriends(keyword: keyword)
    }
}
