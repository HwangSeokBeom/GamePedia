import UIKit

final class NotificationsViewController: BaseViewController<NotificationsRootView, NotificationsState> {
    private let viewModel: NotificationsViewModel
    private var notifications: [AppNotification] = []

    init(
        rootView: NotificationsRootView,
        viewModel: NotificationsViewModel = NotificationsViewModel()
    ) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpTextSecondary)
        navigationItem.title = "알림"
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.register(NotificationCell.self, forCellReuseIdentifier: NotificationCell.reuseID)
        rootView.retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)
        bindViewModel()
        viewModel.send(.viewDidLoad)
    }

    override func render(_ state: NotificationsState) {
        notifications = state.notifications
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

extension NotificationsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        notifications.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: NotificationCell.reuseID, for: indexPath) as! NotificationCell
        cell.configure(with: notifications[indexPath.row])
        return cell
    }
}
