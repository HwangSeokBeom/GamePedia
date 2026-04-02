import UIKit

struct FriendsListState {
    var isLoading = false
    var friends: [FriendUserSummary] = []
    var errorMessage: String?
}

enum FriendsListIntent {
    case viewDidLoad
}

final class FriendsListViewModel {
    private(set) var state = FriendsListState() { didSet { onStateChanged?(state) } }
    var onStateChanged: ((FriendsListState) -> Void)?

    private let fetchFriendsListUseCase: FetchFriendsListUseCase

    init(fetchFriendsListUseCase: FetchFriendsListUseCase = FetchFriendsListUseCase(repository: DefaultFriendRepository())) {
        self.fetchFriendsListUseCase = fetchFriendsListUseCase
    }

    func send(_ intent: FriendsListIntent) {
        switch intent {
        case .viewDidLoad:
            loadFriends()
        }
    }

    private func loadFriends() {
        state.isLoading = true
        state.errorMessage = nil
        print("[FriendsList] request endpoint=GET /users/me/friends")
        Task {
            do {
                let friends = try await fetchFriendsListUseCase.execute()
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.friends = friends
                    self.state.errorMessage = nil
                    print("[FriendsList] response success parsedFriendCount=\(friends.count)")
                }
            } catch {
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.friends = []
                    self.state.errorMessage = L10n.Friend.List.loadFailed
                    print("[FriendsList] response failure error=\(error.localizedDescription)")
                }
            }
        }
    }
}

final class FriendsListViewController: BaseViewController<UIView, FriendsListState> {
    private let viewModel: FriendsListViewModel
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let loadingIndicatorView = UIActivityIndicatorView(style: .medium)
    private var friends: [FriendUserSummary] = []
    private var relationshipChangeObserver: NSObjectProtocol?

    var onFriendSelected: ((String) -> Void)?

    init(viewModel: FriendsListViewModel = FriendsListViewModel()) {
        self.viewModel = viewModel
        super.init(rootView: UIView())
        navigationItem.title = L10n.Friend.List.title
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

    override func render(_ state: FriendsListState) {
        friends = state.friends
        print("[FriendsList] render mappedCellModelCount=\(friends.count)")
        tableView.reloadData()
        state.isLoading ? loadingIndicatorView.startAnimating() : loadingIndicatorView.stopAnimating()
        emptyLabel.isHidden = state.isLoading || !friends.isEmpty
        emptyLabel.text = state.errorMessage ?? L10n.Empty.noFriends
        if state.errorMessage != nil {
            emptyLabel.isHidden = false
        }
    }

    private func setup() {
        rootView.backgroundColor = .gpBackground
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 84
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
}

extension FriendsListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        friends.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FriendUserCell.reuseID, for: indexPath) as! FriendUserCell
        let user = friends[indexPath.row]
        let subtitleParts = [user.recentPlayTitle.map(L10n.Friend.List.recentPlay), user.bio].compactMap { $0 }
        let subtitle = subtitleParts.isEmpty ? L10n.Friend.List.defaultSubtitle : subtitleParts.joined(separator: "\n")
        cell.configure(
            user: user,
            subtitle: subtitle,
            primaryAction: .init(title: L10n.Friend.Action.friend, style: .secondary, isEnabled: false)
        )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onFriendSelected?(friends[indexPath.row].id)
    }
}
