import Combine

protocol AuthRepository {
    func login(email: String, password: String) -> AnyPublisher<AuthSession, AuthError>

    func signUp(
        email: String,
        password: String,
        nickname: String
    ) -> AnyPublisher<AuthSession, AuthError>

    func refreshSession() -> AnyPublisher<AuthSession, AuthError>
    func fetchCurrentUser() -> AnyPublisher<AuthUser, AuthError>
    func logout()
    func deleteAccount() -> AnyPublisher<Void, AuthError>
}
