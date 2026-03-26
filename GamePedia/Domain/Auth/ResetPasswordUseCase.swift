import Combine

final class ResetPasswordUseCase {

    private let authRepository: any AuthRepository

    init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    func execute(token: String, newPassword: String) -> AnyPublisher<Void, AuthError> {
        authRepository.resetPassword(token: token, newPassword: newPassword)
    }
}
