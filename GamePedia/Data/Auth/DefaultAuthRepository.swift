import Combine
import Foundation

final class DefaultAuthRepository: AuthRepository {

    // The shared result publisher is a Future, so a downstream cancellation
    // never propagates to the privately retained upstream sink on its own.
    // The flight therefore tracks its waiters and models an explicit
    // lifecycle so that publication, upstream installation, cancellation,
    // supersession, and replacement form one coherent state transition:
    //
    //   starting              published in the repository slot; the creating
    //                         subscription has not been authorized to
    //                         install the upstream yet
    //   installing            the creator atomically claimed installation
    //                         ownership and is constructing/subscribing the
    //                         provider publisher outside the lock; the
    //                         flight keeps occupying the slot the whole time
    //   installingSuperseded  a fresh session or an invalidation superseded
    //                         the flight while it was installing; the slot
    //                         stays occupied until the creator suppresses
    //                         the subscription entirely or cancels the
    //                         just-created request
    //   active                upstream installed; waiters share one request
    //   abandonRequested      every waiter cancelled during startup; the
    //                         flight keeps occupying the slot until the
    //                         creator suppresses or cancels the upstream,
    //                         so no replacement can overlap it
    //   abandoning            the final waiter cancelled an active flight,
    //                         or a fresh session superseded it; the slot
    //                         stays occupied until the upstream cancellation
    //                         has actually been issued
    //   finished              terminal; the slot is released and a late
    //                         result can neither persist nor clear
    //                         credentials
    //
    // Slot ownership rule: the repository slot is only ever released by the
    // flight itself, through supersession of a not-yet-installing flight,
    // through a claimed completion, or through finishAbandonment() once any
    // old upstream activity has been definitively suppressed or its
    // cancellation has been issued. Login/signup/social-login adoption and
    // logout/account-deletion invalidation supersede the flight and advance
    // the session generation, but they never clear an installing or
    // abandoning flight out of the slot directly, so a replacement refresh
    // can never overlap a still-live superseded request.
    //
    // Ownership is subscription-driven: a flight is only ever created by an
    // actual downstream subscription, and that creating subscription is
    // registered as the first waiter atomically at init, before the flight
    // becomes visible in the repository slot. A joiner that subscribes and
    // cancels while the creator is still installing the upstream therefore
    // never counts as "the final waiter" and cannot abandon the refresh out
    // from under the creator.
    //
    // The flight shares the repository's recursive lock so that every
    // transition is atomic with commitRefresh/failRefresh/supersede and free
    // of lock-order inversions. Waiter resolution and upstream cancellation
    // are always invoked outside the lock; the resolver and slot-cleared
    // signal are consumed at most once, so completion, cancellation, and
    // detachment stay idempotent.
    private final class RefreshFlight {
        private enum State {
            case starting
            case installing
            case installingSuperseded
            case active
            case abandonRequested
            case abandoning
            case finished
        }

        let generation: UInt64
        // One-subscription-per-waiter publisher: init and joinWaiter() each
        // register exactly one waiter, and each returned publisher must be
        // subscribed exactly once so its cancel callback pairs with that
        // registration.
        private var waiterPublisher: AnyPublisher<AuthSession, AuthError>!
        // Completes only once the flight has released the repository slot,
        // i.e. after any upstream cancellation has been issued. Callers that
        // observed a dying flight wait on this before starting a replacement.
        let slotCleared: AnyPublisher<Void, Never>

        private let lock: NSRecursiveLock
        private var state: State = .starting
        private var upstream: AnyCancellable?
        private var activeWaiters = 0
        private var resolver: ((Result<AuthSession, AuthError>) -> Void)?
        private var slotClearedSignal: (() -> Void)?
        private var onAbandoned: ((RefreshFlight) -> Void)?
        private let upstreamWillCancelForAbandonment: (() -> Void)?

        init(
            result: AnyPublisher<AuthSession, AuthError>,
            generation: UInt64,
            lock: NSRecursiveLock,
            resolve: @escaping (Result<AuthSession, AuthError>) -> Void,
            upstreamWillCancelForAbandonment: (() -> Void)?,
            onAbandoned: @escaping (RefreshFlight) -> Void
        ) {
            self.generation = generation
            self.lock = lock
            self.resolver = resolve
            self.upstreamWillCancelForAbandonment = upstreamWillCancelForAbandonment
            self.onAbandoned = onAbandoned

            var clearedPromise: ((Result<Void, Never>) -> Void)?
            self.slotCleared = Future<Void, Never> { promise in
                clearedPromise = promise
            }
            .eraseToAnyPublisher()
            if let clearedPromise {
                self.slotClearedSignal = { clearedPromise(.success(())) }
            }

            self.waiterPublisher = result
                .handleEvents(
                    receiveCancel: { [weak self] in self?.waiterDidCancel() }
                )
                .eraseToAnyPublisher()

            // The creating subscription is registered before the flight is
            // published to the repository slot, so during startup at least
            // one waiter always exists and a joiner's cancellation can
            // never abandon the refresh before the creator has attached.
            self.activeWaiters = 1
        }

        // The creating subscription's pre-registered waiter publisher. Must
        // be subscribed exactly once, by the subscription that created the
        // flight.
        func claimCreatingWaiter() -> AnyPublisher<AuthSession, AuthError> {
            waiterPublisher
        }

        // Atomically registers one additional waiter if the flight can still
        // be joined. Returns nil for a dying or finished flight, in which
        // case the caller must wait for the slot to clear instead.
        func joinWaiter() -> AnyPublisher<AuthSession, AuthError>? {
            lock.lock()
            defer { lock.unlock() }
            guard state == .starting || state == .installing || state == .active else { return nil }
            activeWaiters += 1
            return waiterPublisher
        }

        // MARK: Creator-side startup

        // Atomically claims installation ownership: only the creator moves
        // the flight from starting to installing, and from then on the
        // flight keeps occupying the repository slot until installation is
        // resolved, no matter what supersedes it in the meantime.
        func tryBeginInstalling() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard state == .starting else { return false }
            state = .installing
            return true
        }

        // Last atomic check before the provider publisher is subscribed. If
        // the flight was superseded or abandoned while installing, the
        // subscription is suppressed entirely and no request is issued.
        func shouldSubscribeUpstream() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return state == .installing
        }

        // The creator suppressed the provider subscription because the
        // flight stopped being installable; finalize and release the slot.
        func abortInstallation() {
            lock.lock()
            let shouldFinish = state == .installingSuperseded || state == .abandonRequested
            lock.unlock()
            if shouldFinish {
                finishAbandonment()
            }
        }

        // The creator never claimed installation because the flight stopped
        // being startable while startup was parked.
        func declineUpstream() {
            lock.lock()
            let wasAbandonRequested = state == .abandonRequested
            lock.unlock()
            if wasAbandonRequested {
                finishAbandonment()
            }
            // .finished: a supersede already resolved the waiters and
            // released the slot; nothing is left to do.
        }

        func activateUpstream(_ cancellable: AnyCancellable) {
            lock.lock()
            switch state {
            case .installing:
                upstream = cancellable
                state = .active
                lock.unlock()
            case .installingSuperseded, .abandonRequested:
                // Superseded or abandoned while the subscription was being
                // built: cancel the just-issued request first; only
                // finishAbandonment() afterwards releases the slot, so no
                // replacement can overlap it.
                lock.unlock()
                cancellable.cancel()
                finishAbandonment()
            case .starting, .active, .abandoning, .finished:
                // Terminal or foreign state: never adopt the subscription.
                lock.unlock()
                cancellable.cancel()
            }
        }

        // MARK: Supersession

        // Called with the shared lock held by session adoption
        // (login/signup/social login) and session invalidation
        // (logout/account deletion). Returns the externally visible part of
        // the supersession, which the caller must run outside the lock, or
        // nil when the flight is already tearing itself down. The repository
        // slot is released immediately only when no upstream can exist; in
        // every other case it stays occupied until the old request has been
        // suppressed or its cancellation has been issued.
        func supersede() -> (() -> Void)? {
            lock.lock()
            defer { lock.unlock() }
            switch state {
            case .starting:
                // No upstream exists and tryBeginInstalling can no longer
                // succeed, so the creator's subscription is suppressed and
                // the slot can be released immediately.
                state = .finished
                let onAbandoned = self.onAbandoned
                self.onAbandoned = nil
                onAbandoned?(self)
                let resolver = takeResolverLocked()
                let signalSlotCleared = takeSlotClearedSignalLocked()
                return {
                    resolver?(.failure(.unauthorized))
                    signalSlotCleared?()
                }
            case .installing:
                // The creator is building the provider subscription outside
                // the lock. Keep occupying the slot: the creator will either
                // suppress the subscription or immediately cancel the
                // just-created request before finishAbandonment() releases
                // the slot. Waiters resolve now so the superseded refresh
                // fails promptly.
                state = .installingSuperseded
                let resolver = takeResolverLocked()
                return { resolver?(.failure(.unauthorized)) }
            case .active:
                // A live request exists. Keep occupying the slot until its
                // cancellation has actually been issued, exactly like a
                // final-waiter abandonment.
                state = .abandoning
                let upstream = self.upstream
                self.upstream = nil
                let upstreamWillCancel = upstreamWillCancelForAbandonment
                return { [self] in
                    upstreamWillCancel?()
                    upstream?.cancel()
                    finishAbandonment()
                }
            case .installingSuperseded, .abandonRequested, .abandoning, .finished:
                // Already tearing down; the slot clears through
                // finishAbandonment() once the old upstream is dealt with.
                return nil
            }
        }

        // MARK: Repository-side completion

        // Atomically claims the right to complete with an upstream result.
        // Must be called with the shared lock held so the claim is atomic
        // with the repository's identity check and slot release. A response
        // can legitimately arrive while still installing (before
        // activateUpstream ran); a superseded, abandoning, or finished
        // flight can no longer be claimed, which keeps late results inert.
        func tryBeginCompletion() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard state == .starting || state == .installing || state == .active else { return false }
            state = .finished
            return true
        }

        // Runs the externally visible part of a claimed completion. Must be
        // called outside the repository lock: it cancels the upstream and
        // resolves waiter callbacks, either of which may re-enter Combine.
        func finishCompletion(_ result: Result<AuthSession, AuthError>) {
            lock.lock()
            let upstream = self.upstream
            self.upstream = nil
            self.onAbandoned = nil
            let resolver = takeResolverLocked()
            let signalSlotCleared = takeSlotClearedSignalLocked()
            lock.unlock()

            upstream?.cancel()
            resolver?(result)
            signalSlotCleared?()
        }

        // MARK: Waiter tracking

        private func waiterDidCancel() {
            lock.lock()
            guard state == .starting || state == .installing || state == .active else {
                lock.unlock()
                return
            }
            activeWaiters -= 1
            guard activeWaiters <= 0 else {
                lock.unlock()
                return
            }

            if state == .starting || state == .installing {
                // Defensive: with the creating subscription pre-registered
                // at init and unable to cancel before the upstream is
                // installed, the count cannot reach zero during startup. If
                // it ever does, record the abandonment but keep occupying
                // the slot: the creator will suppress or cancel the request
                // before releasing it.
                state = .abandonRequested
                let resolver = takeResolverLocked()
                lock.unlock()
                // Resolve so a subscriber that grabbed the shared publisher
                // before abandonment terminates instead of hanging forever.
                resolver?(.failure(.unauthorized))
                return
            }

            state = .abandoning
            let upstream = self.upstream
            self.upstream = nil
            lock.unlock()

            // The slot stays occupied until this cancellation has been
            // issued, so no replacement can overlap the rotating request.
            upstreamWillCancelForAbandonment?()
            upstream?.cancel()
            finishAbandonment()
        }

        private func finishAbandonment() {
            lock.lock()
            state = .finished
            let onAbandoned = self.onAbandoned
            self.onAbandoned = nil
            // Detach from the repository while still holding the shared lock
            // so a concurrent commit/fail cannot pass its identity check.
            onAbandoned?(self)
            let resolver = takeResolverLocked()
            let signalSlotCleared = takeSlotClearedSignalLocked()
            lock.unlock()

            resolver?(.failure(.unauthorized))
            signalSlotCleared?()
        }

        private func takeResolverLocked() -> ((Result<AuthSession, AuthError>) -> Void)? {
            let resolver = self.resolver
            self.resolver = nil
            return resolver
        }

        private func takeSlotClearedSignalLocked() -> (() -> Void)? {
            let signal = slotClearedSignal
            slotClearedSignal = nil
            return signal
        }
    }

    private let authRemoteDataSource: AuthRemoteDataSource
    private let tokenStore: any TokenStore
    private let userSessionStore: any UserSessionStore
    private let apiClient: APIClient
    private let refreshWillResolve: (() -> Void)?
    private let refreshDidResolve: (() -> Void)?
    private let refreshUpstreamWillStart: (() -> Void)?
    private let refreshUpstreamWillInstall: (() -> Void)?
    private let refreshUpstreamWillCancel: (() -> Void)?
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
        refreshDidResolve: (() -> Void)? = nil,
        refreshUpstreamWillStart: (() -> Void)? = nil,
        refreshUpstreamWillInstall: (() -> Void)? = nil,
        refreshUpstreamWillCancel: (() -> Void)? = nil
    ) {
        self.authRemoteDataSource = authRemoteDataSource
        self.tokenStore = tokenStore
        self.userSessionStore = userSessionStore
        self.apiClient = apiClient
        self.refreshWillResolve = refreshWillResolve
        self.refreshDidResolve = refreshDidResolve
        self.refreshUpstreamWillStart = refreshUpstreamWillStart
        self.refreshUpstreamWillInstall = refreshUpstreamWillInstall
        self.refreshUpstreamWillCancel = refreshUpstreamWillCancel
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
        // Creating the publisher is side-effect free: no provider request
        // starts and the shared-flight slot stays untouched until a
        // downstream subscriber actually attaches. Each subscription then
        // atomically creates or joins the shared flight with its own waiter
        // registration, so a publisher that is obtained early but subscribed
        // late can never be abandoned by another subscriber's cancellation.
        Deferred { [weak self] () -> AnyPublisher<AuthSession, AuthError> in
            guard let self else {
                return Fail(error: AuthError.unknown(message: "Repository was released"))
                    .eraseToAnyPublisher()
            }
            return self.attachRefreshWaiter()
        }
        .eraseToAnyPublisher()
    }

    // Runs once per downstream subscription of refreshSession(). Atomically
    // (under the repository lock) joins the in-flight refresh as one more
    // waiter, or creates a new flight whose first waiter is this
    // subscription; only after that waiter ownership exists is the upstream
    // provider request built and installed, outside the lock.
    private func attachRefreshWaiter() -> AnyPublisher<AuthSession, AuthError> {
        refreshLock.lock()
        if let inFlightRefresh {
            if let joined = inFlightRefresh.joinWaiter() {
                refreshLock.unlock()
                return joined
            }
            // The previous flight is being abandoned and its upstream
            // cancellation has not been issued yet. A replacement must not
            // overlap the still-live rotating request, so start the new
            // refresh only once the flight has actually released the slot.
            let slotCleared = inFlightRefresh.slotCleared
            refreshLock.unlock()
            return slotCleared
                .setFailureType(to: AuthError.self)
                .flatMap { [weak self] _ -> AnyPublisher<AuthSession, AuthError> in
                    guard let self else {
                        return Fail(error: AuthError.unknown(message: "Repository was released"))
                            .eraseToAnyPublisher()
                    }
                    return self.attachRefreshWaiter()
                }
                .eraseToAnyPublisher()
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
            upstreamWillCancelForAbandonment: refreshUpstreamWillCancel,
            onAbandoned: { [weak self] abandoned in
                guard let self else { return }
                if self.inFlightRefresh === abandoned {
                    self.inFlightRefresh = nil
                }
            }
        )
        inFlightRefresh = flight
        refreshLock.unlock()

        refreshUpstreamWillStart?()

        // The session may have been superseded or invalidated while the
        // flight was still starting. In that case the abandoned provider
        // request is suppressed entirely and never issued.
        guard flight.tryBeginInstalling() else {
            flight.declineUpstream()
            return flight.claimCreatingWaiter()
        }

        refreshUpstreamWillInstall?()

        // Superseded or abandoned between claiming installation and
        // subscribing the provider publisher: suppress the subscription
        // entirely. The flight occupied the slot the whole time, so no
        // replacement could have overlapped it; abortInstallation releases
        // the slot only now.
        guard flight.shouldSubscribeUpstream() else {
            flight.abortInstallation()
            return flight.claimCreatingWaiter()
        }

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
        flight.activateUpstream(cancellable)

        return flight.claimCreatingWaiter()
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
                let deletedUserId = self?.userSessionStore.fetchUser()?.id
                self?.invalidateStoredSession()
                PushNotificationService.shared.deleteRegisteredTokenOnLogout(accessToken: accessToken)
                if let deletedUserId {
                    NotificationCenter.default.post(
                        name: .authAccountDidDelete,
                        object: nil,
                        userInfo: [AuthSessionChangeUserInfoKey.userId: deletedUserId]
                    )
                }
            })
            .eraseToAnyPublisher()
    }

    private func persist(_ session: AuthSession) {
        tokenStore.saveAccessToken(session.accessToken)
        tokenStore.saveRefreshToken(session.refreshToken)
        saveCurrentUser(session.user)
        // Account-aware adoption: a same-account refresh swaps the token
        // and preserves the session epoch (outstanding account-bound
        // requests stay valid); a different account advances the epoch and
        // permanently invalidates every expectation captured before it.
        apiClient.credentialAuthority.adoptAuthenticatedSession(
            accountID: session.user.id,
            accessToken: session.accessToken
        )
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
        apiClient.credentialAuthority.clearSession()
        NotificationCenter.default.post(
            name: .authSessionDidChange,
            object: nil,
            userInfo: [AuthSessionChangeUserInfoKey.isAuthenticated: false]
        )
    }

    // A fresh login/signup/social-login session owns the credential store from
    // this point on: any refresh still in flight was issued for the previous
    // session and must not be allowed to commit or clear on top of it. The
    // generation advance makes every late old callback inert; the superseded
    // flight itself keeps occupying the refresh slot until its old upstream
    // request is definitively suppressed or cancelled, so adoption never
    // opens a window for an overlapping replacement request.
    private func adoptAuthenticatedSession(_ session: AuthSession) {
        refreshLock.lock()
        refreshGeneration &+= 1
        let supersededAction = inFlightRefresh?.supersede()
        persist(session)
        refreshLock.unlock()

        supersededAction?()
    }

    private func commitRefresh(_ session: AuthSession, flight: RefreshFlight) {
        refreshLock.lock()
        guard inFlightRefresh === flight,
              flight.generation == refreshGeneration,
              flight.tryBeginCompletion() else {
            refreshLock.unlock()
            return
        }
        inFlightRefresh = nil
        persist(session)
        refreshLock.unlock()

        flight.finishCompletion(.success(session))
    }

    private func failRefresh(_ error: AuthError, flight: RefreshFlight) {
        refreshLock.lock()
        // The generation check keeps a late failure of a superseded flight
        // (which may still occupy the slot while dying) from clearing a
        // newly adopted session.
        guard inFlightRefresh === flight,
              flight.generation == refreshGeneration,
              flight.tryBeginCompletion() else {
            refreshLock.unlock()
            return
        }
        refreshGeneration &+= 1
        inFlightRefresh = nil
        clearStoredSession()
        refreshLock.unlock()

        flight.finishCompletion(.failure(error))
    }

    private func invalidateStoredSession() {
        refreshLock.lock()
        refreshGeneration &+= 1
        let supersededAction = inFlightRefresh?.supersede()
        clearStoredSession()
        refreshLock.unlock()

        supersededAction?()
    }
}
