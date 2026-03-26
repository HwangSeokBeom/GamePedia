import UIKit

// MARK: - ProfileViewController

final class ProfileViewController: BaseViewController<ProfileRootView, ProfileState> {

    // MARK: Properties
    private let viewModel: ProfileViewModel
    private var recentGames: [RecentGame] = []
    private var lastPresentedErrorMessage: String?

    // Set by ProfileCoordinator.
    var onGameSelected: ((Int) -> Void)?
    var onLoggedOut: (() -> Void)?
    var onShowFavoriteGames: (() -> Void)?
    var onShowWrittenReviews: (() -> Void)?
    var onShowTermsOfService: (() -> Void)?
    var onShowPrivacyPolicy: (() -> Void)?
    var onShowCommunityGuidelines: (() -> Void)?
    var onContactSupport: (() -> Void)?

    // MARK: Init
    init(
        rootView: ProfileRootView,
        viewModel: ProfileViewModel
    ) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        configureNavigationItem()
    }

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        bindViewModel()
        viewModel.send(.viewDidLoad)
    }

    // MARK: Setup

    private func configureNavigationItem() {
        UIView.performWithoutAnimation {
            navigationItem.title = "프로필"
            navigationItem.largeTitleDisplayMode = .never
            navigationItem.rightBarButtonItem = nil
        }
    }

    private func setupTableView() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.logoutButton.addTarget(self, action: #selector(didTapLogout), for: .touchUpInside)
        rootView.deleteAccountButton.addTarget(self, action: #selector(didTapDeleteAccount), for: .touchUpInside)
        rootView.sectionHeader.seeMoreButton.addTarget(
            self, action: #selector(didTapSeeMoreRecentPlay), for: .touchUpInside
        )
        rootView.termsOfServiceButton.addTarget(self, action: #selector(didTapTermsOfService), for: .touchUpInside)
        rootView.privacyPolicyButton.addTarget(self, action: #selector(didTapPrivacyPolicy), for: .touchUpInside)
        rootView.communityGuidelinesButton.addTarget(self, action: #selector(didTapCommunityGuidelines), for: .touchUpInside)
        rootView.contactSupportButton.addTarget(self, action: #selector(didTapContactSupport), for: .touchUpInside)
        let reviewTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapWrittenReviews))
        let favoriteTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapFavoriteGames))
        rootView.reviewStatView.addGestureRecognizer(reviewTapGestureRecognizer)
        rootView.wishlistStatView.addGestureRecognizer(favoriteTapGestureRecognizer)
        rootView.reviewStatView.accessibilityTraits.insert(.button)
        rootView.wishlistStatView.accessibilityTraits.insert(.button)
        rootView.reviewStatView.accessibilityLabel = "작성한 리뷰"
        rootView.wishlistStatView.accessibilityLabel = "찜한 게임"
    }

    // MARK: ViewModel Binding

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async { self?.render(state) }
        }

        viewModel.onRoute = { [weak self] route in
            switch route {
            case .loggedOut:
                self?.onLoggedOut?()
            case .showWrittenReviews:
                self?.onShowWrittenReviews?()
            case .showFavoriteGames:
                self?.onShowFavoriteGames?()
            case .showTermsOfService:
                self?.onShowTermsOfService?()
            case .showPrivacyPolicy:
                self?.onShowPrivacyPolicy?()
            case .showCommunityGuidelines:
                self?.onShowCommunityGuidelines?()
            case .contactSupport:
                self?.onContactSupport?()
            }
        }
    }

    override func render(_ state: ProfileState) {
        rootView.render(state)

        recentGames = state.recentGames
        rootView.tableView.reloadData()

        if let errorMessage = state.errorMessage,
           errorMessage != lastPresentedErrorMessage {
            lastPresentedErrorMessage = errorMessage
            showErrorAlert(message: errorMessage)
        } else if state.errorMessage == nil {
            lastPresentedErrorMessage = nil
        }
    }

    // MARK: Actions

    @objc private func didTapSeeMoreRecentPlay() {
        viewModel.send(.didTapSeeMoreRecentPlay)
        // TODO: navigate to full recent play list
    }

    @objc private func didTapWrittenReviews() {
        viewModel.send(.didTapWrittenReviews)
    }

    @objc private func didTapFavoriteGames() {
        viewModel.send(.didTapFavoriteGames)
    }

    @objc private func didTapTermsOfService() {
        viewModel.send(.didTapTermsOfService)
    }

    @objc private func didTapPrivacyPolicy() {
        viewModel.send(.didTapPrivacyPolicy)
    }

    @objc private func didTapCommunityGuidelines() {
        viewModel.send(.didTapCommunityGuidelines)
    }

    @objc private func didTapContactSupport() {
        viewModel.send(.didTapContactSupport)
    }

    @objc private func didTapLogout() {
        let alertController = UIAlertController(
            title: "로그아웃",
            message: "현재 기기에서 로그인 상태가 해제됩니다.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        alertController.addAction(
            UIAlertAction(title: "로그아웃", style: .destructive) { [weak self] _ in
                self?.viewModel.send(.didTapLogout)
            }
        )
        present(alertController, animated: true)
    }

    @objc private func didTapDeleteAccount() {
        let alertController = UIAlertController(
            title: "회원 탈퇴",
            message: "회원 탈퇴 시 계정과 프로필 정보가 삭제되며 복구할 수 없습니다. 법령상 보관이 필요한 정보는 관련 법령에 따라 별도 보관될 수 있습니다.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        alertController.addAction(
            UIAlertAction(title: "회원 탈퇴", style: .destructive) { [weak self] _ in
                self?.viewModel.send(.didTapDeleteAccount)
            }
        )
        present(alertController, animated: true)
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "오류", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension ProfileViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        recentGames.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: RecentPlayCell.reuseId, for: indexPath
        ) as! RecentPlayCell
        let game = recentGames[indexPath.row]
        let resolvedTitle = viewModel.state.resolvedTitle(for: game)
        cell.configure(with: game, resolvedTitle: resolvedTitle)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let game = recentGames[indexPath.row]
        viewModel.send(.didTapGame(id: game.gameId))
        onGameSelected?(game.gameId)
    }
}
