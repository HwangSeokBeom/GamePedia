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
            title: "홈",
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
}
