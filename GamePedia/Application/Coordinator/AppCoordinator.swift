import UIKit
import Combine

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
    private var cancellables = Set<AnyCancellable>()

    private lazy var authRemoteDataSource = AuthRemoteDataSource(tokenStore: tokenStore)
    private lazy var authRepository: any AuthRepository = DefaultAuthRepository(
        authRemoteDataSource: authRemoteDataSource,
        tokenStore: tokenStore,
        userSessionStore: userSessionStore
    )
    private lazy var loginUseCase = LoginUseCase(authRepository: authRepository)
    private lazy var signUpUseCase = SignUpUseCase(authRepository: authRepository)
    private lazy var refreshSessionUseCase = RefreshSessionUseCase(authRepository: authRepository)
    private lazy var fetchCurrentUserUseCase = FetchCurrentUserUseCase(authRepository: authRepository)
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
        showSplash()
    }

    private func showSplash() {
        let splashViewController = SplashViewController()
        window.backgroundColor = UIColor(hex: "#0B0B0E")
        window.rootViewController = splashViewController
        window.makeKeyAndVisible()

        DispatchQueue.main.asyncAfter(deadline: .now() + Metrics.splashDuration) { [weak self] in
            self?.resolveInitialInterface()
        }
    }

    private func resolveInitialInterface() {
        guard tokenStore.fetchRefreshToken() != nil else {
            showAuthInterface()
            return
        }

        refreshSessionUseCase.execute()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.showAuthInterface()
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.showMainInterface()
                }
            )
            .store(in: &cancellables)
    }

    private func showAuthInterface() {
        homeCoordinator = nil
        searchCoordinator = nil
        libraryCoordinator = nil
        profileCoordinator = nil

        let authCoordinator = AuthCoordinator(
            loginUseCase: loginUseCase,
            signUpUseCase: signUpUseCase
        )
        authCoordinator.onAuthenticated = { [weak self] in
            self?.showMainInterface()
        }
        authCoordinator.start()
        self.authCoordinator = authCoordinator

        UIView.transition(
            with: window,
            duration: Metrics.transitionDuration,
            options: [.transitionCrossDissolve, .allowAnimatedContent]
        ) {
            self.window.rootViewController = authCoordinator.navigationController
        }
    }

    private func showMainInterface() {
        let mainTabBarController = makeMainTabBarController()
        UIView.transition(
            with: window,
            duration: Metrics.transitionDuration,
            options: [.transitionCrossDissolve, .allowAnimatedContent]
        ) {
            self.window.rootViewController = mainTabBarController
        }
        authCoordinator = nil
    }

    private func makeMainTabBarController() -> MainTabBarController {
        let homeCoord    = HomeCoordinator()
        let searchCoord  = SearchCoordinator()
        let libraryCoord = LibraryCoordinator()
        let profileCoord = ProfileCoordinator(
            fetchCurrentUserUseCase: fetchCurrentUserUseCase,
            logoutUseCase: logoutUseCase,
            deleteAccountUseCase: deleteAccountUseCase,
            userSessionStore: userSessionStore
        )
        profileCoord.onLoggedOut = { [weak self] in
            self?.showAuthInterface()
        }

        homeCoord.start()
        searchCoord.start()
        libraryCoord.start()
        profileCoord.start()

        self.homeCoordinator    = homeCoord
        self.searchCoordinator  = searchCoord
        self.libraryCoordinator = libraryCoord
        self.profileCoordinator = profileCoord

        return MainTabBarController(tabNavigationControllers: [
            homeCoord.navigationController,
            searchCoord.navigationController,
            libraryCoord.navigationController,
            profileCoord.navigationController
        ])
    }
}
