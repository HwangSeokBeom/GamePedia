import Combine

final class FetchCurrentUserUseCase {

    private let authRepository: any AuthRepository

    init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    func execute() -> AnyPublisher<AuthUser, AuthError> {
        authRepository.fetchCurrentUser()
    }
}
