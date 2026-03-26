import Combine

final class RemoveCurrentUserProfileImageUseCase {

    private let authRepository: any AuthRepository

    init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    func execute() -> AnyPublisher<AuthUser, AuthError> {
        authRepository.removeCurrentUserProfileImage()
    }
}
