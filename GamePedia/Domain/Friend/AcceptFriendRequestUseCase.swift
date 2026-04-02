import Foundation

final class AcceptFriendRequestUseCase {
    private let repository: any FriendRepository

    init(repository: any FriendRepository) {
        self.repository = repository
    }

    func execute(requestID: String) async throws {
        try await repository.acceptFriendRequest(requestID: requestID)
    }
}
