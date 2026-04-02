import Foundation

enum FriendRequestListKind {
    case received
    case sent
}

final class FetchFriendRequestsUseCase {
    private let repository: any FriendRepository

    init(repository: any FriendRepository) {
        self.repository = repository
    }

    func execute(kind: FriendRequestListKind) async throws -> [FriendRequest] {
        switch kind {
        case .received:
            return try await repository.fetchReceivedFriendRequests()
        case .sent:
            return try await repository.fetchSentFriendRequests()
        }
    }
}
