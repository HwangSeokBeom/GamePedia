import UIKit

struct FriendSearchState {
    var isLoading = false
    var keyword = ""
    var results: [FriendUserSummary] = []
    var errorMessage: String?
}

enum FriendSearchIntent {
    case viewDidLoad
    case didSearch(String)
    case didTapSendFriendRequest(String)
}

final class FriendSearchViewModel {
    private(set) var state = FriendSearchState() { didSet { onStateChanged?(state) } }
    var onStateChanged: ((FriendSearchState) -> Void)?

    private let searchFriendsUseCase: SearchFriendsUseCase
    private let sendFriendRequestUseCase: SendFriendRequestUseCase

    init(
        searchFriendsUseCase: SearchFriendsUseCase = SearchFriendsUseCase(repository: DefaultFriendRepository()),
        sendFriendRequestUseCase: SendFriendRequestUseCase = SendFriendRequestUseCase(repository: DefaultFriendRepository())
    ) {
        self.searchFriendsUseCase = searchFriendsUseCase
        self.sendFriendRequestUseCase = sendFriendRequestUseCase
    }

    func send(_ intent: FriendSearchIntent) {
        switch intent {
        case .viewDidLoad:
            onStateChanged?(state)
        case .didSearch(let keyword):
            search(keyword: keyword)
        case .didTapSendFriendRequest(let userID):
            sendFriendRequest(userID: userID)
        }
    }

    private func search(keyword: String) {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        state.keyword = trimmedKeyword
        guard !trimmedKeyword.isEmpty else {
            state.results = []
            state.errorMessage = nil
            return
        }

        state.isLoading = true
        state.errorMessage = nil

        Task {
            do {
                let users = try await searchFriendsUseCase.execute(keyword: trimmedKeyword)
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.results = users
                }
            } catch {
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.errorMessage = "친구를 찾지 못했어요."
                    self.state.results = []
                }
            }
        }
    }

    private func sendFriendRequest(userID: String) {
        Task {
            do {
                try await sendFriendRequestUseCase.execute(userID: userID)
                await MainActor.run {
                    self.updateRelationshipStatus(for: userID, status: .outgoing)
                    self.state.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    if let relationshipStatus = self.relationshipStatus(for: error) {
                        self.updateRelationshipStatus(for: userID, status: relationshipStatus)
                        self.state.errorMessage = nil
                        print("[FriendSearch] sendFriendRequest conflict userId=\(userID) mappedStatus=\(relationshipStatus.rawValue)")
                        return
                    }
                    self.state.errorMessage = "친구 요청을 보내지 못했어요."
                }
            }
        }
    }

    private func updateRelationshipStatus(for userID: String, status: FriendRelationshipStatus) {
        state.results = state.results.map { user in
            guard user.id == userID else { return user }
            return FriendUserSummary(
                id: user.id,
                nickname: user.nickname,
                bio: user.bio,
                profileImageURL: user.profileImageURL,
                relationshipStatus: status,
                recentPlayTitle: user.recentPlayTitle,
                presence: user.presence
            )
        }
    }

    private func relationshipStatus(for error: Error) -> FriendRelationshipStatus? {
        guard let networkError = error as? NetworkError,
              let serverCode = networkError.serverCode?.uppercased()
        else {
            return nil
        }

        switch serverCode {
        case "FRIEND_REQUEST_ALREADY_SENT":
            return .outgoing
        case "FRIEND_REQUEST_ALREADY_RECEIVED":
            return .incoming
        default:
            return nil
        }
    }
}

final class FriendSearchViewController: BaseViewController<UIView, FriendSearchState> {
    private let viewModel: FriendSearchViewModel
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let loadingIndicatorView = UIActivityIndicatorView(style: .medium)
    private var results: [FriendUserSummary] = []
    private var relationshipChangeObserver: NSObjectProtocol?

    var onFriendSelected: ((String) -> Void)?

    init(viewModel: FriendSearchViewModel = FriendSearchViewModel()) {
        self.viewModel = viewModel
        super.init(rootView: UIView())
        navigationItem.title = "친구 찾기"
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

    override func render(_ state: FriendSearchState) {
        results = state.results
        tableView.reloadData()
        emptyLabel.isHidden = state.isLoading || !state.results.isEmpty
        emptyLabel.text = state.errorMessage ?? (state.keyword.isEmpty ? "닉네임으로 친구를 찾아보세요" : "검색 결과가 없어요")
        state.isLoading ? loadingIndicatorView.startAnimating() : loadingIndicatorView.stopAnimating()
    }

    private func setup() {
        rootView.backgroundColor = .gpBackground
        searchBar.placeholder = "닉네임으로 검색"
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.delegate = self

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

        [searchBar, tableView, emptyLabel, loadingIndicatorView].forEach { rootView.addSubview($0) }

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
            searchBar.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -12),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: rootView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: rootView.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -24),

            loadingIndicatorView.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            loadingIndicatorView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 20)
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
            guard let self, self.searchBar.text?.isEmpty == false else { return }
            self.viewModel.send(.didSearch(self.searchBar.text ?? ""))
        }
    }

    private func actionConfiguration(for user: FriendUserSummary) -> FriendUserCell.ActionConfiguration? {
        switch user.relationshipStatus {
        case .none:
            return .init(title: "친구 추가", style: .primary, isEnabled: true)
        case .outgoing:
            return .init(title: "요청됨", style: .secondary, isEnabled: false)
        case .friends:
            return .init(title: "친구", style: .secondary, isEnabled: false)
        case .incoming:
            return .init(title: "받은 요청 있음", style: .secondary, isEnabled: false)
        case .self:
            return nil
        }
    }

    private func subtitleText(for user: FriendUserSummary) -> String? {
        if let recentPlayTitle = user.recentPlayTitle, !recentPlayTitle.isEmpty {
            return "최근 플레이: \(recentPlayTitle)"
        }

        if let bio = user.bio, !bio.isEmpty {
            return bio
        }

        switch user.relationshipStatus {
        case .friends:
            return "이미 친구예요"
        case .outgoing:
            return "친구 요청을 보냈어요"
        case .incoming:
            return "받은 친구 요청이 있어요"
        case .none, .self:
            return nil
        }
    }
}

extension FriendSearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        viewModel.send(.didSearch(searchBar.text ?? ""))
        searchBar.resignFirstResponder()
    }
}

extension FriendSearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FriendUserCell.reuseID, for: indexPath) as! FriendUserCell
        let user = results[indexPath.row]
        cell.configure(
            user: user,
            subtitle: subtitleText(for: user),
            primaryAction: actionConfiguration(for: user)
        )
        cell.onPrimaryActionTapped = { [weak self] in
            guard user.relationshipStatus == .none else { return }
            self?.viewModel.send(.didTapSendFriendRequest(user.id))
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onFriendSelected?(results[indexPath.row].id)
    }
}
