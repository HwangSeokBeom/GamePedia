import Foundation

final class RejectFriendRequestUseCase {
    private let repository: any FriendRepository

    init(repository: any FriendRepository) {
        self.repository = repository
    }

    func execute(requestID: String) async throws {
        try await repository.rejectFriendRequest(requestID: requestID)
    }
}
