import Combine

final class RefreshSessionUseCase {

    private let authRepository: any AuthRepository

    init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    func execute() -> AnyPublisher<AuthSession, AuthError> {
        authRepository.refreshSession()
    }
}
