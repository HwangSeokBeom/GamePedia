import UIKit

enum SocialPrivacySettingItem: Int, CaseIterable {
    case friendsList
    case recentPlay
    case likedGames
    case reviews

    var title: String {
        switch self {
        case .friendsList: return L10n.Profile.Privacy.friendsListTitle
        case .recentPlay: return L10n.Profile.Privacy.recentPlayTitle
        case .likedGames: return L10n.Profile.Privacy.likedGamesTitle
        case .reviews: return L10n.Profile.Privacy.reviewsTitle
        }
    }

    var subtitle: String {
        switch self {
        case .friendsList: return L10n.Profile.Privacy.friendsListSubtitle
        case .recentPlay: return L10n.Profile.Privacy.recentPlaySubtitle
        case .likedGames: return L10n.Profile.Privacy.likedGamesSubtitle
        case .reviews: return L10n.Profile.Privacy.reviewsSubtitle
        }
    }
}

struct SocialPrivacySettingsState {
    var isLoading = false
    var isSaving = false
    var isImportingSteamFriends = false
    var settings: SocialPrivacySettings?
    var errorMessage: String?
    var successMessage: String?
}

enum SocialPrivacySettingsIntent {
    case viewDidLoad
    case didTapRetry
    case didToggle(SocialPrivacySettingItem, Bool)
    case didTapImportSteamFriends
    case didConsumeSuccessMessage
}

final class SocialPrivacySettingsViewModel {
    private(set) var state = SocialPrivacySettingsState() { didSet { onStateChanged?(state) } }
    var onStateChanged: ((SocialPrivacySettingsState) -> Void)?

    private let fetchSocialPrivacySettingsUseCase: FetchSocialPrivacySettingsUseCase
    private let updateSocialPrivacySettingsUseCase: UpdateSocialPrivacySettingsUseCase
    private let importSteamFriendsUseCase: ImportSteamFriendsUseCase

    init(
        fetchSocialPrivacySettingsUseCase: FetchSocialPrivacySettingsUseCase = FetchSocialPrivacySettingsUseCase(repository: DefaultFriendRepository()),
        updateSocialPrivacySettingsUseCase: UpdateSocialPrivacySettingsUseCase = UpdateSocialPrivacySettingsUseCase(repository: DefaultFriendRepository()),
        importSteamFriendsUseCase: ImportSteamFriendsUseCase = ImportSteamFriendsUseCase(repository: DefaultFriendRepository())
    ) {
        self.fetchSocialPrivacySettingsUseCase = fetchSocialPrivacySettingsUseCase
        self.updateSocialPrivacySettingsUseCase = updateSocialPrivacySettingsUseCase
        self.importSteamFriendsUseCase = importSteamFriendsUseCase
    }

    func send(_ intent: SocialPrivacySettingsIntent) {
        switch intent {
        case .viewDidLoad, .didTapRetry:
            load()
        case .didToggle(let item, let isOn):
            update(item: item, isOn: isOn)
        case .didTapImportSteamFriends:
            importSteamFriends()
        case .didConsumeSuccessMessage:
            state.successMessage = nil
        }
    }

    private func load() {
        state.isLoading = true
        state.errorMessage = nil
        Task {
            do {
                let settings = try await fetchSocialPrivacySettingsUseCase.execute()
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.settings = settings
                }
            } catch {
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.errorMessage = L10n.Profile.Privacy.loadFailed
                }
            }
        }
    }

    private func update(item: SocialPrivacySettingItem, isOn: Bool) {
        guard let currentSettings = state.settings, !state.isSaving else { return }
        let updatedSettings: SocialPrivacySettings
        switch item {
        case .friendsList:
            updatedSettings = currentSettings.updated(isFriendsListPublic: isOn)
        case .recentPlay:
            updatedSettings = currentSettings.updated(isRecentPlayPublic: isOn)
        case .likedGames:
            updatedSettings = currentSettings.updated(isLikedGamesPublic: isOn)
        case .reviews:
            updatedSettings = currentSettings.updated(isReviewsPublic: isOn)
        }

        state.isSaving = true
        state.errorMessage = nil
        state.settings = updatedSettings

        Task {
            do {
                let savedSettings = try await updateSocialPrivacySettingsUseCase.execute(settings: updatedSettings)
                await MainActor.run {
                    self.state.isSaving = false
                    self.state.settings = savedSettings
                }
            } catch {
                await MainActor.run {
                    self.state.isSaving = false
                    self.state.settings = currentSettings
                    self.state.errorMessage = L10n.Profile.Privacy.saveFailed
                }
            }
        }
    }

    private func importSteamFriends() {
        guard !state.isImportingSteamFriends else { return }
        state.isImportingSteamFriends = true
        state.errorMessage = nil
        Task {
            do {
                try await importSteamFriendsUseCase.execute()
                await MainActor.run {
                    self.state.isImportingSteamFriends = false
                    self.state.successMessage = L10n.Profile.Privacy.importSuccess
                }
            } catch {
                await MainActor.run {
                    self.state.isImportingSteamFriends = false
                    self.state.errorMessage = L10n.Profile.Privacy.importFailed
                }
            }
        }
    }
}

final class SocialPrivacySettingsViewController: BaseViewController<UIView, SocialPrivacySettingsState> {
    private let viewModel: SocialPrivacySettingsViewModel
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let loadingIndicatorView = UIActivityIndicatorView(style: .medium)
    private let emptyLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private var lastPresentedSuccessMessage: String?

    init(viewModel: SocialPrivacySettingsViewModel = SocialPrivacySettingsViewModel()) {
        self.viewModel = viewModel
        super.init(rootView: UIView())
        navigationItem.title = L10n.Profile.Action.socialPrivacy
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        bind()
        viewModel.send(.viewDidLoad)
    }

    override func render(_ state: SocialPrivacySettingsState) {
        state.isLoading ? loadingIndicatorView.startAnimating() : loadingIndicatorView.stopAnimating()
        tableView.reloadData()
        tableView.isUserInteractionEnabled = !state.isSaving
        emptyLabel.isHidden = state.errorMessage == nil || state.settings != nil
        retryButton.isHidden = state.errorMessage == nil || state.settings != nil
        emptyLabel.text = state.errorMessage
        updateFooter(settings: state.settings, isImporting: state.isImportingSteamFriends)

        if let successMessage = state.successMessage,
           successMessage != lastPresentedSuccessMessage {
            lastPresentedSuccessMessage = successMessage
            let alert = UIAlertController(title: nil, message: successMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.Common.Button.confirm, style: .default) { [weak self] _ in
                self?.viewModel.send(.didConsumeSuccessMessage)
            })
            present(alert, animated: true)
        } else if state.successMessage == nil {
            lastPresentedSuccessMessage = nil
        }
    }

    private func setup() {
        rootView.backgroundColor = .gpBackground

        tableView.backgroundColor = .gpBackground
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(SocialPrivacyToggleCell.self, forCellReuseIdentifier: SocialPrivacyToggleCell.reuseID)

        loadingIndicatorView.color = .gpPrimary
        loadingIndicatorView.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.font = .systemFont(ofSize: 15, weight: .medium)
        emptyLabel.textColor = .gpTextSecondary
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        var retryConfiguration = UIButton.Configuration.plain()
        retryConfiguration.title = L10n.Common.Button.retry
        retryConfiguration.baseForegroundColor = .gpPrimary
        retryButton.configuration = retryConfiguration
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)

        [tableView, loadingIndicatorView, emptyLabel, retryButton].forEach { rootView.addSubview($0) }

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            loadingIndicatorView.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            loadingIndicatorView.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 20),

            emptyLabel.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: rootView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: rootView.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -24),

            retryButton.topAnchor.constraint(equalTo: emptyLabel.bottomAnchor, constant: 12),
            retryButton.centerXAnchor.constraint(equalTo: rootView.centerXAnchor)
        ])
    }

    private func bind() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state)
            }
        }
    }

    private func updateFooter(settings: SocialPrivacySettings?, isImporting: Bool) {
        guard let settings, settings.isSteamFriendsFeatureAvailable else {
            tableView.tableFooterView = UIView(frame: .zero)
            return
        }

        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 92))
        footerView.backgroundColor = .clear

        var configuration = UIButton.Configuration.filled()
        configuration.title = isImporting ? L10n.Profile.Privacy.importLoading : L10n.Profile.Privacy.importButton
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .gpOnPrimary
        configuration.cornerStyle = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18)

        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = !isImporting
        button.addTarget(self, action: #selector(didTapImportSteamFriends), for: .touchUpInside)

        let helperLabel = UILabel()
        helperLabel.font = .systemFont(ofSize: 12)
        helperLabel.textColor = .gpTextSecondary
        helperLabel.numberOfLines = 2
        helperLabel.text = L10n.Profile.Privacy.importHelper
        helperLabel.translatesAutoresizingMaskIntoConstraints = false

        footerView.addSubview(button)
        footerView.addSubview(helperLabel)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 12),
            button.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 20),
            button.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -20),

            helperLabel.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 10),
            helperLabel.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 24),
            helperLabel.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -24)
        ])

        tableView.tableFooterView = footerView
    }

    @objc
    private func didTapRetry() {
        viewModel.send(.didTapRetry)
    }

    @objc
    private func didTapImportSteamFriends() {
        viewModel.send(.didTapImportSteamFriends)
    }
}

extension SocialPrivacySettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.state.settings == nil ? 0 : SocialPrivacySettingItem.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SocialPrivacyToggleCell.reuseID, for: indexPath) as! SocialPrivacyToggleCell
        guard let item = SocialPrivacySettingItem(rawValue: indexPath.row),
              let settings = viewModel.state.settings else {
            return cell
        }

        let isOn: Bool
        switch item {
        case .friendsList:
            isOn = settings.isFriendsListPublic
        case .recentPlay:
            isOn = settings.isRecentPlayPublic
        case .likedGames:
            isOn = settings.isLikedGamesPublic
        case .reviews:
            isOn = settings.isReviewsPublic
        }

        cell.configure(title: item.title, subtitle: item.subtitle, isOn: isOn)
        cell.onToggleChanged = { [weak self] isOn in
            self?.viewModel.send(.didToggle(item, isOn))
        }
        return cell
    }
}

private final class SocialPrivacyToggleCell: UITableViewCell {
    static let reuseID = "SocialPrivacyToggleCell"

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let toggleSwitch = UISwitch()
    private var isConfigured = false

    var onToggleChanged: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onToggleChanged = nil
        isConfigured = false
    }

    func configure(title: String, subtitle: String, isOn: Bool) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        toggleSwitch.isOn = isOn
        isConfigured = true
    }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .gpBackground
        contentView.backgroundColor = .gpBackground

        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .gpTextPrimary

        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .gpTextSecondary
        subtitleLabel.numberOfLines = 2

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let cardView = UIView()
        cardView.backgroundColor = .gpCardBackground
        cardView.layer.cornerRadius = 16
        cardView.translatesAutoresizingMaskIntoConstraints = false

        toggleSwitch.onTintColor = .gpPrimary
        toggleSwitch.addTarget(self, action: #selector(didChangeToggle), for: .valueChanged)
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        cardView.addSubview(textStack)
        cardView.addSubview(toggleSwitch)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            textStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            textStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: toggleSwitch.leadingAnchor, constant: -12),
            textStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),

            toggleSwitch.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            toggleSwitch.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
        ])
    }

    @objc
    private func didChangeToggle() {
        guard isConfigured else { return }
        onToggleChanged?(toggleSwitch.isOn)
    }
}
