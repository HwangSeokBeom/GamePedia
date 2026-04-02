import Foundation

final class FetchSocialPrivacySettingsUseCase {
    private let repository: any FriendRepository

    init(repository: any FriendRepository) {
        self.repository = repository
    }

    func execute() async throws -> SocialPrivacySettings {
        try await repository.fetchSocialPrivacySettings()
    }
}
