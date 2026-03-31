import Foundation

final class RemoveFriendUseCase {
    private let repository: any FriendRepository

    init(repository: any FriendRepository) {
        self.repository = repository
    }

    func execute(userID: String) async throws {
        try await repository.removeFriend(userID: userID)
    }
}
