import UIKit

struct FriendActivityFeedState {
    var isLoading = false
    var isRefreshing = false
    var isLoadingMore = false
    var items: [FriendActivityFeedItemViewState] = []
    var nextCursor: String?
    var errorMessage: String?

    var isEmpty: Bool {
        !isLoading && !isRefreshing && items.isEmpty && errorMessage == nil
    }
}

enum FriendActivityFeedIntent {
    case viewDidLoad
    case didPullToRefresh
    case didReachListBottom
}

final class FriendActivityFeedViewModel {
    private(set) var state = FriendActivityFeedState() { didSet { onStateChanged?(state) } }
    var onStateChanged: ((FriendActivityFeedState) -> Void)?

    private let fetchFriendActivityFeedUseCase: FetchFriendActivityFeedUseCase
    private let widgetSnapshotStore: SocialWidgetSnapshotStore
    private var hasLoadedOnce = false
    private var isLoadInFlight = false
    private var activityItemsByID: [String: FriendActivityItem] = [:]

    init(
        fetchFriendActivityFeedUseCase: FetchFriendActivityFeedUseCase = FetchFriendActivityFeedUseCase(
            repository: DefaultFriendRepository()
        ),
        widgetSnapshotStore: SocialWidgetSnapshotStore = .shared
    ) {
        self.fetchFriendActivityFeedUseCase = fetchFriendActivityFeedUseCase
        self.widgetSnapshotStore = widgetSnapshotStore
    }

    func send(_ intent: FriendActivityFeedIntent) {
        switch intent {
        case .viewDidLoad:
            guard !hasLoadedOnce else { return }
            load(reset: true, isUserInitiatedRefresh: false)
        case .didPullToRefresh:
            load(reset: true, isUserInitiatedRefresh: true)
        case .didReachListBottom:
            guard state.nextCursor != nil else { return }
            load(reset: false, isUserInitiatedRefresh: false)
        }
    }

    func item(for identity: String) -> FriendActivityItem? {
        activityItemsByID[identity]
    }

    private func load(reset: Bool, isUserInitiatedRefresh: Bool) {
        guard !isLoadInFlight else { return }
        isLoadInFlight = true

        if reset {
            if hasLoadedOnce, isUserInitiatedRefresh {
                state.isRefreshing = true
            } else {
                state.isLoading = true
            }
        } else {
            state.isLoadingMore = true
        }

        let currentItems = state.items
        let cursor = reset ? nil : state.nextCursor
        print("[FriendActivity] loadStarted reset=\(reset) cursor=\(cursor ?? "nil")")

        Task {
            do {
                let page = try await fetchFriendActivityFeedUseCase.execute(cursor: cursor)
                await MainActor.run {
                    let newItems = page.activities.map(FriendActivityFeedItemFormatter.makeViewState(from:))
                    self.activityItemsByID.merge(
                        MappingSafety.dictionary(
                            pairs: page.activities.map { ($0.stableIdentity, $0) },
                            logPrefix: "[FriendActivity]",
                            keyName: "stableIdentity",
                            countLabel: "activityCount",
                            screen: "FriendActivityFeedViewController.loadFeed",
                            mergePolicy: .keepLast
                        )
                    ) { _, new in new }
                    let mergedItems = self.mergeItems(
                        currentItems: reset ? [] : currentItems,
                        incomingItems: newItems
                    )

                    if reset, self.hasLoadedOnce {
                        self.enqueueBannersIfNeeded(incomingItems: newItems, existingItems: currentItems)
                    }

                    self.state.isLoading = false
                    self.state.isRefreshing = false
                    self.state.isLoadingMore = false
                    self.state.items = mergedItems
                    self.state.nextCursor = page.nextCursor
                    self.state.errorMessage = nil
                    self.hasLoadedOnce = true
                    self.isLoadInFlight = false
                    self.persistWidgetSnapshot(items: mergedItems)

                    print(
                        "[FriendActivity] loadSuccess count=\(mergedItems.count) " +
                        "nextCursor=\(page.nextCursor ?? "nil")"
                    )
                }
            } catch {
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.isRefreshing = false
                    self.state.isLoadingMore = false
                    if reset {
                        self.state.items = []
                    }
                    self.state.errorMessage = L10n.Friend.Activity.loadFailed
                    self.isLoadInFlight = false
                    print("[FriendActivity] loadFailure error=\(error.localizedDescription)")
                }
            }
        }
    }

    private func mergeItems(
        currentItems: [FriendActivityFeedItemViewState],
        incomingItems: [FriendActivityFeedItemViewState]
    ) -> [FriendActivityFeedItemViewState] {
        var seen = Set<String>()
        let merged = (currentItems + incomingItems).filter { item in
            seen.insert(item.id).inserted
        }
        return merged.sorted { lhs, rhs in
            guard let lhsActivity = activityItemsByID[lhs.id],
                  let rhsActivity = activityItemsByID[rhs.id] else {
                return lhs.timestampText > rhs.timestampText
            }
            return (lhsActivity.createdAt ?? .distantPast) > (rhsActivity.createdAt ?? .distantPast)
        }
    }

    private func enqueueBannersIfNeeded(
        incomingItems: [FriendActivityFeedItemViewState],
        existingItems: [FriendActivityFeedItemViewState]
    ) {
        let existingIDs = Set(existingItems.map(\.id))
        incomingItems
            .filter { existingIDs.contains($0.id) == false }
            .prefix(3)
            .forEach { item in
                let payload = SocialActivityBannerPayload(
                    id: item.id,
                    title: item.actorNameText,
                    message: item.headlineText,
                    actorAvatarURL: item.actorAvatarURL,
                    gameCoverURL: item.gameCoverURL,
                    route: item.primaryRoute
                )
                SocialActivityEventDispatcher.shared.send(.showBanner(payload))
            }
    }

    private func persistWidgetSnapshot(items: [FriendActivityFeedItemViewState]) {
        let widgetItems = items.prefix(3).map { item in
            FriendActivitySummaryWidgetData.Item(
                id: item.id,
                title: item.actorNameText,
                subtitle: item.headlineText,
                actorAvatarURL: item.actorAvatarURL,
                gameCoverURL: item.gameCoverURL,
                timestampText: item.timestampText
            )
        }

        let snapshot = FriendActivitySummaryWidgetData(
            generatedAt: Date(),
            title: L10n.Friend.Activity.feedTitle,
            summary: widgetItems.first?.subtitle ?? L10n.Friend.Activity.feedSummary,
            items: Array(widgetItems)
        )
        widgetSnapshotStore.saveFriendActivitySummary(snapshot)
    }
}

final class FriendActivityFeedViewController: BaseViewController<UIView, FriendActivityFeedState> {
    private let viewModel: FriendActivityFeedViewModel
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let loadingIndicatorView = UIActivityIndicatorView(style: .medium)
    private let footerLoadingIndicatorView = UIActivityIndicatorView(style: .medium)
    private let refreshControl = UIRefreshControl()
    private var items: [FriendActivityFeedItemViewState] = []

    var onRoute: ((SocialActivityRoute) -> Void)?

    init(viewModel: FriendActivityFeedViewModel = FriendActivityFeedViewModel()) {
        self.viewModel = viewModel
        super.init(rootView: UIView())
        navigationItem.title = L10n.Friend.Activity.feedTitle
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        bind()
        viewModel.send(.viewDidLoad)
    }

    override func render(_ state: FriendActivityFeedState) {
        items = state.items
        tableView.reloadData()

        state.isLoading ? loadingIndicatorView.startAnimating() : loadingIndicatorView.stopAnimating()
        state.isLoadingMore ? footerLoadingIndicatorView.startAnimating() : footerLoadingIndicatorView.stopAnimating()
        if state.isRefreshing == false, refreshControl.isRefreshing {
            refreshControl.endRefreshing()
        }

        emptyLabel.isHidden = !state.isEmpty && state.errorMessage == nil
        if let errorMessage = state.errorMessage {
            emptyLabel.isHidden = false
            emptyLabel.text = errorMessage
        } else if state.isEmpty {
            emptyLabel.isHidden = false
            emptyLabel.text = L10n.Friend.Activity.empty
        } else {
            emptyLabel.text = nil
        }
    }

    private func setup() {
        rootView.backgroundColor = .gpBackground
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 136
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(FriendActivityCell.self, forCellReuseIdentifier: FriendActivityCell.reuseID)
        tableView.refreshControl = refreshControl

        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        footerLoadingIndicatorView.color = .gpPrimary
        footerLoadingIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        footerView.addSubview(footerLoadingIndicatorView)
        NSLayoutConstraint.activate([
            footerLoadingIndicatorView.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
            footerLoadingIndicatorView.centerYAnchor.constraint(equalTo: footerView.centerYAnchor)
        ])
        tableView.tableFooterView = footerView

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

        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
    }

    private func bind() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async { self?.render(state) }
        }
    }

    @objc
    private func didPullToRefresh() {
        viewModel.send(.didPullToRefresh)
    }
}

extension FriendActivityFeedViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FriendActivityCell.reuseID, for: indexPath) as! FriendActivityCell
        let item = items[indexPath.row]
        cell.configure(with: item)
        cell.onActorTapped = { [weak self] in
            guard let actorRoute = item.actorRoute else { return }
            self?.onRoute?(actorRoute)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onRoute?(items[indexPath.row].primaryRoute)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard indexPath.row >= items.count - 2 else { return }
        viewModel.send(.didReachListBottom)
    }
}
