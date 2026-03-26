import Combine

final class ForgotPasswordUseCase {

    private let authRepository: any AuthRepository

    init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    func execute(email: String) -> AnyPublisher<String, AuthError> {
        authRepository.forgotPassword(email: email)
    }
}
