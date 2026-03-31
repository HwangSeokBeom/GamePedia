import Foundation

final class CancelFriendRequestUseCase {
    private let repository: any FriendRepository

    init(repository: any FriendRepository) {
        self.repository = repository
    }

    func execute(requestID: String) async throws {
        try await repository.cancelFriendRequest(requestID: requestID)
    }
}
