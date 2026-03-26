import UIKit

// MARK: - SearchCoordinator

final class SearchCoordinator {

    // MARK: Properties

    let navigationController: UINavigationController

    // MARK: Init

    init() {
        navigationController = UINavigationController()
        navigationController.tabBarItem = UITabBarItem(
            title: "검색",
            image: UIImage(systemName: "magnifyingglass"),
            selectedImage: UIImage(systemName: "magnifyingglass")
        )
        NavigationBarStyler.configureGlobalAppearance(on: navigationController.navigationBar)
    }

    // MARK: Start

    func start() {
        let searchVC = SearchViewController(rootView: SearchRootView())
        searchVC.onGameSelected = { [weak self] gameId in
            self?.showDetail(gameId: gameId)
        }
        navigationController.setViewControllers([searchVC], animated: false)
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
