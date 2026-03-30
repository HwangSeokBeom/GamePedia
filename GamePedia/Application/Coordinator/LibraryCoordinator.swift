import SafariServices
import UIKit

// MARK: - LibraryCoordinator

final class LibraryCoordinator {

    // MARK: Properties

    let navigationController: UINavigationController
    var onAuthenticationRequested: ((UIViewController, RestrictedActionContext, @escaping () -> Void) -> Void)?
    private let steamLinkFlowController: any SteamLinkFlowControlling

    // MARK: Init

    init(steamLinkFlowController: any SteamLinkFlowControlling) {
        self.steamLinkFlowController = steamLinkFlowController
        navigationController = UINavigationController()
        navigationController.tabBarItem = UITabBarItem(
            title: "라이브러리",
            image: UIImage(systemName: "books.vertical"),
            selectedImage: UIImage(systemName: "books.vertical.fill")
        )
        NavigationBarStyler.configureGlobalAppearance(on: navigationController.navigationBar)
    }

    // MARK: Start

    func start() {
        let libraryVC = LibraryViewController()
        libraryVC.onGameSelected = { [weak self] gameId in
            self?.showDetail(gameId: gameId)
        }
        libraryVC.onSteamDetailRequested = { [weak self] viewState in
            self?.showSteamDetail(viewState: viewState)
        }
        libraryVC.onSteamLinkRequested = { [weak self, weak libraryVC] url in
            let presenter = libraryVC ?? self?.navigationController.topViewController ?? self?.navigationController
            self?.showSteamLink(url: url, presenter: presenter)
        }
        libraryVC.onSteamPrivacyGuideRequested = { [weak self, weak libraryVC] url in
            let presenter = libraryVC ?? self?.navigationController.topViewController ?? self?.navigationController
            self?.showSteamPrivacyGuidance(
                url: url,
                presenter: presenter,
                retryHandler: { [weak libraryVC] in
                    libraryVC?.retrySteamPrivacyGuidance()
                }
            )
        }
        libraryVC.onSectionListRequested = { [weak self] route in
            self?.showSectionList(route)
        }
        navigationController.setViewControllers([libraryVC], animated: false)
    }

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

    private func showSectionList(_ route: LibrarySectionListRoute) {
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

    private func showSteamLink(url: URL, presenter: UIViewController?) {
        guard let presenter else { return }
        steamLinkFlowController.start(url: url, presenter: presenter)
    }

    private func showSteamPrivacyGuidance(
        url: URL,
        presenter: UIViewController?,
        retryHandler: @escaping () -> Void
    ) {
        guard let presenter else { return }

        let guidanceViewController = SteamPrivacyGuidanceViewController()
        let navigationController = UINavigationController(rootViewController: guidanceViewController)
        navigationController.modalPresentationStyle = .pageSheet
        NavigationBarStyler.configureGlobalAppearance(on: navigationController.navigationBar)

        if let sheetPresentationController = navigationController.sheetPresentationController {
            sheetPresentationController.detents = [.medium(), .large()]
            sheetPresentationController.prefersGrabberVisible = true
        }

        guidanceViewController.onShowInstructions = { [weak self, weak navigationController] in
            guard let navigationController else { return }
            self?.showSteamPrivacyInstructions(url: url, navigationController: navigationController)
        }
        guidanceViewController.onRetry = { [weak navigationController] in
            navigationController?.dismiss(animated: true) {
                retryHandler()
            }
        }

        presenter.present(navigationController, animated: true)
    }

    private func showSteamPrivacyInstructions(url: URL, navigationController: UINavigationController) {
        let instructionsViewController = SteamPrivacyInstructionsViewController()
        instructionsViewController.onOpenSteamSettings = { [weak self, weak instructionsViewController] in
            let presenter = instructionsViewController ?? navigationController.topViewController
            self?.showWebPage(url: url, presenter: presenter)
        }
        navigationController.pushViewController(instructionsViewController, animated: true)
    }

    private func showWebPage(url: URL, presenter: UIViewController?) {
        guard let presenter else { return }
        let safariViewController = SFSafariViewController(url: url)
        safariViewController.preferredControlTintColor = .gpPrimary
        presenter.present(safariViewController, animated: true)
    }
}
