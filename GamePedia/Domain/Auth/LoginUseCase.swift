import Combine

final class LoginUseCase {

    private let authRepository: any AuthRepository

    init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    func execute(email: String, password: String) -> AnyPublisher<AuthSession, AuthError> {
        authRepository.login(email: email, password: password)
    }
}
