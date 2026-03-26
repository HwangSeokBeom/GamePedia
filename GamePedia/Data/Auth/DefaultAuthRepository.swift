import Combine
import Foundation

final class DefaultAuthRepository: AuthRepository {

    private let authRemoteDataSource: AuthRemoteDataSource
    private let tokenStore: any TokenStore
    private let userSessionStore: any UserSessionStore
    private let apiClient: APIClient
    private var cancellables = Set<AnyCancellable>()

    init(
        authRemoteDataSource: AuthRemoteDataSource,
        tokenStore: any TokenStore,
        userSessionStore: any UserSessionStore,
        apiClient: APIClient = .shared
    ) {
        self.authRemoteDataSource = authRemoteDataSource
        self.tokenStore = tokenStore
        self.userSessionStore = userSessionStore
        self.apiClient = apiClient
    }

    func login(email: String, password: String) -> AnyPublisher<AuthSession, AuthError> {
        authRemoteDataSource.login(
            requestDTO: LoginRequestDTO(email: email, password: password)
        )
        .tryMap { [weak self] responseDTO in
            let session = try responseDTO.toDomainSession()
            self?.persist(session)
            return session
        }
        .mapError { $0 as? AuthError ?? AuthError.unknown(message: $0.localizedDescription) }
        .eraseToAnyPublisher()
    }

    func signUp(
        email: String,
        password: String,
        nickname: String
    ) -> AnyPublisher<AuthSession, AuthError> {
        authRemoteDataSource.signUp(
            requestDTO: SignUpRequestDTO(email: email, password: password, nickname: nickname)
        )
        .tryMap { [weak self] responseDTO in
            let session = try responseDTO.toDomainSession()
            self?.persist(session)
            return session
        }
        .mapError { $0 as? AuthError ?? AuthError.unknown(message: $0.localizedDescription) }
        .eraseToAnyPublisher()
    }

    func refreshSession() -> AnyPublisher<AuthSession, AuthError> {
        guard let refreshToken = tokenStore.fetchRefreshToken() else {
            return Fail(error: AuthError.missingRefreshToken).eraseToAnyPublisher()
        }

        return authRemoteDataSource.refreshSession(refreshToken: refreshToken)
            .tryMap { [weak self] responseDTO in
                let session = try responseDTO.toDomainSession()
                self?.persist(session)
                return session
            }
            .handleEvents(receiveCompletion: { [weak self] completion in
                if case .failure = completion {
                    self?.clearStoredSession()
                }
            })
            .mapError { $0 as? AuthError ?? AuthError.unknown(message: $0.localizedDescription) }
            .eraseToAnyPublisher()
    }

    func fetchCurrentUser() -> AnyPublisher<AuthUser, AuthError> {
        authRemoteDataSource.fetchCurrentUser()
            .handleEvents(receiveOutput: { [weak self] user in
                self?.userSessionStore.saveUser(user)
            })
            .eraseToAnyPublisher()
    }

    func logout() {
        let refreshToken = tokenStore.fetchRefreshToken()
        let logoutPublisher = authRemoteDataSource.logout(refreshToken: refreshToken)

        clearStoredSession()

        logoutPublisher
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }

    func deleteAccount() -> AnyPublisher<Void, AuthError> {
        authRemoteDataSource.deleteAccount()
            .mapError { error in
                if case .server(let code, _) = error, code.uppercased() == "NOT_FOUND" {
                    return .accountDeletionUnavailable
                }
                return error
            }
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.clearStoredSession()
            })
            .eraseToAnyPublisher()
    }

    private func persist(_ session: AuthSession) {
        tokenStore.saveAccessToken(session.accessToken)
        tokenStore.saveRefreshToken(session.refreshToken)
        userSessionStore.saveUser(session.user)
        apiClient.userAuthToken = session.accessToken
    }

    private func clearStoredSession() {
        tokenStore.clear()
        userSessionStore.clear()
        apiClient.userAuthToken = nil
    }
}
