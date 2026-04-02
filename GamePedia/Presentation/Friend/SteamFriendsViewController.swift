import UIKit

struct SteamFriendsState {
    var isLoading = false
    var friends: [SteamFriend] = []
    var alreadyFriendUserIDs = Set<String>()
    var isAvailable = false
    var isLimitedByPrivacy = false
    var syncWarningCode: String?
    var errorMessage: String?
}

enum SteamFriendsIntent {
    case viewDidLoad
}

final class SteamFriendsViewModel {
    private(set) var state = SteamFriendsState() { didSet { onStateChanged?(state) } }
    var onStateChanged: ((SteamFriendsState) -> Void)?

    private let fetchSteamFriendsUseCase: FetchSteamFriendsUseCase
    private let fetchFriendsListUseCase: FetchFriendsListUseCase

    init(
        fetchSteamFriendsUseCase: FetchSteamFriendsUseCase = FetchSteamFriendsUseCase(repository: DefaultFriendRepository()),
        fetchFriendsListUseCase: FetchFriendsListUseCase = FetchFriendsListUseCase(repository: DefaultFriendRepository())
    ) {
        self.fetchSteamFriendsUseCase = fetchSteamFriendsUseCase
        self.fetchFriendsListUseCase = fetchFriendsListUseCase
    }

    func send(_ intent: SteamFriendsIntent) {
        switch intent {
        case .viewDidLoad:
            loadSteamFriends()
        }
    }

    private func loadSteamFriends() {
        state.isLoading = true
        state.errorMessage = nil

        Task {
            do {
                async let steamFriendsResult = fetchSteamFriendsUseCase.execute()
                async let currentFriends = fetchFriendsListUseCase.execute()
                let steamFriends = try await steamFriendsResult
                let currentFriendList = (try? await currentFriends) ?? []
                let currentFriendUserIDs = Set(currentFriendList.map(\.id))

                await MainActor.run {
                    self.state.isLoading = false
                    self.state.friends = steamFriends.friends
                    self.state.alreadyFriendUserIDs = currentFriendUserIDs
                    self.state.isAvailable = steamFriends.isAvailable
                    self.state.isLimitedByPrivacy = steamFriends.isLimitedByPrivacy
                    self.state.syncWarningCode = steamFriends.syncWarningCode
                    self.state.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.friends = []
                    self.state.alreadyFriendUserIDs = []
                    if let networkError = error as? NetworkError,
                       networkError.serverCode?.uppercased() == "STEAM_NOT_CONNECTED" {
                        self.state.errorMessage = L10n.Friend.Steam.connectRequired
                    } else {
                        self.state.errorMessage = L10n.Friend.Steam.loadFailed
                    }
                }
            }
        }
    }
}

final class SteamFriendsViewController: BaseViewController<UIView, SteamFriendsState> {
    private let viewModel: SteamFriendsViewModel
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let loadingIndicatorView = UIActivityIndicatorView(style: .medium)
    private var friends: [SteamFriend] = []
    private var alreadyFriendUserIDs = Set<String>()
    private var relationshipChangeObserver: NSObjectProtocol?

    var onLinkedFriendSelected: ((String) -> Void)?

    init(viewModel: SteamFriendsViewModel = SteamFriendsViewModel()) {
        self.viewModel = viewModel
        super.init(rootView: UIView())
        navigationItem.title = L10n.Friend.Steam.title
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        bind()
        observeRelationshipChanges()
        viewModel.send(.viewDidLoad)
    }

    deinit {
        if let relationshipChangeObserver {
            NotificationCenter.default.removeObserver(relationshipChangeObserver)
        }
    }

    override func render(_ state: SteamFriendsState) {
        friends = state.friends
        alreadyFriendUserIDs = state.alreadyFriendUserIDs
        tableView.reloadData()
        state.isLoading ? loadingIndicatorView.startAnimating() : loadingIndicatorView.stopAnimating()
        emptyLabel.isHidden = state.isLoading || !friends.isEmpty
        emptyLabel.text = emptyMessage(for: state)
        if state.errorMessage != nil || state.isLimitedByPrivacy || friends.isEmpty {
            emptyLabel.isHidden = state.isLoading ? true : false
        }
    }

    private func setup() {
        rootView.backgroundColor = .gpBackground

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(FriendUserCell.self, forCellReuseIdentifier: FriendUserCell.reuseID)

        emptyLabel.font = .systemFont(ofSize: 15, weight: .medium)
        emptyLabel.textColor = .gpTextSecondary
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        loadingIndicatorView.color = .gpPrimary
        loadingIndicatorView.translatesAutoresizingMaskIntoConstraints = false

        [tableView, emptyLabel, loadingIndicatorView].forEach { rootView.addSubview($0) }

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: rootView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: rootView.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -24),

            loadingIndicatorView.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            loadingIndicatorView.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
    }

    private func bind() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async { self?.render(state) }
        }
    }

    private func observeRelationshipChanges() {
        relationshipChangeObserver = NotificationCenter.default.addObserver(
            forName: .friendRelationshipDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.viewModel.send(.viewDidLoad)
        }
    }

    private func emptyMessage(for state: SteamFriendsState) -> String {
        if let errorMessage = state.errorMessage {
            return errorMessage
        }
        if state.isLimitedByPrivacy {
            return L10n.Friend.Steam.privateData
        }
        if state.isAvailable == false, let syncWarningCode = state.syncWarningCode, !syncWarningCode.isEmpty {
            return L10n.Friend.Steam.unavailable
        }
        return L10n.Friend.Steam.empty
    }

    private func actionConfiguration(for friend: SteamFriend) -> FriendUserCell.ActionConfiguration? {
        guard let userId = friend.userId else { return nil }
        if alreadyFriendUserIDs.contains(userId) {
            return .init(title: L10n.Friend.Action.alreadyFriend, style: .secondary, isEnabled: false)
        }
        return .init(title: L10n.Friend.Action.viewProfile, style: .primary, isEnabled: true)
    }

    private func configuredUserSummary(for friend: SteamFriend) -> FriendUserSummary {
        FriendUserSummary(
            id: friend.userId ?? friend.steamId64,
            nickname: friend.displayName,
            bio: nil,
            profileImageURL: friend.resolvedAvatarURL,
            relationshipStatus: .none,
            recentPlayTitle: nil,
            presence: nil
        )
    }
}

extension SteamFriendsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        friends.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FriendUserCell.reuseID, for: indexPath) as! FriendUserCell
        let friend = friends[indexPath.row]
        let subtitle: String
        if friend.isLinkedToGamePedia {
            subtitle = friend.nickname == nil ? L10n.Friend.Steam.subtitleLinkedSteam : L10n.Friend.Steam.subtitleLinked
        } else {
            subtitle = L10n.Friend.Steam.subtitleUnlinked
        }
        cell.configure(
            user: configuredUserSummary(for: friend),
            subtitle: subtitle,
            primaryAction: actionConfiguration(for: friend)
        )
        cell.onPrimaryActionTapped = { [weak self] in
            guard let userId = friend.userId else { return }
            self?.onLinkedFriendSelected?(userId)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let userId = friends[indexPath.row].userId else { return }
        onLinkedFriendSelected?(userId)
    }
}
