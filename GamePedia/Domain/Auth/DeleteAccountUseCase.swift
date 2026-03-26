import Combine

final class DeleteAccountUseCase {

    private let authRepository: any AuthRepository

    init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    func execute() -> AnyPublisher<Void, AuthError> {
        authRepository.deleteAccount()
    }
}
