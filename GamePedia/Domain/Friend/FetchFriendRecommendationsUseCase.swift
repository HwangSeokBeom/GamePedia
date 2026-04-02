import Foundation

final class FetchFriendRecommendationsUseCase {
    private let repository: any FriendRepository

    init(repository: any FriendRepository) {
        self.repository = repository
    }

    func execute(userID: String) async throws -> [FriendRecommendation] {
        try await repository.fetchFriendRecommendations(userID: userID)
    }
}
