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
            title: L10n.Profile.Tab.title,
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
        profileVC.onShowEditProfile = { [weak self] selectedTitleKey in
            self?.showEditProfile(selectedTitleKey: selectedTitleKey)
        }
        profileVC.onShowSettings = { [weak self, weak profileVC] in
            guard let self, let profileVC else { return }
            self.showSettings(profileViewController: profileVC)
        }
        profileVC.onShowPlayedGames = { [weak self] in
            print("[Profile] coordinator push playedGames")
            self?.showLibrary(tab: .playing)
        }
        profileVC.onShowRecentPlayList = { [weak self] games, translatedTitles in
            self?.showRecentPlayList(games: games, translatedTitles: translatedTitles)
        }
        profileVC.onShowFavoriteGames = { [weak self] in
            self?.showLibrary(tab: .favorites)
        }
        profileVC.onShowWrittenReviews = { [weak self] in
            self?.showLibrary(tab: .reviewed)
        }
        profileVC.onShowFriendsList = { [weak self] in
            self?.showFriendsList()
        }
        profileVC.onShowSteamFriends = { [weak self] in
            self?.showSteamFriends()
        }
        profileVC.onShowFriendRequests = { [weak self] in
            self?.showFriendRequests()
        }
        profileVC.onShowFriendSearch = { [weak self] in
            self?.showFriendSearch()
        }
        profileVC.onShowFriendActivity = { [weak self] in
            self?.showFriendActivity()
        }
        profileVC.onShowMyComments = { [weak self] in
            self?.showMyComments()
        }
        profileVC.onShowSocialPrivacySettings = { [weak self] in
            self?.showSocialPrivacySettings()
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

    func navigateToFriendProfile(userID: String) {
        showFriendProfile(userID: userID)
    }

    func navigateToFriendActivityFeed() {
        showFriendActivity()
    }

    func navigateToFriendRequests() {
        showFriendRequests()
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
            let items: [Any] = [L10n.tr("Localizable", "common.share.gameInvitation", game.displayTitle)]
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
        reviewsViewController.onReviewSelected = { [weak self] review in
            self?.showReviewDiscussion(
                gameId: game.id,
                gameTitle: game.displayTitle,
                reviewID: review.id,
                reviewSeed: review,
                highlightCommentID: nil
            )
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

    private func showFriendsList() {
        let viewController = FriendsListViewController()
        viewController.onFriendSelected = { [weak self] userID in
            self?.showFriendProfile(userID: userID)
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showMyComments() {
        let viewController = ProfileCommentsViewController(
            rootView: ProfileCommentsRootView(),
            viewModel: ProfileCommentsViewModel()
        )
        viewController.onCommentSelected = { [weak self] item in
            self?.showReviewDiscussion(
                gameId: item.gameId,
                gameTitle: item.gameTitle,
                reviewID: item.reviewId,
                reviewSeed: nil,
                highlightCommentID: item.id
            )
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showSteamFriends() {
        let viewController = SteamFriendsViewController()
        viewController.onLinkedFriendSelected = { [weak self] userID in
            self?.showFriendProfile(userID: userID)
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showFriendRequests() {
        let viewController = FriendRequestsViewController()
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showFriendSearch() {
        let viewController = FriendSearchViewController()
        viewController.onFriendSelected = { [weak self] userID in
            self?.showFriendProfile(userID: userID)
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showFriendProfile(userID: String) {
        let viewController = FriendProfileViewController(userID: userID)
        viewController.onGameSelected = { [weak self] gameID in
            self?.showDetail(gameId: gameID)
        }
        viewController.onReviewGameSelected = { [weak self] gameID in
            self?.showDetail(gameId: gameID)
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showFriendActivity() {
        let viewController = FriendActivityFeedViewController()
        viewController.onRoute = { [weak self] route in
            self?.handleSocialActivityRoute(route)
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showRecentPlayList(games: [RecentGame], translatedTitles: [Int: String]) {
        print("[Profile] coordinator push recentPlayList count=\(games.count)")
        let viewController = ProfileRecentPlayListViewController(
            games: games,
            translatedTitles: translatedTitles
        )
        viewController.onGameSelected = { [weak self] gameID in
            self?.showDetail(gameId: gameID)
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showSocialPrivacySettings() {
        let viewController = SocialPrivacySettingsViewController()
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showSettings(profileViewController: ProfileViewController) {
        let viewController = ProfileSettingsViewController()
        viewController.onShowSocialPrivacySettings = { [weak self] in
            self?.showSocialPrivacySettings()
        }
        viewController.onLogoutConfirmed = { [weak profileViewController] in
            profileViewController?.performLogoutFromSettings()
        }
        viewController.onDeleteAccountConfirmed = { [weak profileViewController] in
            profileViewController?.performDeleteAccountFromSettings()
        }
        viewController.onShowTermsOfService = { [weak self] in
            self?.showWebPage(url: AppConfig.termsOfServiceURL)
        }
        viewController.onShowPrivacyPolicy = { [weak self] in
            self?.showWebPage(url: AppConfig.privacyPolicyURL)
        }
        viewController.onShowCommunityGuidelines = { [weak self] in
            self?.showWebPage(url: AppConfig.communityGuidelinesURL)
        }
        viewController.onContactSupport = { [weak self] in
            self?.contactSupport()
        }
        viewController.onShowNotificationSettings = { [weak self] in
            self?.showNotificationSettings()
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showSteamDetail(viewState: SteamFallbackGameDetailViewState) {
        let viewController = SteamFallbackGameDetailViewController(viewState: viewState)
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showEditProfile(selectedTitleKey: String?) {
        guard let authenticatedUser = userSessionStore.fetchUser() else { return }

        let profileEditViewModel = ProfileEditViewModel(
            authenticatedUser: authenticatedUser,
            initialSelectedTitleKey: selectedTitleKey,
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
                title: L10n.Common.Error.title,
                message: L10n.Common.Error.tryAgain,
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: L10n.tr("Localizable", "common.button.ok"), style: .default))
            navigationController.topViewController?.present(alertController, animated: true)
            return
        }

        UIApplication.shared.open(mailURL)
    }

    private func showNotificationSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

    private func handleSocialActivityRoute(_ route: SocialActivityRoute) {
        switch route {
        case .friendActivityFeed:
            showFriendActivity()
        case .friendRequests:
            showFriendRequests()
        case .friendProfile(let userID):
            showFriendProfile(userID: userID)
        case .gameDetail(let gameID):
            showDetail(gameId: gameID)
        case .review(let gameID, let reviewID, let commentID):
            guard let reviewID else {
                showDetail(gameId: gameID)
                return
            }
            showReviewDiscussion(
                gameId: gameID,
                gameTitle: nil,
                reviewID: reviewID,
                reviewSeed: nil,
                highlightCommentID: commentID
            )
        }
    }

    private func showReviewDiscussion(
        gameId: Int,
        gameTitle: String?,
        reviewID: String,
        reviewSeed: Review?,
        highlightCommentID: String?
    ) {
        let viewController = ReviewDiscussionViewController(
            rootView: ReviewDiscussionRootView(),
            viewModel: ReviewDiscussionViewModel(
                gameId: gameId,
                gameTitle: gameTitle,
                reviewId: reviewID,
                reviewSeed: reviewSeed,
                highlightCommentId: highlightCommentID
            )
        )
        viewController.onAuthenticationRequired = { [weak self, weak viewController] context, action in
            guard let self else { return }
            let presenter = viewController ?? self.navigationController.topViewController ?? self.navigationController
            self.onAuthenticationRequested?(presenter, context, action)
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showSteamLink(url: URL, presenter: UIViewController?) {
        guard let presenter else { return }
        steamLinkFlowController.start(url: url, presenter: presenter)
    }
}
