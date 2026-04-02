import UIKit

// MARK: - ProfileViewController

final class ProfileViewController: BaseViewController<ProfileRootView, ProfileState> {

    // MARK: Properties
    private let viewModel: ProfileViewModel
    private var recentlyPlayedGames: [RecentGame] = []
    private var lastPresentedErrorMessage: String?
    private var lastPresentedSuccessMessage: String?
    private var toastHideWorkItem: DispatchWorkItem?
    private weak var toastView: ProfileToastView?

    // Set by ProfileCoordinator.
    var onGameSelected: ((Int) -> Void)?
    var onLoggedOut: (() -> Void)?
    var onShowEditProfile: ((String?) -> Void)?
    var onShowSettings: (() -> Void)?
    var onShowPlayedGames: (() -> Void)?
    var onShowRecentPlayList: (([RecentGame], [Int: String]) -> Void)?
    var onShowFavoriteGames: (() -> Void)?
    var onShowWrittenReviews: (() -> Void)?
    var onShowFriendsList: (() -> Void)?
    var onShowSteamFriends: (() -> Void)?
    var onShowFriendRequests: (() -> Void)?
    var onShowFriendSearch: (() -> Void)?
    var onShowFriendActivity: (() -> Void)?
    var onShowSocialPrivacySettings: (() -> Void)?
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
            navigationItem.title = L10n.Profile.Navigation.title
            navigationItem.largeTitleDisplayMode = .never
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "gearshape.fill"),
                style: .plain,
                target: self,
                action: #selector(didTapSettings)
            )
        }
    }

    private func setupTableView() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.headerCardView.editProfileButton.addTarget(self, action: #selector(didTapEditProfile), for: .touchUpInside)
        rootView.logoutButton.addTarget(self, action: #selector(didTapLogout), for: .touchUpInside)
        rootView.deleteAccountButton.addTarget(self, action: #selector(didTapDeleteAccount), for: .touchUpInside)
        rootView.steamUnlinkButton.addTarget(self, action: #selector(didTapSteamUnlink), for: .touchUpInside)
        rootView.friendsListButton.addTarget(self, action: #selector(didTapFriendsList), for: .touchUpInside)
        rootView.friendActivityButton.addTarget(self, action: #selector(didTapFriendActivity), for: .touchUpInside)
        rootView.sectionHeader.seeMoreButton.addTarget(
            self, action: #selector(didTapSeeMoreRecentPlay), for: .touchUpInside
        )
        let reviewTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapWrittenReviews))
        let favoriteTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapFavoriteGames))
        rootView.reviewStatView.addGestureRecognizer(reviewTapGestureRecognizer)
        rootView.wishlistStatView.addGestureRecognizer(favoriteTapGestureRecognizer)
        let playedTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapPlayedGames))
        rootView.playedStatView.addGestureRecognizer(playedTapGestureRecognizer)
        rootView.playedStatView.accessibilityTraits.insert(.button)
        rootView.reviewStatView.accessibilityTraits.insert(.button)
        rootView.wishlistStatView.accessibilityTraits.insert(.button)
        rootView.playedStatView.accessibilityLabel = L10n.Profile.Stat.playedGames
        rootView.reviewStatView.accessibilityLabel = L10n.Profile.Stat.writtenReviews
        rootView.wishlistStatView.accessibilityLabel = L10n.Profile.Stat.wishlistedGames
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
                self?.onShowEditProfile?(self?.viewModel.state.selectedTitleKey)
            case .showSettings:
                self?.onShowSettings?()
            case .showPlayedGames:
                print("[Profile] route handled route=showPlayedGames")
                self?.onShowPlayedGames?()
            case .showRecentPlayList:
                guard let self else { return }
                print("[Profile] route handled route=showRecentPlayList count=\(self.recentlyPlayedGames.count)")
                self.onShowRecentPlayList?(self.recentlyPlayedGames, self.viewModel.state.translatedRecentGameTitles)
            case .showWrittenReviews:
                self?.onShowWrittenReviews?()
            case .showFavoriteGames:
                self?.onShowFavoriteGames?()
            case .showFriendsList:
                self?.onShowFriendsList?()
            case .showSteamFriends:
                self?.onShowSteamFriends?()
            case .showFriendRequests:
                self?.onShowFriendRequests?()
            case .showFriendSearch:
                self?.onShowFriendSearch?()
            case .showFriendActivity:
                self?.onShowFriendActivity?()
            case .showSocialPrivacySettings:
                self?.onShowSocialPrivacySettings?()
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
        print(
            "[Profile] render " +
            "selectedTitle=\(state.selectedTitle ?? "nil") " +
            "selectedTitleKey=\(state.selectedTitleKey ?? "nil") " +
            "selectedTitles=\(state.selectedTitles) " +
            "recentPlayCount=\(state.recentlyPlayedGames.count) " +
            "recentPlayState=\(String(describing: state.recentPlayLoadState))"
        )
        GameDetailSeedStore.shared.store(recentGames: state.recentlyPlayedGames, screen: "Profile.render")
        rootView.render(state)

        recentlyPlayedGames = state.recentlyPlayedGames
        print("[Profile] recent-play render input count=\(recentlyPlayedGames.count)")
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
        print("[Profile] recentPlay seeMore tapped")
        viewModel.send(.didTapSeeMoreRecentPlay)
    }

    @objc private func didTapPlayedGames() {
        print("[Profile] playedStat tapped")
        UIView.animate(withDuration: 0.12, animations: {
            self.rootView.playedStatView.alpha = 0.72
        }, completion: { _ in
            UIView.animate(withDuration: 0.12) {
                self.rootView.playedStatView.alpha = 1.0
            }
        })
        print("[Profile] playedStat intent sent")
        viewModel.send(.didTapPlayedGamesStat)
    }

    @objc private func didTapSettings() {
        viewModel.send(.didTapSettings)
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

    @objc private func didTapFriendsList() {
        let alertController = UIAlertController(title: L10n.Profile.Social.friendManagement, message: nil, preferredStyle: .actionSheet)
        alertController.addAction(
            UIAlertAction(title: L10n.Profile.Action.friendsList, style: .default) { [weak self] _ in
                self?.viewModel.send(.didTapFriendsList)
            }
        )
        alertController.addAction(
            UIAlertAction(title: L10n.Profile.Action.steamFriends, style: .default) { [weak self] _ in
                self?.viewModel.send(.didTapSteamFriends)
            }
        )
        alertController.addAction(
            UIAlertAction(title: L10n.Profile.Action.friendRequests, style: .default) { [weak self] _ in
                self?.viewModel.send(.didTapFriendRequests)
            }
        )
        alertController.addAction(
            UIAlertAction(title: L10n.Profile.Action.findFriends, style: .default) { [weak self] _ in
                self?.viewModel.send(.didTapFriendSearch)
            }
        )
        alertController.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))

        if let popoverPresentationController = alertController.popoverPresentationController {
            popoverPresentationController.sourceView = rootView
            popoverPresentationController.sourceRect = CGRect(
                x: rootView.bounds.midX,
                y: rootView.bounds.midY,
                width: 1,
                height: 1
            )
        }

        present(alertController, animated: true)
    }

    @objc private func didTapSteamFriends() {
        viewModel.send(.didTapSteamFriends)
    }

    @objc private func didTapFriendRequests() {
        viewModel.send(.didTapFriendRequests)
    }

    @objc private func didTapFriendSearch() {
        viewModel.send(.didTapFriendSearch)
    }

    @objc private func didTapFriendActivity() {
        viewModel.send(.didTapFriendActivity)
    }

    @objc private func didTapSocialPrivacySettings() {
        viewModel.send(.didTapSocialPrivacySettings)
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
            title: L10n.Profile.Action.logout,
            message: L10n.Profile.Settings.logoutMessage,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        alertController.addAction(
            UIAlertAction(title: L10n.Profile.Action.logout, style: .destructive) { [weak self] _ in
                self?.viewModel.send(.didTapLogout)
            }
        )
        present(alertController, animated: true)
    }

    @objc private func didTapDeleteAccount() {
        let alertController = UIAlertController(
            title: L10n.Profile.Action.deleteAccount,
            message: L10n.Profile.Settings.deleteMessage,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        alertController.addAction(
            UIAlertAction(title: L10n.Profile.Action.deleteAccount, style: .destructive) { [weak self] _ in
                self?.viewModel.send(.didTapDeleteAccount)
            }
        )
        present(alertController, animated: true)
    }

    @objc private func didTapSteamUnlink() {
        let alertController = UIAlertController(
            title: L10n.Profile.Alert.steamUnlinkTitle,
            message: L10n.Profile.Alert.steamUnlinkMessage,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        alertController.addAction(
            UIAlertAction(title: L10n.Profile.Action.unlinkSteam, style: .destructive) { [weak self] _ in
                self?.viewModel.send(.didTapSteamUnlink)
            }
        )
        present(alertController, animated: true)
    }

    func performLogoutFromSettings() {
        viewModel.send(.didTapLogout)
    }

    func performDeleteAccountFromSettings() {
        viewModel.send(.didTapDeleteAccount)
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: L10n.Common.Error.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Common.Button.confirm, style: .default))
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
        recentlyPlayedGames.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: RecentPlayCell.reuseId, for: indexPath
        ) as! RecentPlayCell
        let game = recentlyPlayedGames[indexPath.row]
        let resolvedTitle = viewModel.state.resolvedTitle(for: game)
        cell.configure(with: game, resolvedTitle: resolvedTitle)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let game = recentlyPlayedGames[indexPath.row]
        GameDetailSeedStore.shared.store(recentGames: [game], screen: "Profile.preview.tap")
        let resolvedGameId = game.resolvedDetailGameId
        let blockedReason: String?
        if game.detailAvailable == false {
            blockedReason = "detailUnavailable"
        } else if resolvedGameId == nil {
            blockedReason = "invalidGameId"
        } else {
            blockedReason = nil
        }
        print(
            "[DetailRouteMapping] " +
            "screen=Profile.preview " +
            "title=\(viewModel.state.resolvedTitle(for: game)) " +
            "externalGameId=\(game.externalGameId ?? "nil") " +
            "igdbGameId=\(game.igdbGameId.map(String.init) ?? "nil") " +
            "detailAvailable=\(game.detailAvailable) " +
            "createdDestination=\(resolvedGameId.map(String.init) ?? "nil") " +
            "blockedReason=\(blockedReason ?? "nil")"
        )
        guard let resolvedGameId, resolvedGameId > 0, game.detailAvailable else {
            presentUnavailableDetailAlert()
            return
        }
        print(
            "[GameTap] " +
            "screen=Profile.preview " +
            "title=\(viewModel.state.resolvedTitle(for: game)) " +
            "destination=igdb:\(resolvedGameId) " +
            "igdbGameId=\(game.igdbGameId.map(String.init) ?? "nil") " +
            "externalGameId=\(game.externalGameId ?? "nil")"
        )
        viewModel.send(.didTapGame(id: resolvedGameId))
        onGameSelected?(resolvedGameId)
    }
}

private extension ProfileViewController {
    func presentUnavailableDetailAlert() {
        let alert = UIAlertController(
            title: L10n.tr("Localizable", "profile.alert.detailUnavailableTitle"),
            message: L10n.tr("Localizable", "profile.alert.detailUnavailableMessage"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("Localizable", "common.button.ok"), style: .default))
        present(alert, animated: true)
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
