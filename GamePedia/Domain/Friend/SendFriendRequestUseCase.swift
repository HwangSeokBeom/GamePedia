import Foundation

final class SendFriendRequestUseCase {
    private let repository: any FriendRepository

    init(repository: any FriendRepository) {
        self.repository = repository
    }

    func execute(userID: String) async throws {
        try await repository.sendFriendRequest(userID: userID)
    }
}
