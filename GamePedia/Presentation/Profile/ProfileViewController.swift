import UIKit

// MARK: - ProfileViewController

final class ProfileViewController: BaseViewController<ProfileRootView, ProfileState> {

    // MARK: Properties
    private let viewModel: ProfileViewModel
    private var recentGames: [RecentGame] = []
    private var lastPresentedErrorMessage: String?
    private var lastPresentedSuccessMessage: String?
    private var toastHideWorkItem: DispatchWorkItem?
    private weak var toastView: ProfileToastView?

    // Set by ProfileCoordinator.
    var onGameSelected: ((Int) -> Void)?
    var onLoggedOut: (() -> Void)?
    var onShowEditProfile: (() -> Void)?
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
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "편집",
                style: .plain,
                target: self,
                action: #selector(didTapEditProfile)
            )
        }
    }

    private func setupTableView() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.logoutButton.addTarget(self, action: #selector(didTapLogout), for: .touchUpInside)
        rootView.deleteAccountButton.addTarget(self, action: #selector(didTapDeleteAccount), for: .touchUpInside)
        rootView.steamUnlinkButton.addTarget(self, action: #selector(didTapSteamUnlink), for: .touchUpInside)
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
            case .showEditProfile:
                self?.onShowEditProfile?()
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

        if let successMessage = state.successMessage,
           successMessage != lastPresentedSuccessMessage {
            lastPresentedSuccessMessage = successMessage
            showToast(message: successMessage)
            viewModel.send(.didConsumeSuccessMessage)
        } else if state.successMessage == nil {
            lastPresentedSuccessMessage = nil
        }
    }

    // MARK: Actions

    @objc private func didTapSeeMoreRecentPlay() {
        viewModel.send(.didTapSeeMoreRecentPlay)
        // TODO: navigate to full recent play list
    }

    @objc private func didTapEditProfile() {
        viewModel.send(.didTapEditProfile)
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

    @objc private func didTapSteamUnlink() {
        let alertController = UIAlertController(
            title: "Steam 연동을 해제할까요?",
            message: "연동을 해제하면 Steam에서 가져온 최근 플레이 및 보유 게임 연결 정보가 더 이상 동기화되지 않아요.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        alertController.addAction(
            UIAlertAction(title: "연동 해제", style: .destructive) { [weak self] _ in
                self?.viewModel.send(.didTapSteamUnlink)
            }
        )
        present(alertController, animated: true)
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "오류", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    private func showToast(message: String) {
        toastHideWorkItem?.cancel()
        toastView?.removeFromSuperview()

        let toastView = ProfileToastView(message: message)
        toastView.translatesAutoresizingMaskIntoConstraints = false
        toastView.alpha = 0
        view.addSubview(toastView)
        self.toastView = toastView

        NSLayoutConstraint.activate([
            toastView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toastView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            toastView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])

        UIView.animate(withDuration: 0.2) {
            toastView.alpha = 1
        }

        let hideWorkItem = DispatchWorkItem { [weak toastView] in
            UIView.animate(withDuration: 0.2, animations: {
                toastView?.alpha = 0
            }, completion: { _ in
                toastView?.removeFromSuperview()
            })
        }
        toastHideWorkItem = hideWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: hideWorkItem)
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

private final class ProfileToastView: UIView {
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(message: String) {
        super.init(frame: .zero)
        messageLabel.text = message
        backgroundColor = UIColor.gpSurface.withAlphaComponent(0.96)
        layer.cornerRadius = 14
        layer.masksToBounds = true

        addSubview(messageLabel)
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
