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
            return L10n.tr("Localizable", "app.authRequired.prompt.favorite")
        case .viewReviews:
            return L10n.tr("Localizable", "app.authRequired.prompt.viewReviews")
        case .library, .profile:
            return L10n.tr("Localizable", "app.authRequired.prompt.libraryProfile")
        case .moderation:
            return L10n.tr("Localizable", "app.authRequired.prompt.default")
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
    private var pendingWidgetDeepLink: WidgetDeepLink?
    private var pendingWidgetReviewItem: ReviewPromptWidgetSnapshot.Item?
    private var pendingPushPayload: PushNotificationPayload?
    private var cancellables = Set<AnyCancellable>()
    private let steamLinkFlowController = SteamLinkFlowController()
    private lazy var socialActivityBannerPresenter = SocialActivityBannerPresenter(window: window)
    private lazy var widgetSnapshotStore = GameWidgetSnapshotStore.shared
    private lazy var widgetSnapshotRefreshService = GameWidgetSnapshotRefreshService(
        snapshotStore: widgetSnapshotStore
    )

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
        bindPushRouteEvents()
        bindWidgetSnapshotEvents()
        showSplash()
#if DEBUG
        applyDebugLaunchOverridesIfNeeded()
#endif
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

        if let widgetDeepLink = WidgetDeepLink(url: url) {
            let reviewItem = reviewPromptItem(for: widgetDeepLink)

            if window.rootViewController is SplashViewController || mainTabBarController == nil {
                pendingWidgetDeepLink = widgetDeepLink
                pendingWidgetReviewItem = reviewItem
            } else {
                handleWidgetDeepLink(widgetDeepLink, reviewItem: reviewItem)
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

    private func bindPushRouteEvents() {
        PushRouteDispatcher.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard case .route(let payload) = event else { return }
                self?.handlePushPayload(payload)
            }
            .store(in: &cancellables)

        if let payload = PushRouteDispatcher.shared.drainPendingRoute() {
            handlePushPayload(payload)
        }
    }

    private func bindWidgetSnapshotEvents() {
        NotificationCenter.default.publisher(for: .recentViewedDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshWidgetSnapshots(reason: "recentViewedDidChange")
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .favoriteDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshWidgetSnapshots(reason: "favoriteDidChange")
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .reviewDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshWidgetSnapshots(reason: "reviewDidChange")
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
        case .review(let gameID, let reviewID, let commentID):
            ensureMainInterface(selectedIndex: 0)
            homeCoordinator?.navigateToReviewDiscussion(gameID: gameID, reviewID: reviewID, commentID: commentID)
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
#if DEBUG
        guard WidgetDebugQAHelper.shouldSkipAutomaticSessionRefresh == false else {
            print("[WidgetDebug] skipping session refresh due to debug launch override")
            return
        }
#endif
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
                    self.refreshWidgetSnapshots(reason: "sessionRestored")
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

        if let pendingWidgetDeepLink {
            let pendingReviewItem = pendingWidgetReviewItem
            self.pendingWidgetDeepLink = nil
            self.pendingWidgetReviewItem = nil
            DispatchQueue.main.async { [weak self] in
                self?.handleWidgetDeepLink(pendingWidgetDeepLink, reviewItem: pendingReviewItem)
            }
        }

        if let pendingPushPayload {
            self.pendingPushPayload = nil
            DispatchQueue.main.async { [weak self] in
                self?.executePushRoute(pendingPushPayload)
            }
        }

        refreshWidgetSnapshots(reason: "showMainInterface")
        NotificationBadgeRefreshService.shared.refresh(reason: "showMainInterface")
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
            title: L10n.tr("Localizable", "app.authRequired.title"),
            message: context.promptMessage,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: L10n.tr("Localizable", "app.authRequired.later"), style: .cancel))
        alertController.addAction(UIAlertAction(title: L10n.Settings.Action.login, style: .default) { [weak self, weak presenter] _ in
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
                self?.refreshWidgetSnapshots(reason: "authCompleted")
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

    func refreshWidgetSnapshots(reason: String) {
        widgetSnapshotRefreshService.refresh(reason: reason)
    }

    private func handlePushPayload(_ payload: PushNotificationPayload) {
        guard mainTabBarController != nil else {
            pendingPushPayload = payload
            print("[PushRoute] deferred reason=mainInterfaceNotReady")
            return
        }

        executePushRoute(payload)
    }

    private func executePushRoute(_ payload: PushNotificationPayload) {
        NotificationBadgeRefreshService.shared.refresh(reason: "pushRoute", force: true)

        switch payload.destination {
        case .notifications:
            ensureMainInterface(selectedIndex: 0)
            homeCoordinator?.navigateToNotifications()
            print("[PushRoute] executed destination=notifications")
        case .gameDetail(let gameID):
            ensureMainInterface(selectedIndex: 0)
            homeCoordinator?.navigateToGameDetail(gameID: gameID)
            print("[PushRoute] executed destination=gameDetail id=\(gameID)")
        case .reviewDetail(let gameID, let reviewID, let commentID):
            ensureMainInterface(selectedIndex: 0)
            homeCoordinator?.navigateToReviewDiscussion(gameID: gameID, reviewID: reviewID, commentID: commentID)
            print("[PushRoute] executed destination=reviewDetail gameId=\(gameID) reviewId=\(reviewID ?? "nil")")
        case .friendRequests:
            ensureMainInterface(selectedIndex: 3)
            profileCoordinator?.navigateToFriendRequests()
            print("[PushRoute] executed destination=friendRequests")
        case .profile(let userID):
            ensureMainInterface(selectedIndex: 3)
            if let userID {
                profileCoordinator?.navigateToFriendProfile(userID: userID)
                print("[PushRoute] executed destination=profile id=\(userID)")
            } else {
                print("[PushRoute] executed destination=profile")
            }
        case .libraryCurator:
            guard currentSessionAccessMode() == .authenticated else {
                ensureMainInterface(selectedIndex: 0)
                homeCoordinator?.navigateToNotifications()
                print("[PushRoute] fallback destination=notifications reason=authRequired")
                return
            }
            ensureMainInterface(selectedIndex: 2)
            libraryCoordinator?.navigateToLibraryCurator()
            print("[PushRoute] executed destination=libraryCurator")
        }
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

    private func handleWidgetDeepLink(
        _ deepLink: WidgetDeepLink,
        reviewItem: ReviewPromptWidgetSnapshot.Item?
    ) {
        switch deepLink {
        case .game(let gameID):
            ensureMainInterface(selectedIndex: 0)
            homeCoordinator?.navigateToGameDetail(gameID: gameID)
        case .trending:
            ensureMainInterface(selectedIndex: 0)
            guard let items = widgetSnapshotStore.loadTrendingGames()?.items,
                  items.isEmpty == false else {
                return
            }
            homeCoordinator?.navigateToTrendingGameList(items: items)
        case .profile:
            guard currentSessionAccessMode() == .authenticated else {
                pendingWidgetDeepLink = deepLink
                pendingWidgetReviewItem = nil

                guard let presenter = topPresenter(from: window.rootViewController) else { return }
                presentAuthFlow(from: presenter) { [weak self] in
                    guard let self, let pendingWidgetDeepLink = self.pendingWidgetDeepLink else { return }
                    self.pendingWidgetDeepLink = nil
                    self.handleWidgetDeepLink(pendingWidgetDeepLink, reviewItem: nil)
                }
                return
            }

            ensureMainInterface(selectedIndex: 3)
        case .login:
            guard currentSessionAccessMode() == .guest,
                  let presenter = topPresenter(from: window.rootViewController) else {
                return
            }
            presentAuthFlow(from: presenter) {}
        case .review(let reviewID):
            guard currentSessionAccessMode() == .authenticated else {
                pendingWidgetDeepLink = deepLink
                pendingWidgetReviewItem = nil

                guard let presenter = topPresenter(from: window.rootViewController) else { return }
                presentAuthFlow(from: presenter) { [weak self] in
                    guard let self, let pendingWidgetDeepLink = self.pendingWidgetDeepLink else { return }
                    self.pendingWidgetDeepLink = nil
                    self.handleWidgetDeepLink(pendingWidgetDeepLink, reviewItem: nil)
                }
                return
            }

            guard let reviewItem = activityReviewItem(for: reviewID) else {
                ensureMainInterface(selectedIndex: 3)
                return
            }

            ensureMainInterface(selectedIndex: 0)
            homeCoordinator?.navigateToReviewDiscussion(
                gameID: reviewItem.gameID,
                reviewID: reviewItem.reviewID,
                commentID: nil,
                gameTitle: reviewItem.gameTitle
            )
        case .reviewNew(let gameID):
            let resolvedItem = reviewItem ?? reviewPromptItem(forGameID: gameID)

            guard currentSessionAccessMode() == .authenticated else {
                pendingWidgetDeepLink = deepLink
                pendingWidgetReviewItem = resolvedItem

                guard let presenter = topPresenter(from: window.rootViewController) else { return }
                presentAuthFlow(from: presenter) { [weak self] in
                    guard let self, let pendingWidgetDeepLink = self.pendingWidgetDeepLink else { return }
                    let pendingReviewItem = self.pendingWidgetReviewItem
                    self.pendingWidgetDeepLink = nil
                    self.pendingWidgetReviewItem = nil
                    self.handleWidgetDeepLink(pendingWidgetDeepLink, reviewItem: pendingReviewItem)
                }
                return
            }

            ensureMainInterface(selectedIndex: 0)
            if let resolvedItem {
                homeCoordinator?.navigateToReviewComposer(item: resolvedItem)
            } else {
                homeCoordinator?.navigateToGameDetail(gameID: gameID)
            }
        }
    }

    private func reviewPromptItem(for deepLink: WidgetDeepLink) -> ReviewPromptWidgetSnapshot.Item? {
        guard case .reviewNew(let gameID) = deepLink else { return nil }
        return reviewPromptItem(forGameID: gameID)
    }

    private func reviewPromptItem(forGameID gameID: Int) -> ReviewPromptWidgetSnapshot.Item? {
        guard let item = widgetSnapshotStore.loadReviewPrompt()?.items.first(where: { $0.gameID == gameID }) else {
            return nil
        }
        return item
    }

    private func activityReviewItem(for reviewID: String) -> MyActivityWidgetSnapshot.ReviewItem? {
        widgetSnapshotStore.loadMyActivity()?.recentReviews.first(where: { $0.reviewID == reviewID })
    }

#if DEBUG
    private func presentDebugEnvironmentMenu(from presenter: UIViewController) {
        EnvironmentDebugMenuPresenter.present(
            from: presenter,
            currentEnvironment: AppConfig.apiEnvironment,
            onRefreshWidgetSnapshots: { [weak self] in
                self?.refreshWidgetSnapshots(reason: "debug.manualRefresh")
            },
            onSeedWidgetSamples: {
                WidgetDebugQAHelper.seedSampleSnapshots()
            },
            onSeedLoggedOutWidgetSamples: {
                WidgetDebugQAHelper.seedLoggedOutSnapshots()
            }
        )
    }

    private func applyDebugLaunchOverridesIfNeeded() {
        if let launchURL = WidgetDebugQAHelper.applyLaunchOverrides(snapshotStore: widgetSnapshotStore) {
            _ = handleIncomingURL(launchURL)
        }
    }
#endif
}
