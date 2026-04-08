import UIKit

// MARK: - HomeCoordinator
//
// Appearance is applied to each view controller's navigationItem
// BEFORE push/setViewControllers is called. UIKit reads navigationItem
// appearances when building the transition, so the correct style is
// present from the first animation frame — no snap or flash.
//
// willShow is not used: per-VC navigationItem.standardAppearance persists
// on the VC throughout its lifetime, so UIKit restores it automatically
// on pop (including cancelled interactive swipe-back gestures).

final class HomeCoordinator {

    // MARK: Properties

    let navigationController: UINavigationController
    var onAuthenticationRequested: ((UIViewController, RestrictedActionContext, @escaping () -> Void) -> Void)?

    // MARK: Init

    init() {
        navigationController = UINavigationController()
        navigationController.tabBarItem = UITabBarItem(
            title: L10n.Home.Tab.title,
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )
        NavigationBarStyler.configureGlobalAppearance(on: navigationController.navigationBar)
    }

    // MARK: Start

    func start() {
        let homeVC = HomeViewController(rootView: HomeRootView())
        homeVC.onGameSelected = { [weak self] gameId in
            self?.showDetail(gameId: gameId)
        }
        homeVC.onRoute = { [weak self] route in
            self?.handle(route)
        }
        navigationController.setViewControllers([homeVC], animated: false)
    }

    func navigateToGameDetail(gameID: Int) {
        showDetail(gameId: gameID)
    }

    func navigateToReviewDiscussion(gameID: Int, reviewID: String?, commentID: String?) {
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

    func navigateToNotifications() {
        showNotifications()
    }

    func navigateToTrendingGameList(items: [TrendingGamesWidgetSnapshot.Item]) {
        let games = items.map(Self.makeTrendingGame)
        guard games.isEmpty == false else { return }
        showGameList(section: .trending, games: games, wishlistedGameIDs: [])
    }

    func navigateToReviewComposer(item: ReviewPromptWidgetSnapshot.Item) {
        showReviewComposer(
            gameId: item.gameID,
            gameName: item.title,
            gameSubtitle: item.subtitleText.replacingOccurrences(of: "\n", with: " · "),
            gameThumbnailURL: item.coverImageURL?.absoluteString ?? ""
        )
    }

    func navigateToFriendRequests() {
        showFriendRequests()
    }

    func navigateToFriendProfile(userID: String) {
        showFriendProfile(userID: userID)
    }

    // MARK: - Navigation

    private func showDetail(gameId: Int) {
        if reuseGameDetailIfPossible(gameId: gameId) {
            return
        }

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
        detailVC.onReviewSelected = { [weak self] game, review in
            self?.showReviewDiscussion(
                gameId: game.id,
                gameTitle: game.displayTitle,
                reviewID: review.id,
                reviewSeed: review,
                highlightCommentID: nil
            )
        }
        detailVC.onShare = { [weak self] game in
            guard let topVC = self?.navigationController.topViewController else { return }
            let items: [Any] = [L10n.tr("Localizable", "common.share.gameInvitation", game.displayTitle)]
            let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
            topVC.present(activityVC, animated: true)
        }
        navigationController.pushViewController(detailVC, animated: true)
    }

    private func handle(_ route: HomeRoute) {
        switch route {
        case .showGameList(let section, let games, let wishlistedGameIDs):
            showGameList(section: section, games: games, wishlistedGameIDs: wishlistedGameIDs)
        case .showNotifications:
            showNotifications()
        case .presentHomeFilterSheet:
            break
        }
    }

    private func showGameList(
        section: HomeSection,
        games: [Game],
        wishlistedGameIDs: Set<Int>
    ) {
        if reuseGameListIfPossible(section: section) {
            return
        }

        let viewModel = HomeGameListViewModel(
            section: section,
            games: games,
            wishlistedGameIDs: wishlistedGameIDs
        )
        let listViewController = HomeGameListViewController(
            rootView: HomeGameListRootView(),
            viewModel: viewModel
        )
        listViewController.onGameSelected = { [weak self] gameId in
            self?.showDetail(gameId: gameId)
        }
        listViewController.onAuthenticationRequired = { [weak self, weak listViewController] context, action in
            guard let self else { return }
            let presenter = listViewController ?? self.navigationController.topViewController ?? self.navigationController
            self.onAuthenticationRequested?(presenter, context, action)
        }
        navigationController.pushViewController(listViewController, animated: true)
    }

    private func showNotifications() {
        guard APIClient.shared.userAuthToken != nil else {
            let presenter = navigationController.topViewController ?? navigationController
            onAuthenticationRequested?(presenter, .profile) { [weak self] in
                self?.showNotifications()
            }
            return
        }

        let viewController = NotificationsViewController(rootView: NotificationsRootView())
        viewController.onGameSelected = { [weak self] gameID in
            self?.showDetail(gameId: gameID)
        }
        viewController.onFriendRequestsSelected = { [weak self] in
            self?.showFriendRequests()
        }
        viewController.onFriendSelected = { [weak self] userID in
            self?.showFriendProfile(userID: userID)
        }
        viewController.onSocialRoute = { [weak self] route in
            self?.handleSocialActivityRoute(route)
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showFriendRequests() {
        let viewController = FriendRequestsViewController()
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
            navigateToReviewDiscussion(gameID: gameID, reviewID: reviewID, commentID: commentID)
        }
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

    private func showReviewComposer(
        gameId: Int,
        gameName: String,
        gameSubtitle: String,
        gameThumbnailURL: String,
        existingReview: Review? = nil
    ) {
        if reuseReviewComposerIfPossible(gameId: gameId) {
            return
        }

        let reviewVC = ReviewViewController(
            rootView: ReviewRootView(),
            viewModel: ReviewViewModel(
                gameId: gameId,
                gameName: gameName,
                gameSubtitle: gameSubtitle,
                gameThumbnailURL: gameThumbnailURL,
                existingReview: existingReview
            )
        )
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

    private func showReviewDiscussion(
        gameId: Int,
        gameTitle: String?,
        reviewID: String,
        reviewSeed: Review?,
        highlightCommentID: String?,
        initialReplyTargetCommentID: String? = nil,
        autoFocusReplyComposer: Bool = false
    ) {
        let viewController = ReviewDiscussionViewController(
            rootView: ReviewDiscussionRootView(),
            viewModel: ReviewDiscussionViewModel(
                gameId: gameId,
                gameTitle: gameTitle,
                reviewId: reviewID,
                reviewSeed: reviewSeed,
                highlightCommentId: highlightCommentID
            ),
            initialReplyTargetCommentId: initialReplyTargetCommentID,
            autoFocusReplyComposerOnFirstAppearance: autoFocusReplyComposer
        )
        viewController.onAuthenticationRequired = { [weak self, weak viewController] context, action in
            guard let self else { return }
            let presenter = viewController ?? self.navigationController.topViewController ?? self.navigationController
            self.onAuthenticationRequested?(presenter, context, action)
        }
        viewController.onReplyDetailRequested = { [weak self] comment, reviewSeed in
            self?.showReviewDiscussion(
                gameId: comment.gameId,
                gameTitle: comment.gameTitle,
                reviewID: comment.reviewId,
                reviewSeed: reviewSeed,
                highlightCommentID: comment.id,
                initialReplyTargetCommentID: comment.id,
                autoFocusReplyComposer: true
            )
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func reuseGameDetailIfPossible(gameId: Int) -> Bool {
        if let topViewController = navigationController.topViewController as? GameDetailViewController,
           topViewController.gameId == gameId {
            return true
        }

        guard let existingViewController = navigationController.viewControllers.first(where: {
            guard let detailViewController = $0 as? GameDetailViewController else { return false }
            return detailViewController.gameId == gameId
        }) else {
            return false
        }

        navigationController.popToViewController(existingViewController, animated: true)
        return true
    }

    private func reuseGameListIfPossible(section: HomeSection) -> Bool {
        if let topViewController = navigationController.topViewController as? HomeGameListViewController,
           topViewController.section == section {
            return true
        }

        guard let existingViewController = navigationController.viewControllers.first(where: {
            guard let listViewController = $0 as? HomeGameListViewController else { return false }
            return listViewController.section == section
        }) else {
            return false
        }

        navigationController.popToViewController(existingViewController, animated: true)
        return true
    }

    private func reuseReviewComposerIfPossible(gameId: Int) -> Bool {
        if let topViewController = navigationController.topViewController as? ReviewViewController,
           topViewController.gameId == gameId {
            return true
        }

        guard let existingViewController = navigationController.viewControllers.first(where: {
            guard let reviewViewController = $0 as? ReviewViewController else { return false }
            return reviewViewController.gameId == gameId
        }) else {
            return false
        }

        navigationController.popToViewController(existingViewController, animated: true)
        return true
    }

    private static func makeTrendingGame(from item: TrendingGamesWidgetSnapshot.Item) -> Game {
        let rating = Double(item.ratingText ?? "") ?? 0
        return Game(
            id: item.gameID,
            title: item.title,
            translatedTitle: nil,
            summary: nil,
            translatedSummary: nil,
            genre: item.genreText,
            category: item.genreText,
            developer: "",
            platform: "",
            releaseDate: nil,
            releaseYear: 0,
            coverImageURL: item.coverImageURL,
            rating: rating,
            reviewCount: 0,
            popularity: 0,
            isTrending: true,
            formattedRating: item.ratingText ?? "—",
            formattedReviewCount: "0"
        )
    }
}
