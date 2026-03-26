import Combine

final class GoogleLoginUseCase {

    private let authRepository: any AuthRepository

    init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    func execute(credential: GoogleLoginCredential) -> AnyPublisher<AuthSession, AuthError> {
        authRepository.loginWithGoogle(credential: credential)
    }
}
