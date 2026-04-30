import UIKit

final class AIRecommendationViewController: BaseViewController<AIRecommendationRootView, AIRecommendationState> {
    private let viewModel: AIRecommendationViewModel
    private var recommendations: [AIRecommendationItemViewState] = []
    private var keyboardObservers: [NSObjectProtocol] = []

    var onGameSelected: ((Int) -> Void)?
    var onAuthenticationRequired: ((RestrictedActionContext, @escaping () -> Void) -> Void)?

    init(
        rootView: AIRecommendationRootView,
        viewModel: AIRecommendationViewModel = AIRecommendationViewModel()
    ) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        navigationItem.title = "AI 추천"
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDelegates()
        setupKeyboardObservers()
        bindViewModel()
        viewModel.send(.viewDidLoad)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isMovingFromParent || navigationController?.isBeingDismissed == true {
            viewModel.cancelInFlightRequest()
        }
    }

    deinit {
        keyboardObservers.forEach(NotificationCenter.default.removeObserver)
    }

    override func render(_ state: AIRecommendationState) {
        let examplesChanged = rootView.chipStackView.arrangedSubviews.count != state.examples.count
        rootView.render(state)

        if examplesChanged {
            rootView.configureChips(state.examples, target: self, action: #selector(didTapExampleChip(_:)))
        }

        recommendations = state.recommendations
        rootView.tableView.reloadData()
        rootView.updateTableHeight()
    }

    private func setupDelegates() {
        rootView.queryTextView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.recommendButton.addTarget(self, action: #selector(didTapRecommendButton), for: .touchUpInside)
        rootView.retryButton.addTarget(self, action: #selector(didTapRetryButton), for: .touchUpInside)
    }

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state)
            }
        }
        viewModel.onRouteToGameDetail = { [weak self] gameId in
            self?.onGameSelected?(gameId)
        }
        viewModel.onAuthenticationRequired = { [weak self] context, action in
            self?.onAuthenticationRequired?(context, action)
        }
    }

    private func setupKeyboardObservers() {
        let notificationCenter = NotificationCenter.default
        let willChangeObserver = notificationCenter.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleKeyboard(notification)
        }
        let willHideObserver = notificationCenter.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rootView.setKeyboardBottomInset(0)
        }
        keyboardObservers = [willChangeObserver, willHideObserver]
    }

    private func handleKeyboard(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        let keyboardFrameInView = view.convert(keyboardFrame, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrameInView.minY)
        rootView.setKeyboardBottomInset(overlap + 12)
    }

    @objc
    private func didTapRecommendButton() {
        rootView.queryTextView.resignFirstResponder()
        viewModel.send(.recommendButtonTapped)
    }

    @objc
    private func didTapRetryButton() {
        viewModel.send(.retryTapped)
    }

    @objc
    private func didTapExampleChip(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        viewModel.send(.exampleChipTapped(title))
    }
}

extension AIRecommendationViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        viewModel.send(.queryChanged(textView.text ?? ""))
    }
}

extension AIRecommendationViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        recommendations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: AIRecommendationResultCell.reuseId,
            for: indexPath
        ) as? AIRecommendationResultCell else {
            return UITableViewCell()
        }
        let item = recommendations[indexPath.row]
        cell.configure(with: item)
        cell.onFavoriteButtonTapped = { [weak self] in
            self?.viewModel.send(.favoriteTapped(gameId: item.gameId))
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = recommendations[indexPath.row]
        viewModel.send(.gameTapped(gameId: item.gameId))
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        rootView.queryTextView.resignFirstResponder()
    }
}
