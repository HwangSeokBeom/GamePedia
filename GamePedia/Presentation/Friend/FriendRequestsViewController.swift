import UIKit

struct FriendRequestsState {
    var isLoading = false
    var selectedTab: FriendRequestListKind = .received
    var receivedRequests: [FriendRequest] = []
    var sentRequests: [FriendRequest] = []
    var receivedErrorMessage: String?
    var sentErrorMessage: String?
}

enum FriendRequestsIntent {
    case viewDidLoad
    case didSelectTab(FriendRequestListKind)
    case didTapAccept(String)
    case didTapReject(String)
    case didTapCancel(String)
}

final class FriendRequestsViewModel {
    private(set) var state = FriendRequestsState() { didSet { onStateChanged?(state) } }
    var onStateChanged: ((FriendRequestsState) -> Void)?

    private let fetchFriendRequestsUseCase: FetchFriendRequestsUseCase
    private let acceptFriendRequestUseCase: AcceptFriendRequestUseCase
    private let rejectFriendRequestUseCase: RejectFriendRequestUseCase
    private let cancelFriendRequestUseCase: CancelFriendRequestUseCase

    init(
        fetchFriendRequestsUseCase: FetchFriendRequestsUseCase = FetchFriendRequestsUseCase(repository: DefaultFriendRepository()),
        acceptFriendRequestUseCase: AcceptFriendRequestUseCase = AcceptFriendRequestUseCase(repository: DefaultFriendRepository()),
        rejectFriendRequestUseCase: RejectFriendRequestUseCase = RejectFriendRequestUseCase(repository: DefaultFriendRepository()),
        cancelFriendRequestUseCase: CancelFriendRequestUseCase = CancelFriendRequestUseCase(repository: DefaultFriendRepository())
    ) {
        self.fetchFriendRequestsUseCase = fetchFriendRequestsUseCase
        self.acceptFriendRequestUseCase = acceptFriendRequestUseCase
        self.rejectFriendRequestUseCase = rejectFriendRequestUseCase
        self.cancelFriendRequestUseCase = cancelFriendRequestUseCase
    }

    func send(_ intent: FriendRequestsIntent) {
        switch intent {
        case .viewDidLoad:
            print("[FriendRequests] viewDidLoad selectedTab=received")
            loadRequests(for: .received)
        case .didSelectTab(let tab):
            state.selectedTab = tab
            print("[FriendRequests] didSelectTab tab=\(tab.logLabel)")
            loadRequests(for: tab)
        case .didTapAccept(let requestID):
            mutateRequest { try await self.acceptFriendRequestUseCase.execute(requestID: requestID) }
        case .didTapReject(let requestID):
            mutateRequest { try await self.rejectFriendRequestUseCase.execute(requestID: requestID) }
        case .didTapCancel(let requestID):
            mutateRequest { try await self.cancelFriendRequestUseCase.execute(requestID: requestID) }
        }
    }

    private func mutateRequest(operation: @escaping () async throws -> Void) {
        Task {
            do {
                try await operation()
                loadRequests(for: state.selectedTab)
            } catch {
                await MainActor.run {
                    switch self.state.selectedTab {
                    case .received:
                        self.state.receivedErrorMessage = "친구 요청을 처리하지 못했어요."
                    case .sent:
                        self.state.sentErrorMessage = "친구 요청을 처리하지 못했어요."
                    }
                }
            }
        }
    }

    private func loadRequests(for kind: FriendRequestListKind) {
        state.isLoading = true
        switch kind {
        case .received:
            state.receivedErrorMessage = nil
        case .sent:
            state.sentErrorMessage = nil
        }

        Task {
            do {
                let requests = try await fetchFriendRequestsUseCase.execute(kind: kind)
                await MainActor.run {
                    self.state.isLoading = false
                    switch kind {
                    case .received:
                        self.state.receivedRequests = requests
                        self.state.receivedErrorMessage = nil
                    case .sent:
                        self.state.sentRequests = requests
                        self.state.sentErrorMessage = nil
                    }
                    print("[FriendRequests] response tab=\(kind.logLabel) success count=\(requests.count)")
                }
            } catch {
                await MainActor.run {
                    self.state.isLoading = false
                    let message = "친구 요청을 불러오지 못했어요."
                    switch kind {
                    case .received:
                        self.state.receivedErrorMessage = message
                    case .sent:
                        self.state.sentErrorMessage = message
                    }
                    print("[FriendRequests] response tab=\(kind.logLabel) failure error=\(error.localizedDescription)")
                }
            }
        }
    }
}

final class FriendRequestsViewController: BaseViewController<UIView, FriendRequestsState> {
    private let viewModel: FriendRequestsViewModel
    private let segmentedControl = UISegmentedControl(items: ["받은 요청", "보낸 요청"])
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let loadingIndicatorView = UIActivityIndicatorView(style: .medium)

    private var requests: [FriendRequest] = []

    init(viewModel: FriendRequestsViewModel = FriendRequestsViewModel()) {
        self.viewModel = viewModel
        super.init(rootView: UIView())
        navigationItem.title = "친구 요청"
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        bind()
        viewModel.send(.viewDidLoad)
    }

    override func render(_ state: FriendRequestsState) {
        requests = state.selectedTab == .received ? state.receivedRequests : state.sentRequests
        print("receivedRequests count:", state.receivedRequests.count)
        print("sentRequests count:", state.sentRequests.count)
        print("selectedTab:", state.selectedTab.logLabel)
        tableView.reloadData()
        segmentedControl.selectedSegmentIndex = state.selectedTab == .received ? 0 : 1
        state.isLoading ? loadingIndicatorView.startAnimating() : loadingIndicatorView.stopAnimating()
        emptyLabel.isHidden = state.isLoading || !requests.isEmpty
        let errorMessage: String?
        switch state.selectedTab {
        case .received:
            errorMessage = state.receivedErrorMessage
        case .sent:
            errorMessage = state.sentErrorMessage
        }

        if let errorMessage {
            emptyLabel.text = errorMessage
            emptyLabel.isHidden = false
        } else {
            emptyLabel.text = state.selectedTab == .received ? "받은 친구 요청이 없어요" : "보낸 친구 요청이 없어요"
        }
    }

    private func setup() {
        rootView.backgroundColor = .gpBackground
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.selectedSegmentTintColor = .gpPrimary
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(self, action: #selector(didChangeSegment), for: .valueChanged)

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

        [segmentedControl, tableView, emptyLabel, loadingIndicatorView].forEach { rootView.addSubview($0) }

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 12),
            segmentedControl.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: rootView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: rootView.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -24),

            loadingIndicatorView.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            loadingIndicatorView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 20)
        ])
    }

    private func bind() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async { self?.render(state) }
        }
    }

    @objc
    private func didChangeSegment() {
        let selectedTab: FriendRequestListKind = segmentedControl.selectedSegmentIndex == 0 ? .received : .sent
        viewModel.send(.didSelectTab(selectedTab))
    }
}

private extension FriendRequestListKind {
    var logLabel: String {
        switch self {
        case .received:
            return "received"
        case .sent:
            return "sent"
        }
    }
}

extension FriendRequestsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        requests.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FriendUserCell.reuseID, for: indexPath) as! FriendUserCell
        let request = requests[indexPath.row]
        let subtitleText = request.createdAt.map {
            RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date())
        } ?? request.user.bio ?? (segmentedControl.selectedSegmentIndex == 0 ? "받은 친구 요청" : "보낸 친구 요청")

        if segmentedControl.selectedSegmentIndex == 0 {
            cell.configure(
                user: request.user,
                subtitle: subtitleText,
                primaryAction: .init(title: "수락", style: .primary, isEnabled: true),
                secondaryAction: .init(title: "거절", style: .secondary, isEnabled: true)
            )
            cell.onPrimaryActionTapped = { [weak self] in
                self?.viewModel.send(.didTapAccept(request.id))
            }
            cell.onSecondaryActionTapped = { [weak self] in
                self?.viewModel.send(.didTapReject(request.id))
            }
        } else {
            cell.configure(
                user: request.user,
                subtitle: subtitleText,
                primaryAction: .init(title: "요청됨", style: .secondary, isEnabled: false),
                secondaryAction: .init(title: "취소", style: .secondary, isEnabled: true)
            )
            cell.onPrimaryActionTapped = nil
            cell.onSecondaryActionTapped = { [weak self] in
                self?.viewModel.send(.didTapCancel(request.id))
            }
        }
        return cell
    }
}
