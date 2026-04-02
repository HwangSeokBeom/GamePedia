import UIKit
import Combine

enum SessionAccessMode {
    case guest
    case authenticated
}

enum RestrictedActionContext {
    case favoriteGame
    case writeReview
    case viewReviews
    case library
    case profile
    case moderation

    var logName: String {
        switch self {
        case .favoriteGame:
            return "favoriteGame"
        case .writeReview:
            return "writeReview"
        case .viewReviews:
            return "viewReviews"
        case .library:
            return "library"
        case .profile:
            return "profile"
        case .moderation:
            return "moderation"
        }
    }

    var promptMessage: String {
        switch self {
        case .favoriteGame, .writeReview:
            return "로그인하면 리뷰 작성과 찜 기능을 사용할 수 있어요."
        case .viewReviews:
            return "리뷰를 확인하려면 로그인이 필요합니다."
        case .library, .profile:
            return "내 라이브러리와 프로필을 사용하려면 로그인이 필요합니다."
        case .moderation:
            return "이 기능을 사용하려면 로그인이 필요합니다."
        }
    }
}

// MARK: - AppCoordinator
//
// Root coordinator. Owns the window and all tab coordinators.
// SceneDelegate creates one instance and calls start().

final class AppCoordinator {

    private enum Metrics {
        static let splashDuration: TimeInterval = 0.8
        static let transitionDuration: TimeInterval = 0.2
    }

    // MARK: Properties

    private let window: UIWindow
    private let tokenStore: any TokenStore
    private let userSessionStore: any UserSessionStore
    private var authCoordinator: AuthCoordinator?
    private var homeCoordinator: HomeCoordinator?
    private var searchCoordinator: SearchCoordinator?
    private var libraryCoordinator: LibraryCoordinator?
    private var profileCoordinator: ProfileCoordinator?
    private weak var mainTabBarController: MainTabBarController?
    private var modalAuthCoordinator: AuthCoordinator?
    private var pendingResetPasswordToken: String?
    private var pendingSteamLinkCallbackURL: URL?
    private var cancellables = Set<AnyCancellable>()
    private let steamLinkFlowController = SteamLinkFlowController()
    private lazy var socialActivityBannerPresenter = SocialActivityBannerPresenter(window: window)

    private lazy var authRemoteDataSource = AuthRemoteDataSource(tokenStore: tokenStore)
    private lazy var authRepository: any AuthRepository = DefaultAuthRepository(
        authRemoteDataSource: authRemoteDataSource,
        tokenStore: tokenStore,
        userSessionStore: userSessionStore
    )
    private lazy var loginUseCase = LoginUseCase(authRepository: authRepository)
    private lazy var appleLoginUseCase = AppleLoginUseCase(authRepository: authRepository)
    private lazy var googleLoginUseCase = GoogleLoginUseCase(authRepository: authRepository)
    private lazy var signUpUseCase = SignUpUseCase(authRepository: authRepository)
    private lazy var forgotPasswordUseCase = ForgotPasswordUseCase(authRepository: authRepository)
    private lazy var resetPasswordUseCase = ResetPasswordUseCase(authRepository: authRepository)
    private lazy var refreshSessionUseCase = RefreshSessionUseCase(authRepository: authRepository)
    private lazy var fetchCurrentUserUseCase = FetchCurrentUserUseCase(authRepository: authRepository)
    private lazy var updateCurrentUserProfileUseCase = UpdateCurrentUserProfileUseCase(authRepository: authRepository)
    private lazy var uploadCurrentUserProfileImageUseCase = UploadCurrentUserProfileImageUseCase(authRepository: authRepository)
    private lazy var removeCurrentUserProfileImageUseCase = RemoveCurrentUserProfileImageUseCase(authRepository: authRepository)
    private lazy var logoutUseCase = LogoutUseCase(authRepository: authRepository)
    private lazy var deleteAccountUseCase = DeleteAccountUseCase(authRepository: authRepository)

    // MARK: Init

    init(window: UIWindow) {
        self.window = window
        self.tokenStore = KeychainTokenStore()
        self.userSessionStore = InMemoryUserSessionStore.shared
    }

    // MARK: Start

    func start() {
        bindSocialActivityEvents()
        showSplash()
    }

    @discardableResult
    func handleIncomingURL(_ url: URL) -> Bool {
        if SteamLinkCallbackParser.isSteamCallbackURL(url) {
            if window.rootViewController is SplashViewController {
                pendingSteamLinkCallbackURL = url
            } else {
                _ = steamLinkFlowController.handleIncomingURL(url)
            }
            return true
        }

        guard let resetPasswordToken = resetPasswordToken(from: url) else { return false }
        print("[PasswordReset] deepLinkReceived tokenLength=\(resetPasswordToken.count)")

        if window.rootViewController is SplashViewController {
            pendingResetPasswordToken = resetPasswordToken
            return true
        }

        presentResetPasswordFlow(token: resetPasswordToken)
        return true
    }

    private func showSplash() {
        let splashViewController = SplashViewController()
        window.backgroundColor = .gpBackground
        window.rootViewController = splashViewController
        window.makeKeyAndVisible()

        DispatchQueue.main.asyncAfter(deadline: .now() + Metrics.splashDuration) { [weak self] in
            self?.resolveInitialInterface()
        }
    }

    private func bindSocialActivityEvents() {
        SocialActivityEventDispatcher.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleSocialActivityEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleSocialActivityEvent(_ event: SocialActivityAppEvent) {
        switch event {
        case .showBanner(let payload):
            socialActivityBannerPresenter.enqueue(payload: payload) { [weak self] in
                self?.handleSocialActivityRoute(payload.route)
            }
        case .route(let route):
            handleSocialActivityRoute(route)
        }
    }

    private func handleSocialActivityRoute(_ route: SocialActivityRoute) {
        switch route {
        case .friendActivityFeed:
            ensureMainInterface(selectedIndex: 3)
            profileCoordinator?.navigateToFriendActivityFeed()
        case .friendRequests:
            ensureMainInterface(selectedIndex: 3)
            profileCoordinator?.navigateToFriendRequests()
        case .friendProfile(let userID):
            ensureMainInterface(selectedIndex: 3)
            profileCoordinator?.navigateToFriendProfile(userID: userID)
        case .gameDetail(let gameID):
            ensureMainInterface(selectedIndex: 0)
            homeCoordinator?.navigateToGameDetail(gameID: gameID)
        case .review(let gameID, _):
            ensureMainInterface(selectedIndex: 0)
            homeCoordinator?.navigateToGameDetail(gameID: gameID)
        }
    }

    private func ensureMainInterface(selectedIndex: Int) {
        if mainTabBarController == nil {
            showMainInterface(selectedIndex: selectedIndex)
        } else {
            mainTabBarController?.selectTab(index: selectedIndex)
        }
    }

    private func resolveInitialInterface() {
        showMainInterface()
        refreshSessionIfNeeded()
    }

    private func refreshSessionIfNeeded() {
        guard tokenStore.fetchRefreshToken() != nil else {
            print("[GuestMode] active runtime=noRefreshToken")
            return
        }

        refreshSessionUseCase.execute()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        print("[GuestMode] refreshFailed continuingAsGuest=true")
                    }
                },
                receiveValue: { _ in
                    print("[GuestMode] sessionRestored mode=authenticated")
                }
            )
            .store(in: &cancellables)
    }

    private func makeAuthCoordinator() -> AuthCoordinator {
        AuthCoordinator(
            loginUseCase: loginUseCase,
            appleLoginUseCase: appleLoginUseCase,
            googleLoginUseCase: googleLoginUseCase,
            signUpUseCase: signUpUseCase,
            forgotPasswordUseCase: forgotPasswordUseCase,
            resetPasswordUseCase: resetPasswordUseCase
        )
    }

    private func showMainInterface(selectedIndex: Int = 0) {
        let mainTabBarController = makeMainTabBarController(selectedIndex: selectedIndex)
        UIView.transition(
            with: window,
            duration: Metrics.transitionDuration,
            options: [.transitionCrossDissolve, .allowAnimatedContent]
        ) {
            self.window.rootViewController = mainTabBarController
        }
        self.mainTabBarController = mainTabBarController
        modalAuthCoordinator = nil
        authCoordinator = nil

        if let pendingResetPasswordToken {
            self.pendingResetPasswordToken = nil
            DispatchQueue.main.async { [weak self] in
                self?.presentResetPasswordFlow(token: pendingResetPasswordToken)
            }
        }

        if let pendingSteamLinkCallbackURL {
            self.pendingSteamLinkCallbackURL = nil
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                _ = self.steamLinkFlowController.handleIncomingURL(pendingSteamLinkCallbackURL)
            }
        }
    }

    private func makeMainTabBarController(selectedIndex: Int) -> MainTabBarController {
        let homeCoord    = HomeCoordinator()
        let searchCoord  = SearchCoordinator()
        let libraryCoord = LibraryCoordinator(steamLinkFlowController: steamLinkFlowController)
        let profileCoord = ProfileCoordinator(
            fetchCurrentUserUseCase: fetchCurrentUserUseCase,
            updateCurrentUserProfileUseCase: updateCurrentUserProfileUseCase,
            uploadCurrentUserProfileImageUseCase: uploadCurrentUserProfileImageUseCase,
            removeCurrentUserProfileImageUseCase: removeCurrentUserProfileImageUseCase,
            logoutUseCase: logoutUseCase,
            deleteAccountUseCase: deleteAccountUseCase,
            userSessionStore: userSessionStore,
            steamLinkFlowController: steamLinkFlowController
        )
        let authenticationHandler: (UIViewController, RestrictedActionContext, @escaping () -> Void) -> Void = {
            [weak self] presenter, context, completion in
            self?.requestAuthenticationIfNeeded(
                from: presenter,
                context: context,
                onAuthenticated: completion
            )
        }
        homeCoord.onAuthenticationRequested = authenticationHandler
        searchCoord.onAuthenticationRequested = authenticationHandler
        libraryCoord.onAuthenticationRequested = authenticationHandler
        profileCoord.onAuthenticationRequested = authenticationHandler
        profileCoord.onLoggedOut = { [weak self] in
            print("[GuestMode] logoutCompleted switchingToGuestMode=true")
            self?.showMainInterface(selectedIndex: 0)
        }

        homeCoord.start()
        searchCoord.start()
        libraryCoord.start()
        profileCoord.start()

        self.homeCoordinator    = homeCoord
        self.searchCoordinator  = searchCoord
        self.libraryCoordinator = libraryCoord
        self.profileCoordinator = profileCoord

        let mainTabBarController = MainTabBarController(tabNavigationControllers: [
            homeCoord.navigationController,
            searchCoord.navigationController,
            libraryCoord.navigationController,
            profileCoord.navigationController
        ])
        mainTabBarController.onTabSelectionRequested = { [weak self, weak mainTabBarController] index in
            guard let self, let mainTabBarController else { return false }
            return self.handleTabSelection(index: index, in: mainTabBarController)
        }
#if DEBUG
        mainTabBarController.onDebugEnvironmentMenuRequested = { [weak self, weak mainTabBarController] in
            guard let self, let mainTabBarController else { return }
            self.presentDebugEnvironmentMenu(from: mainTabBarController)
        }
#endif
        mainTabBarController.selectTab(index: selectedIndex)
        return mainTabBarController
    }

    private func handleTabSelection(index: Int, in mainTabBarController: MainTabBarController) -> Bool {
        switch index {
        case 2:
            guard currentSessionAccessMode() == .guest else { return true }
            requestAuthenticationIfNeeded(
                from: mainTabBarController,
                context: .library
            ) {
                mainTabBarController.selectTab(index: index)
            }
            return false
        case 3:
            guard currentSessionAccessMode() == .guest else { return true }
            requestAuthenticationIfNeeded(
                from: mainTabBarController,
                context: .profile
            ) {
                mainTabBarController.selectTab(index: index)
            }
            return false
        default:
            return true
        }
    }

    private func currentSessionAccessMode() -> SessionAccessMode {
        let hasAccessToken = tokenStore.fetchAccessToken() != nil
        let hasRefreshToken = tokenStore.fetchRefreshToken() != nil
        return (hasAccessToken || hasRefreshToken) ? .authenticated : .guest
    }

    private func requestAuthenticationIfNeeded(
        from presenter: UIViewController,
        context: RestrictedActionContext,
        onAuthenticated: @escaping () -> Void
    ) {
        guard currentSessionAccessMode() == .guest else {
            onAuthenticated()
            return
        }

        guard presenter.presentedViewController == nil else { return }

        print("[GuestMode] restrictedActionTriggered action=\(context.logName)")

        let alertController = UIAlertController(
            title: "로그인이 필요합니다",
            message: context.promptMessage,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "나중에 하기", style: .cancel))
        alertController.addAction(UIAlertAction(title: "로그인", style: .default) { [weak self, weak presenter] _ in
            guard let self, let presenter else { return }
            print("[GuestMode] loginRouteRequested action=\(context.logName)")
            self.presentAuthFlow(from: presenter, onAuthenticated: onAuthenticated)
        })
        presenter.present(alertController, animated: true)
    }

    private func presentAuthFlow(
        from presenter: UIViewController,
        onAuthenticated: @escaping () -> Void
    ) {
        if let modalAuthCoordinator,
           modalAuthCoordinator.navigationController.presentingViewController != nil {
            return
        }

        if let modalAuthCoordinator,
           modalAuthCoordinator.navigationController.presentingViewController == nil {
            self.modalAuthCoordinator = nil
        }

        let authCoordinator = makeAuthCoordinator()
        authCoordinator.onAuthenticated = { [weak self, weak authNavigationController = authCoordinator.navigationController] in
            authNavigationController?.dismiss(animated: true) {
                self?.modalAuthCoordinator = nil
                onAuthenticated()
            }
        }
        authCoordinator.start()

        let navigationController = authCoordinator.navigationController
        navigationController.modalPresentationStyle = .pageSheet
        if let sheetPresentationController = navigationController.sheetPresentationController {
            sheetPresentationController.detents = [.large()]
            sheetPresentationController.prefersGrabberVisible = true
        }

        modalAuthCoordinator = authCoordinator
        presenter.present(navigationController, animated: true)
    }

    private func presentResetPasswordFlow(token: String) {
        guard let presenter = topPresenter(from: window.rootViewController) else { return }

        if let modalAuthCoordinator,
           modalAuthCoordinator.navigationController.presentingViewController != nil {
            modalAuthCoordinator.showResetPassword(token: token)
            return
        }

        if let modalAuthCoordinator,
           modalAuthCoordinator.navigationController.presentingViewController == nil {
            self.modalAuthCoordinator = nil
        }

        let authCoordinator = makeAuthCoordinator()
        authCoordinator.start(resetPasswordToken: token)

        let navigationController = authCoordinator.navigationController
        navigationController.modalPresentationStyle = .pageSheet
        if let sheetPresentationController = navigationController.sheetPresentationController {
            sheetPresentationController.detents = [.large()]
            sheetPresentationController.prefersGrabberVisible = true
        }

        modalAuthCoordinator = authCoordinator
        presenter.present(navigationController, animated: true)
    }

    private func topPresenter(from rootViewController: UIViewController?) -> UIViewController? {
        if let navigationController = rootViewController as? UINavigationController {
            return topPresenter(from: navigationController.visibleViewController) ?? navigationController
        }

        if let tabBarController = rootViewController as? UITabBarController {
            return topPresenter(from: tabBarController.selectedViewController) ?? tabBarController
        }

        if let presentedViewController = rootViewController?.presentedViewController {
            return topPresenter(from: presentedViewController)
        }

        return rootViewController
    }

    private func resetPasswordToken(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "gamepedia" else { return nil }

        let route = url.host?.lowercased() ?? url.path.replacingOccurrences(of: "/", with: "").lowercased()
        guard route == "reset-password" else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "token" })?.value
    }

#if DEBUG
    private func presentDebugEnvironmentMenu(from presenter: UIViewController) {
        EnvironmentDebugMenuPresenter.present(
            from: presenter,
            currentEnvironment: AppConfig.apiEnvironment,
            selectedOverride: DebugEnvironmentSelectionStore.selectedEnvironment
        ) { [weak presenter] selectedEnvironment in
            DebugEnvironmentSelectionStore.selectedEnvironment = selectedEnvironment
            let resolvedEnvironment = selectedEnvironment ?? AppEnvironmentResolver.current
            let alertController = UIAlertController(
                title: "환경이 저장되었습니다",
                message: """
                다음 실행부터 \(resolvedEnvironment.rawValue) 환경이 적용됩니다.

                API: \(resolvedEnvironment.apiBaseURL.absoluteString)
                Translation: \(resolvedEnvironment.translationBaseURL.absoluteString)
                """,
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "확인", style: .default))
            presenter?.present(alertController, animated: true)
        }
    }
#endif
}
