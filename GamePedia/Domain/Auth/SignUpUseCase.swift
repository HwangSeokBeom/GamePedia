import Combine

final class SignUpUseCase {

    private let authRepository: any AuthRepository

    init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    func execute(
        email: String,
        password: String,
        nickname: String
    ) -> AnyPublisher<AuthSession, AuthError> {
        authRepository.signUp(email: email, password: password, nickname: nickname)
    }
}
