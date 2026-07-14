import Combine
import Foundation

final class DefaultAuthRepository: AuthRepository {

    // The shared result publisher is a Future, so a downstream cancellation
    // never propagates to the privately retained upstream sink on its own.
    // The flight therefore counts active waiters itself: when the last one
    // cancels before a terminal result, it atomically invalidates the flight,
    // detaches it from the repository, and cancels the upstream request so a
    // late response can neither persist nor clear credentials. It shares the
    // repository's recursive lock so that this invalidation is atomic with
    // commitRefresh/failRefresh and free of lock-order inversions.
    private final class RefreshFlight {
        let generation: UInt64
        private(set) var publisher: AnyPublisher<AuthSession, AuthError>
        private let lock: NSRecursiveLock
        private let resolve: (Result<AuthSession, AuthError>) -> Void
        private var onAbandoned: ((RefreshFlight) -> Void)?
        private var upstream: AnyCancellable?
        private var activeWaiters = 0
        private var isCompleted = false

        init(
            result: AnyPublisher<AuthSession, AuthError>,
            generation: UInt64,
            lock: NSRecursiveLock,
            resolve: @escaping (Result<AuthSession, AuthError>) -> Void,
            onAbandoned: @escaping (RefreshFlight) -> Void
        ) {
            self.generation = generation
            self.lock = lock
            self.resolve = resolve
            self.onAbandoned = onAbandoned
            self.publisher = result
            self.publisher = result
                .handleEvents(
                    receiveSubscription: { [weak self] _ in self?.waiterDidSubscribe() },
                    receiveCancel: { [weak self] in self?.waiterDidCancel() }
                )
                .eraseToAnyPublisher()
        }

        func install(_ cancellable: AnyCancellable) {
            lock.lock()
            if isCompleted {
                lock.unlock()
                cancellable.cancel()
                return
            }
            upstream = cancellable
            lock.unlock()
        }

        func complete(_ result: Result<AuthSession, AuthError>) {
            lock.lock()
            guard isCompleted == false else {
                lock.unlock()
                return
            }
            isCompleted = true
            onAbandoned = nil
            lock.unlock()

            resolve(result)
        }

        private func waiterDidSubscribe() {
            lock.lock()
            if isCompleted == false {
                activeWaiters += 1
            }
            lock.unlock()
        }

        private func waiterDidCancel() {
            lock.lock()
            guard isCompleted == false else {
                lock.unlock()
                return
            }
            activeWaiters -= 1
            guard activeWaiters <= 0 else {
                lock.unlock()
                return
            }
            isCompleted = true
            let upstream = self.upstream
            self.upstream = nil
            let onAbandoned = self.onAbandoned
            self.onAbandoned = nil
            // Detach from the repository while still holding the shared lock
            // so a concurrent commit/fail cannot pass its identity check.
            onAbandoned?(self)
            lock.unlock()

            upstream?.cancel()
            // Resolve so a subscriber that grabbed the shared publisher
            // before abandonment terminates instead of hanging forever.
            resolve(.failure(.unauthorized))
        }
    }

    private let authRemoteDataSource: AuthRemoteDataSource
    private let tokenStore: any TokenStore
    private let userSessionStore: any UserSessionStore
    private let apiClient: APIClient
    private let refreshWillResolve: (() -> Void)?
    private let refreshDidResolve: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()
    private let refreshLock = NSRecursiveLock()
    private var refreshGeneration: UInt64 = 0
    private var inFlightRefresh: RefreshFlight?

    init(
        authRemoteDataSource: AuthRemoteDataSource,
        tokenStore: any TokenStore,
        userSessionStore: any UserSessionStore,
        apiClient: APIClient = .shared,
        refreshWillResolve: (() -> Void)? = nil,
        refreshDidResolve: (() -> Void)? = nil
    ) {
        self.authRemoteDataSource = authRemoteDataSource
        self.tokenStore = tokenStore
        self.userSessionStore = userSessionStore
        self.apiClient = apiClient
        self.refreshWillResolve = refreshWillResolve
        self.refreshDidResolve = refreshDidResolve
    }

    func login(email: String, password: String) -> AnyPublisher<AuthSession, AuthError> {
        authRemoteDataSource.login(
            requestDTO: LoginRequestDTO(email: email, password: password)
        )
        .tryMap { [weak self] responseDTO in
            let session = try responseDTO.toDomainSession()
            self?.adoptAuthenticatedSession(session)
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
            identityTokenExists=\(!credential.identityToken.isEmpty) \
            authorizationCodeExists=\((credential.authorizationCode?.isEmpty == false)) \
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
            credentialPresent=\(!requestDTO.identityToken.isEmpty) \
            deviceNameExists=\((requestDTO.deviceName?.isEmpty == false))
            """
        )

        return authRemoteDataSource.loginWithApple(
            requestDTO: requestDTO
        )
        .tryMap { [weak self] responseDTO in
            let session = try responseDTO.toDomainSession()
            self?.adoptAuthenticatedSession(session)
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
            credentialPresent=\(!requestDTO.idToken.isEmpty) \
            deviceNameExists=\((requestDTO.deviceName?.isEmpty == false))
            """
        )

        return authRemoteDataSource.loginWithGoogle(
            requestDTO: requestDTO
        )
        .tryMap { [weak self] responseDTO in
            let session = try responseDTO.toDomainSession()
            self?.adoptAuthenticatedSession(session)
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
            self?.adoptAuthenticatedSession(session)
            return session
        }
        .mapError { $0 as? AuthError ?? AuthError.unknown(message: $0.localizedDescription) }
        .eraseToAnyPublisher()
    }

    func refreshSession() -> AnyPublisher<AuthSession, AuthError> {
        refreshLock.lock()
        if let inFlightRefresh {
            refreshLock.unlock()
            return inFlightRefresh.publisher
        }

        guard let refreshToken = tokenStore.fetchRefreshToken() else {
            refreshLock.unlock()
            return Fail(error: AuthError.missingRefreshToken).eraseToAnyPublisher()
        }

        var resolve: ((Result<AuthSession, AuthError>) -> Void)?
        let publisher = Future<AuthSession, AuthError> { promise in
            resolve = promise
        }
        .eraseToAnyPublisher()
        guard let resolve else {
            refreshLock.unlock()
            return Fail(error: AuthError.invalidResponse).eraseToAnyPublisher()
        }
        let flight = RefreshFlight(
            result: publisher,
            generation: refreshGeneration,
            lock: refreshLock,
            resolve: resolve,
            onAbandoned: { [weak self] abandoned in
                guard let self else { return }
                if self.inFlightRefresh === abandoned {
                    self.inFlightRefresh = nil
                }
            }
        )
        inFlightRefresh = flight
        refreshLock.unlock()

        let cancellable = authRemoteDataSource.refreshSession(refreshToken: refreshToken)
            .tryMap { try $0.toDomainSession() }
            .mapError { $0 as? AuthError ?? AuthError.unknown(message: $0.localizedDescription) }
            .sink(
                receiveCompletion: { [weak self, weak flight] completion in
                    guard let self, let flight else { return }
                    if case .failure(let error) = completion {
                        self.refreshWillResolve?()
                        self.failRefresh(error, flight: flight)
                        self.refreshDidResolve?()
                    }
                },
                receiveValue: { [weak self, weak flight] session in
                    guard let self, let flight else { return }
                    self.refreshWillResolve?()
                    self.commitRefresh(session, flight: flight)
                    self.refreshDidResolve?()
                }
            )
        flight.install(cancellable)

        return flight.publisher
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
            "selectedTitleCount=\(selectedTitleKeys.count)"
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
        let accessToken = tokenStore.fetchAccessToken()
        let logoutPublisher = authRemoteDataSource.logout(refreshToken: refreshToken)

        invalidateStoredSession()
        PushNotificationService.shared.deleteRegisteredTokenOnLogout(accessToken: accessToken)

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
                let accessToken = self?.tokenStore.fetchAccessToken()
                self?.invalidateStoredSession()
                PushNotificationService.shared.deleteRegisteredTokenOnLogout(accessToken: accessToken)
            })
            .eraseToAnyPublisher()
    }

    private func persist(_ session: AuthSession) {
        tokenStore.saveAccessToken(session.accessToken)
        tokenStore.saveRefreshToken(session.refreshToken)
        saveCurrentUser(session.user)
        apiClient.userAuthToken = session.accessToken
        NotificationCenter.default.post(
            name: .authSessionDidChange,
            object: nil,
            userInfo: [
                AuthSessionChangeUserInfoKey.isAuthenticated: true,
                AuthSessionChangeUserInfoKey.userId: session.user.id
            ]
        )
    }

    private func saveCurrentUser(_ user: AuthUser) {
        userSessionStore.saveUser(user)
    }

    private func clearStoredSession() {
        tokenStore.clear()
        userSessionStore.clear()
        apiClient.userAuthToken = nil
        NotificationCenter.default.post(
            name: .authSessionDidChange,
            object: nil,
            userInfo: [AuthSessionChangeUserInfoKey.isAuthenticated: false]
        )
    }

    // A fresh login/signup/social-login session owns the credential store from
    // this point on: any refresh still in flight was issued for the previous
    // session and must not be allowed to commit or clear on top of it.
    private func adoptAuthenticatedSession(_ session: AuthSession) {
        refreshLock.lock()
        refreshGeneration &+= 1
        let supersededFlight = inFlightRefresh
        inFlightRefresh = nil
        persist(session)
        supersededFlight?.complete(.failure(.unauthorized))
        refreshLock.unlock()
    }

    private func commitRefresh(_ session: AuthSession, flight: RefreshFlight) {
        refreshLock.lock()
        guard inFlightRefresh === flight, flight.generation == refreshGeneration else {
            refreshLock.unlock()
            return
        }
        persist(session)
        inFlightRefresh = nil
        flight.complete(.success(session))
        refreshLock.unlock()
    }

    private func failRefresh(_ error: AuthError, flight: RefreshFlight) {
        refreshLock.lock()
        guard inFlightRefresh === flight else {
            refreshLock.unlock()
            return
        }
        refreshGeneration &+= 1
        inFlightRefresh = nil
        clearStoredSession()
        flight.complete(.failure(error))
        refreshLock.unlock()
    }

    private func invalidateStoredSession() {
        refreshLock.lock()
        refreshGeneration &+= 1
        let flight = inFlightRefresh
        inFlightRefresh = nil
        clearStoredSession()
        flight?.complete(.failure(.unauthorized))
        refreshLock.unlock()
    }
}
