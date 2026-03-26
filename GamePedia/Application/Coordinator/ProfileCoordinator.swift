import UIKit

// MARK: - ProfileCoordinator

final class ProfileCoordinator {

    // MARK: Properties

    let navigationController: UINavigationController
    private let fetchCurrentUserUseCase: FetchCurrentUserUseCase
    private let logoutUseCase: LogoutUseCase
    private let deleteAccountUseCase: DeleteAccountUseCase
    private let userSessionStore: any UserSessionStore

    var onLoggedOut: (() -> Void)?

    // MARK: Init

    init(
        fetchCurrentUserUseCase: FetchCurrentUserUseCase,
        logoutUseCase: LogoutUseCase,
        deleteAccountUseCase: DeleteAccountUseCase,
        userSessionStore: any UserSessionStore
    ) {
        self.fetchCurrentUserUseCase = fetchCurrentUserUseCase
        self.logoutUseCase = logoutUseCase
        self.deleteAccountUseCase = deleteAccountUseCase
        self.userSessionStore = userSessionStore
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
        navigationController.setViewControllers([profileVC], animated: false)
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
