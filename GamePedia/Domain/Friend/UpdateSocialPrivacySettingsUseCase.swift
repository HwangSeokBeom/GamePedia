import Foundation

final class UpdateSocialPrivacySettingsUseCase {
    private let repository: any FriendRepository

    init(repository: any FriendRepository) {
        self.repository = repository
    }

    func execute(settings: SocialPrivacySettings) async throws -> SocialPrivacySettings {
        try await repository.updateSocialPrivacySettings(settings)
    }
}
