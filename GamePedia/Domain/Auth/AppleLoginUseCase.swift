import Combine

final class AppleLoginUseCase {

    private let authRepository: any AuthRepository

    init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    func execute(credential: AppleLoginCredential) -> AnyPublisher<AuthSession, AuthError> {
        authRepository.loginWithApple(credential: credential)
    }
}
