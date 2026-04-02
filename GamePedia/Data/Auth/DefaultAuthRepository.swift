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

    func forgotPassword(email: String) -> AnyPublisher<String, AuthError> {
        authRemoteDataSource.forgotPassword(
            requestDTO: ForgotPasswordRequestDTO(email: email)
        )
        .map(\.message)
        .eraseToAnyPublisher()
    }

    func resetPassword(token: String, newPassword: String) -> AnyPublisher<Void, AuthError> {
        authRemoteDataSource.resetPassword(
            requestDTO: ResetPasswordRequestDTO(
                token: token,
                newPassword: newPassword
            )
        )
        .tryMap { responseDTO in
            guard responseDTO.passwordReset else {
                throw AuthError.invalidResponse
            }
            return ()
        }
        .mapError { $0 as? AuthError ?? AuthError.unknown(message: $0.localizedDescription) }
        .eraseToAnyPublisher()
    }

    func loginWithApple(credential: AppleLoginCredential) -> AnyPublisher<AuthSession, AuthError> {
        let fullNameExists = [credential.givenName, credential.familyName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .contains { !$0.isEmpty }

        print(
            """
            [AppleLogin] credential prepared \
            userIdentifierExists=\(!credential.userIdentifier.isEmpty) \
            userIdentifierLength=\(credential.userIdentifier.count) \
            identityTokenExists=\(!credential.identityToken.isEmpty) \
            identityTokenLength=\(credential.identityToken.count) \
            authorizationCodeExists=\((credential.authorizationCode?.isEmpty == false)) \
            authorizationCodeLength=\(credential.authorizationCode?.count ?? 0) \
            emailExists=\((credential.email?.isEmpty == false)) \
            fullNameExists=\(fullNameExists)
            """
        )

        let requestDTO = AppleLoginRequestDTO(
            identityToken: credential.identityToken,
            deviceName: nil
        )

        print(
            """
            [AppleLogin] requestDTO prepared \
            payloadKeys=[identityToken,deviceName] \
            identityTokenExists=\(!requestDTO.identityToken.isEmpty) \
            identityTokenLength=\(requestDTO.identityToken.count) \
            deviceNameExists=\((requestDTO.deviceName?.isEmpty == false))
            """
        )

        return authRemoteDataSource.loginWithApple(
            requestDTO: requestDTO
        )
        .tryMap { [weak self] responseDTO in
            let session = try responseDTO.toDomainSession()
            self?.persist(session)
            return session
        }
        .mapError { $0 as? AuthError ?? AuthError.unknown(message: $0.localizedDescription) }
        .eraseToAnyPublisher()
    }

    func loginWithGoogle(credential: GoogleLoginCredential) -> AnyPublisher<AuthSession, AuthError> {
        let requestDTO = GoogleLoginRequestDTO(
            idToken: credential.idToken,
            deviceName: credential.deviceName
        )

        print(
            """
            [GoogleLogin] requestDTO prepared \
            payloadKeys=[idToken,deviceName] \
            idTokenExists=\(!requestDTO.idToken.isEmpty) \
            idTokenLength=\(requestDTO.idToken.count) \
            deviceNameExists=\((requestDTO.deviceName?.isEmpty == false))
            """
        )

        return authRemoteDataSource.loginWithGoogle(
            requestDTO: requestDTO
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
                self?.saveCurrentUser(user)
            })
            .eraseToAnyPublisher()
    }

    func updateCurrentUserProfile(
        nickname: String,
        selectedTitleKeys: [String]
    ) -> AnyPublisher<AuthUser, AuthError> {
        print(
            "[ProfileEdit] updateProfile " +
            "nicknameLength=\(nickname.count) " +
            "selectedTitleKeys=\(selectedTitleKeys)"
        )
        return authRemoteDataSource.updateCurrentUserProfile(
            requestDTO: UpdateCurrentUserProfileRequestDTO(
                nickname: nickname,
                selectedTitleKeys: selectedTitleKeys
            )
        )
        .handleEvents(receiveOutput: { [weak self] user in
            self?.saveCurrentUser(user)
        })
        .eraseToAnyPublisher()
    }

    func uploadCurrentUserProfileImage(
        data: Data,
        fileName: String,
        mimeType: String
    ) -> AnyPublisher<AuthUser, AuthError> {
        print("[ProfileEdit] uploadProfileImage bytes=\(data.count) mimeType=\(mimeType)")
        return authRemoteDataSource.uploadCurrentUserProfileImage(
            requestDTO: ProfileImageUploadRequestDTO(
                imageData: data,
                fileName: fileName,
                mimeType: mimeType
            )
        )
        .handleEvents(receiveOutput: { [weak self] user in
            self?.saveCurrentUser(user)
        })
        .eraseToAnyPublisher()
    }

    func removeCurrentUserProfileImage() -> AnyPublisher<AuthUser, AuthError> {
        print("[ProfileEdit] removeProfileImage")
        return authRemoteDataSource.removeCurrentUserProfileImage()
            .handleEvents(receiveOutput: { [weak self] user in
                self?.saveCurrentUser(user)
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
        saveCurrentUser(session.user)
        apiClient.userAuthToken = session.accessToken
    }

    private func saveCurrentUser(_ user: AuthUser) {
        userSessionStore.saveUser(user)
    }

    private func clearStoredSession() {
        tokenStore.clear()
        userSessionStore.clear()
        apiClient.userAuthToken = nil
    }
}
