import UIKit

final class LibraryCuratorViewController: BaseViewController<LibraryCuratorRootView, LibraryCuratorViewState> {
    private let viewModel: LibraryCuratorViewModel
    private var sections: [LibraryCuratorSectionViewState] = []
    private var keyboardObservers: [NSObjectProtocol] = []
    private var lastLoggedPromptSelection: String?

    var onGameSelected: ((Int) -> Void)?
    var onAuthenticationRequired: ((RestrictedActionContext, @escaping () -> Void) -> Void)?

    private let modes = LibraryCuratorMode.allCases

    init(
        rootView: LibraryCuratorRootView = LibraryCuratorRootView(),
        viewModel: LibraryCuratorViewModel = LibraryCuratorViewModel()
    ) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        navigationItem.title = L10n.tr("Localizable", "library_curator_title")
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDelegates()
        setupKeyboardObservers()
        bindViewModel()
        viewModel.send(.viewDidLoad)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let tabBarHeight = tabBarController?.tabBar.isHidden == false
            ? tabBarController?.tabBar.bounds.height ?? 0
            : 0
        rootView.setBaseBottomInset(tabBarHeight + view.safeAreaInsets.bottom + 24)
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

    override func render(_ state: LibraryCuratorViewState) {
        rootView.render(state)
        sections = state.visibleRecommendations
        rootView.modeCollectionView.reloadData()
        applyPromptSelection(state.selectedPromptChipID)
        rootView.tableView.reloadData()
        rootView.updateTableHeight()
    }

    private func applyPromptSelection(_ selectedPromptID: String?) {
        if let selectedPromptID,
           let selectedIndex = modes.firstIndex(where: { $0.promptChipID == selectedPromptID }) {
            rootView.modeCollectionView.selectItem(
                at: IndexPath(item: selectedIndex, section: 0),
                animated: false,
                scrollPosition: .centeredHorizontally
            )
        } else {
            rootView.modeCollectionView.indexPathsForSelectedItems?.forEach {
                rootView.modeCollectionView.deselectItem(at: $0, animated: false)
            }
        }

#if DEBUG
        let visiblePromptChips = modes
            .map { "\($0.promptChipID):\($0.promptChipID == selectedPromptID)" }
            .joined(separator: ",")
        let logKey = "\(selectedPromptID ?? "nil")|\(visiblePromptChips)"
        guard logKey != lastLoggedPromptSelection else { return }
        lastLoggedPromptSelection = logKey
        print(
            "[LibraryCuratorLayout] applyPromptSelection " +
            "selectedPrompt=\(selectedPromptID ?? "nil") " +
            "visiblePromptChips=\(visiblePromptChips)"
        )
#endif
    }

    private func setupDelegates() {
        rootView.queryTextView.delegate = self
        rootView.modeCollectionView.dataSource = self
        rootView.modeCollectionView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.onTasteTagTapped = { [weak self] id in
            self?.viewModel.send(.tasteTagTapped(id))
        }
        rootView.analyzeButton.addTarget(self, action: #selector(didTapAnalyzeButton), for: .touchUpInside)
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
    private func didTapAnalyzeButton() {
        rootView.queryTextView.resignFirstResponder()
        viewModel.send(.analyzeTapped)
    }

    @objc
    private func didTapRetryButton() {
        viewModel.send(.retryTapped)
    }
}

extension LibraryCuratorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        viewModel.send(.queryChanged(textView.text ?? ""))
    }
}

extension LibraryCuratorViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        modes.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: LibraryCuratorModeChipCell.reuseId,
            for: indexPath
        ) as? LibraryCuratorModeChipCell else {
            return UICollectionViewCell()
        }
        let mode = modes[indexPath.item]
        cell.configure(
            id: mode.promptChipID,
            title: mode.localizedTitle,
            selected: mode.promptChipID == viewModel.state.selectedPromptChipID
        )
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < modes.count else { return }
        viewModel.send(.modeSelected(modes[indexPath.item]))
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let title = modes[indexPath.item].localizedTitle as NSString
        let width = title.size(withAttributes: [.font: UIFont.systemFont(ofSize: 13, weight: .semibold)]).width + 30
        return CGSize(width: min(max(width, 86), 190), height: 36)
    }
}

extension LibraryCuratorViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        L10n.tr("Localizable", "library_curator_result_title")
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: LibraryCuratorResultCell.reuseId,
            for: indexPath
        ) as? LibraryCuratorResultCell else {
            return UITableViewCell()
        }
        let item = sections[indexPath.section].items[indexPath.row]
        cell.configure(with: item, selectedGenreTagIDs: viewModel.state.selectedGenreTagIDs)
        cell.onFavoriteButtonTapped = { [weak self] in
            self?.viewModel.send(.favoriteTapped(item.gameId))
        }
        cell.onTagTapped = { [weak self] id in
            self?.viewModel.send(.genreTagTapped(id))
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel.send(.gameTapped(sections[indexPath.section].items[indexPath.row].gameId))
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        rootView.queryTextView.resignFirstResponder()
    }
}
