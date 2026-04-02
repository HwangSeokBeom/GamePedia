import Foundation

final class FetchFriendProfileUseCase {
    private let repository: any FriendRepository

    init(repository: any FriendRepository) {
        self.repository = repository
    }

    func execute(userID: String) async throws -> FriendProfile {
        try await repository.fetchFriendProfile(userID: userID)
    }
}
