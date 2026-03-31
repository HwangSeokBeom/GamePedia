import Foundation

final class ImportSteamFriendsUseCase {
    private let repository: any FriendRepository

    init(repository: any FriendRepository) {
        self.repository = repository
    }

    func execute() async throws {
        try await repository.importSteamFriends()
    }
}
