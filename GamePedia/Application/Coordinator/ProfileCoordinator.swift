import SafariServices
import UIKit

// MARK: - ProfileCoordinator

final class ProfileCoordinator: NSObject {

    // MARK: Properties

    let navigationController: UINavigationController
    private let fetchCurrentUserUseCase: FetchCurrentUserUseCase
    private let updateCurrentUserProfileUseCase: UpdateCurrentUserProfileUseCase
    private let uploadCurrentUserProfileImageUseCase: UploadCurrentUserProfileImageUseCase
    private let removeCurrentUserProfileImageUseCase: RemoveCurrentUserProfileImageUseCase
    private let logoutUseCase: LogoutUseCase
    private let deleteAccountUseCase: DeleteAccountUseCase
    private let userSessionStore: any UserSessionStore
    private let steamLinkFlowController: any SteamLinkFlowControlling
    var onAuthenticationRequested: ((UIViewController, RestrictedActionContext, @escaping () -> Void) -> Void)?

    var onLoggedOut: (() -> Void)?

    // MARK: Init

    init(
        fetchCurrentUserUseCase: FetchCurrentUserUseCase,
        updateCurrentUserProfileUseCase: UpdateCurrentUserProfileUseCase,
        uploadCurrentUserProfileImageUseCase: UploadCurrentUserProfileImageUseCase,
        removeCurrentUserProfileImageUseCase: RemoveCurrentUserProfileImageUseCase,
        logoutUseCase: LogoutUseCase,
        deleteAccountUseCase: DeleteAccountUseCase,
        userSessionStore: any UserSessionStore,
        steamLinkFlowController: any SteamLinkFlowControlling
    ) {
        self.fetchCurrentUserUseCase = fetchCurrentUserUseCase
        self.updateCurrentUserProfileUseCase = updateCurrentUserProfileUseCase
        self.uploadCurrentUserProfileImageUseCase = uploadCurrentUserProfileImageUseCase
        self.removeCurrentUserProfileImageUseCase = removeCurrentUserProfileImageUseCase
        self.logoutUseCase = logoutUseCase
        self.deleteAccountUseCase = deleteAccountUseCase
        self.userSessionStore = userSessionStore
        self.steamLinkFlowController = steamLinkFlowController
        navigationController = UINavigationController()
        navigationController.tabBarItem = UITabBarItem(
            title: "프로필",
            image: UIImage(systemName: "person"),
            selectedImage: UIImage(systemName: "person.fill")
        )
        NavigationBarStyler.configureGlobalAppearance(on: navigationController.navigationBar)
    }

    // MARK: Start

    func start() {
        let profileViewModel = ProfileViewModel(
            fetchCurrentUserUseCase: fetchCurrentUserUseCase,
            logoutUseCase: logoutUseCase,
            deleteAccountUseCase: deleteAccountUseCase,
            userSessionStore: userSessionStore
        )
        let profileVC = ProfileViewController(
            rootView: ProfileRootView(),
            viewModel: profileViewModel
        )
        profileVC.onGameSelected = { [weak self] gameId in
            self?.showDetail(gameId: gameId)
        }
        profileVC.onLoggedOut = { [weak self] in
            self?.onLoggedOut?()
        }
        profileVC.onShowEditProfile = { [weak self] in
            self?.showEditProfile()
        }
        profileVC.onShowFavoriteGames = { [weak self] in
            self?.showLibrary(tab: .favorites)
        }
        profileVC.onShowWrittenReviews = { [weak self] in
            self?.showLibrary(tab: .reviewed)
        }
        profileVC.onShowTermsOfService = { [weak self] in
            self?.showWebPage(url: AppConfig.termsOfServiceURL)
        }
        profileVC.onShowPrivacyPolicy = { [weak self] in
            self?.showWebPage(url: AppConfig.privacyPolicyURL)
        }
        profileVC.onShowCommunityGuidelines = { [weak self] in
            self?.showWebPage(url: AppConfig.communityGuidelinesURL)
        }
        profileVC.onContactSupport = { [weak self] in
            self?.contactSupport()
        }
        navigationController.setViewControllers([profileVC], animated: false)
    }

    // MARK: - Navigation

    private func showDetail(gameId: Int) {
        let detailVC = GameDetailViewController(gameId: gameId)
        detailVC.onAuthenticationRequired = { [weak self, weak detailVC] context, action in
            guard let self else { return }
            let presenter = detailVC ?? self.navigationController.topViewController ?? self.navigationController
            self.onAuthenticationRequested?(presenter, context, action)
        }
        detailVC.onWriteReview = { [weak self, weak detailVC] game, existingReview in
            self?.showReview(game: game, existingReview: existingReview, detailViewController: detailVC)
        }
        detailVC.onShowAllReviews = { [weak self, weak detailVC] game in
            self?.showGameReviews(game: game, detailViewController: detailVC)
        }
        detailVC.onShare = { [weak self] game in
            guard let topVC = self?.navigationController.topViewController else { return }
            let items: [Any] = ["\(game.displayTitle) — GamePedia에서 확인해보세요!"]
            let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
            topVC.present(activityVC, animated: true)
        }
        navigationController.pushViewController(detailVC, animated: true)
    }

    private func showReview(
        game: GameDetail,
        existingReview: Review? = nil,
        detailViewController: GameDetailViewController?,
        reviewsViewController: GameReviewsViewController? = nil
    ) {
        let reviewVC = ReviewViewController(
            rootView: ReviewRootView(),
            viewModel: ReviewViewModel(
                gameId: game.id,
                gameName: game.displayTitle,
                gameSubtitle: game.developerLine,
                gameThumbnailURL: game.coverImageURL?.absoluteString ?? "",
                existingReview: existingReview
            )
        )
        reviewVC.onReviewSubmitted = { [weak detailViewController, weak reviewsViewController] in
            detailViewController?.reload()
            reviewsViewController?.reload()
        }
        navigationController.pushViewController(reviewVC, animated: true)
    }

    private func showGameReviews(game: GameDetail, detailViewController: GameDetailViewController?) {
        let reviewsViewController = GameReviewsViewController(
            rootView: GameReviewsRootView(),
            viewModel: GameReviewsViewModel(
                gameId: game.id,
                gameTitle: game.displayTitle
            )
        )
        reviewsViewController.onAuthenticationRequired = { [weak self, weak reviewsViewController] context, action in
            guard let self else { return }
            let presenter = reviewsViewController ?? self.navigationController.topViewController ?? self.navigationController
            self.onAuthenticationRequested?(presenter, context, action)
        }
        reviewsViewController.onComposeRequested = { [weak self, weak detailViewController, weak reviewsViewController] existingReview in
            self?.showReview(
                game: game,
                existingReview: existingReview,
                detailViewController: detailViewController,
                reviewsViewController: reviewsViewController
            )
        }
        reviewsViewController.onReviewsChanged = { [weak detailViewController] in
            detailViewController?.reload()
        }
        navigationController.pushViewController(reviewsViewController, animated: true)
    }

    private func showLibrary(tab: LibraryTab) {
        let libraryViewController = LibraryViewController(
            rootView: LibraryRootView(),
            viewModel: LibraryViewModel(initialTab: tab)
        )
        libraryViewController.onGameSelected = { [weak self] gameId in
            self?.showDetail(gameId: gameId)
        }
        libraryViewController.onSteamDetailRequested = { [weak self] viewState in
            self?.showSteamDetail(viewState: viewState)
        }
        libraryViewController.onSteamLinkRequested = { [weak self, weak libraryViewController] url in
            let presenter = libraryViewController ?? self?.navigationController.topViewController ?? self?.navigationController
            self?.showSteamLink(url: url, presenter: presenter)
        }
        libraryViewController.onSteamPrivacyGuideRequested = { [weak self, weak libraryViewController] url in
            let presenter = libraryViewController ?? self?.navigationController.topViewController ?? self?.navigationController
            self?.showSteamPrivacyGuidance(
                url: url,
                presenter: presenter,
                retryHandler: { [weak libraryViewController] in
                    libraryViewController?.retrySteamPrivacyGuidance()
                }
            )
        }
        libraryViewController.onSectionListRequested = { [weak self] route in
            self?.showLibrarySectionList(route)
        }
        navigationController.pushViewController(libraryViewController, animated: true)
    }

    private func showLibrarySectionList(_ route: LibrarySectionListRoute) {
        let listViewController = LibrarySectionListViewController(route: route)
        listViewController.onGameSelected = { [weak self] gameID in
            self?.showDetail(gameId: gameID)
        }
        listViewController.onSteamDetailRequested = { [weak self] viewState in
            self?.showSteamDetail(viewState: viewState)
        }
        navigationController.pushViewController(listViewController, animated: true)
    }

    private func showSteamDetail(viewState: SteamFallbackGameDetailViewState) {
        let viewController = SteamFallbackGameDetailViewController(viewState: viewState)
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showEditProfile() {
        guard let authenticatedUser = userSessionStore.fetchUser() else { return }

        let profileEditViewModel = ProfileEditViewModel(
            authenticatedUser: authenticatedUser,
            updateCurrentUserProfileUseCase: updateCurrentUserProfileUseCase,
            uploadCurrentUserProfileImageUseCase: uploadCurrentUserProfileImageUseCase,
            removeCurrentUserProfileImageUseCase: removeCurrentUserProfileImageUseCase
        )
        let profileEditViewController = ProfileEditViewController(
            rootView: ProfileEditRootView(),
            viewModel: profileEditViewModel
        )
        profileEditViewController.onCompleted = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        navigationController.pushViewController(profileEditViewController, animated: true)
    }

    private func showWebPage(url: URL) {
        let safariViewController = SFSafariViewController(url: url)
        safariViewController.preferredControlTintColor = .gpPrimary
        navigationController.topViewController?.present(safariViewController, animated: true)
    }

    private func showSteamPrivacyGuidance(
        url: URL,
        presenter: UIViewController?,
        retryHandler: @escaping () -> Void
    ) {
        guard let presenter else { return }

        let guidanceViewController = SteamPrivacyGuidanceViewController()
        let modalNavigationController = UINavigationController(rootViewController: guidanceViewController)
        modalNavigationController.modalPresentationStyle = .pageSheet
        NavigationBarStyler.configureGlobalAppearance(on: modalNavigationController.navigationBar)

        if let sheetPresentationController = modalNavigationController.sheetPresentationController {
            sheetPresentationController.detents = [.medium(), .large()]
            sheetPresentationController.prefersGrabberVisible = true
        }

        guidanceViewController.onShowInstructions = { [weak self, weak modalNavigationController] in
            guard let modalNavigationController else { return }
            self?.showSteamPrivacyInstructions(url: url, navigationController: modalNavigationController)
        }
        guidanceViewController.onRetry = { [weak modalNavigationController] in
            modalNavigationController?.dismiss(animated: true) {
                retryHandler()
            }
        }

        presenter.present(modalNavigationController, animated: true)
    }

    private func showSteamPrivacyInstructions(url: URL, navigationController: UINavigationController) {
        let instructionsViewController = SteamPrivacyInstructionsViewController()
        instructionsViewController.onOpenSteamSettings = { [weak instructionsViewController] in
            let presenter = instructionsViewController ?? navigationController.topViewController
            guard let presenter else { return }
            let safariViewController = SFSafariViewController(url: url)
            safariViewController.preferredControlTintColor = .gpPrimary
            presenter.present(safariViewController, animated: true)
        }
        navigationController.pushViewController(instructionsViewController, animated: true)
    }

    private func contactSupport() {
        guard let mailURL = URL(string: "mailto:\(AppConfig.supportEmail)") else { return }
        guard UIApplication.shared.canOpenURL(mailURL) else {
            let alertController = UIAlertController(
                title: "메일을 열 수 없어요",
                message: "Mail 앱을 사용할 수 있는 환경에서 다시 시도해 주세요.",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "확인", style: .default))
            navigationController.topViewController?.present(alertController, animated: true)
            return
        }

        UIApplication.shared.open(mailURL)
    }

    private func showSteamLink(url: URL, presenter: UIViewController?) {
        guard let presenter else { return }
        steamLinkFlowController.start(url: url, presenter: presenter)
    }
}
