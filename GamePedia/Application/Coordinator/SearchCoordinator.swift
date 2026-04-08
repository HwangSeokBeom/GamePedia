import UIKit

// MARK: - SearchCoordinator

final class SearchCoordinator {

    // MARK: Properties

    let navigationController: UINavigationController
    var onAuthenticationRequested: ((UIViewController, RestrictedActionContext, @escaping () -> Void) -> Void)?

    // MARK: Init

    init() {
        navigationController = UINavigationController()
        navigationController.tabBarItem = UITabBarItem(
            title: L10n.Search.Tab.title,
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
}
