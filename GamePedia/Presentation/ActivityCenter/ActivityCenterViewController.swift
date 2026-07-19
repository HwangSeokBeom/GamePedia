import UIKit

final class ActivityCenterViewController: BaseViewController<ActivityCenterRootView, ActivityCenterState> {
    private let viewModel: ActivityCenterViewModel
    private var items: [ActivityCenterItem] = []

    var onSocialRoute: ((SocialActivityRoute) -> Void)?
    var onAuthenticationRequired: ((RestrictedActionContext, @escaping () -> Void) -> Void)?

    /// Injected for determinism; production reads the live session.
    var isAuthenticatedProvider: () -> Bool = { APIClient.shared.userAuthToken != nil }

    init(
        rootView: ActivityCenterRootView,
        viewModel: ActivityCenterViewModel = ActivityCenterViewModel()
    ) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpTextSecondary)
        navigationItem.title = L10n.tr("Localizable", "activityCenter.title")
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.register(ActivityCenterCell.self, forCellReuseIdentifier: ActivityCenterCell.reuseID)
        rootView.retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)
        rootView.noticeRetryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)
        bindViewModel()
        viewModel.send(.viewDidLoad)
    }

    override func render(_ state: ActivityCenterState) {
        items = state.items
        rootView.render(state)
        rootView.tableView.reloadData()
    }

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state)
            }
        }
    }

    @objc
    private func didTapRetry() {
        viewModel.send(.didTapRetry)
    }
}

extension ActivityCenterViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ActivityCenterCell.reuseID,
            for: indexPath
        ) as! ActivityCenterCell
        cell.configure(with: items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let route = items[indexPath.row].route else { return }
        performRoute(route)
    }

    /// Session-gated destinations never bypass authentication, even if
    /// this screen is somehow reached without a session.
    private func performRoute(_ route: SocialActivityRoute) {
        switch ActivityCenterRoutePolicy.decision(
            for: route,
            isAuthenticated: isAuthenticatedProvider()
        ) {
        case .perform:
            onSocialRoute?(route)
        case .requireAuthentication:
            onAuthenticationRequired?(.profile) { [weak self] in
                self?.performRoute(route)
            }
        }
    }
}
