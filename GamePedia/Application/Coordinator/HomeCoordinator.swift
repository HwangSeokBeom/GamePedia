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
        detailVC.onWriteReview = { [weak self] game in
            self?.showReview(game: game)
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

    private func showReview(game: GameDetail) {
        guard let detailVC = navigationController.topViewController as? GameDetailViewController else { return }
        let reviewVC = ReviewViewController(
            rootView: ReviewRootView(),
            viewModel: ReviewViewModel(
                gameId: game.id,
                gameName: game.displayTitle,
                gameSubtitle: game.developerLine,
                gameThumbnailURL: game.coverImageURL?.absoluteString ?? ""
            )
        )
        reviewVC.onReviewSubmitted = { [weak detailVC] in
            detailVC?.reload()
        }
        navigationController.pushViewController(reviewVC, animated: true)
    }
}
