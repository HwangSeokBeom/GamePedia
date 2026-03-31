import UIKit

struct FriendActivityFeedState {
    var isLoading = false
    var activities: [FriendActivityItem] = []
    var errorMessage: String?
}

enum FriendActivityFeedIntent {
    case viewDidLoad
}

final class FriendActivityFeedViewModel {
    private(set) var state = FriendActivityFeedState() { didSet { onStateChanged?(state) } }
    var onStateChanged: ((FriendActivityFeedState) -> Void)?

    private let fetchFriendActivityFeedUseCase: FetchFriendActivityFeedUseCase

    init(
        fetchFriendActivityFeedUseCase: FetchFriendActivityFeedUseCase = FetchFriendActivityFeedUseCase(
            repository: DefaultFriendRepository()
        )
    ) {
        self.fetchFriendActivityFeedUseCase = fetchFriendActivityFeedUseCase
    }

    func send(_ intent: FriendActivityFeedIntent) {
        switch intent {
        case .viewDidLoad:
            load()
        }
    }

    private func load() {
        state.isLoading = true
        Task {
            do {
                let activities = try await fetchFriendActivityFeedUseCase.execute()
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.activities = activities
                    self.state.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.errorMessage = "친구 활동을 불러오지 못했어요"
                }
            }
        }
    }
}

final class FriendActivityFeedViewController: BaseViewController<UIView, FriendActivityFeedState> {
    private let viewModel: FriendActivityFeedViewModel
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let loadingIndicatorView = UIActivityIndicatorView(style: .medium)
    private var activities: [FriendActivityItem] = []

    var onGameSelected: ((Int) -> Void)?

    init(viewModel: FriendActivityFeedViewModel = FriendActivityFeedViewModel()) {
        self.viewModel = viewModel
        super.init(rootView: UIView())
        navigationItem.title = "친구 활동"
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        bind()
        viewModel.send(.viewDidLoad)
    }

    override func render(_ state: FriendActivityFeedState) {
        activities = state.activities
        tableView.reloadData()
        state.isLoading ? loadingIndicatorView.startAnimating() : loadingIndicatorView.stopAnimating()
        emptyLabel.isHidden = state.isLoading || !activities.isEmpty
        emptyLabel.text = state.errorMessage ?? "친구 활동이 아직 없어요"
        if state.errorMessage != nil {
            emptyLabel.isHidden = false
        }
    }

    private func setup() {
        rootView.backgroundColor = .gpBackground
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(FriendActivityCell.self, forCellReuseIdentifier: FriendActivityCell.reuseID)

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
}

extension FriendActivityFeedViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        activities.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FriendActivityCell.reuseID, for: indexPath) as! FriendActivityCell
        cell.configure(activity: activities[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onGameSelected?(activities[indexPath.row].game.id)
    }
}
