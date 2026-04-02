import Combine

final class UpdateCurrentUserProfileUseCase {

    private let authRepository: any AuthRepository

    init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    func execute(
        nickname: String,
        selectedTitleKeys: [String] = []
    ) -> AnyPublisher<AuthUser, AuthError> {
        authRepository.updateCurrentUserProfile(
            nickname: nickname,
            selectedTitleKeys: selectedTitleKeys
        )
    }
}
