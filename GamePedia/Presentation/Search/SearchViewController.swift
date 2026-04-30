import UIKit

// MARK: - SearchViewController

final class SearchViewController: BaseViewController<SearchRootView, SearchState> {

    // MARK: Properties
    private let viewModel: SearchViewModel
    private let aiSearchAssistViewModel: AISearchAssistViewModel
    private var genres: [String] = []
    private var selectedGenre: String = ""
    private var results: [Game] = []
    private var latestAISearchAssistState = AISearchAssistState()

    // Set by SearchCoordinator.
    var onGameSelected: ((Int) -> Void)?
    var onAIRecommendationRequested: (() -> Void)?
    var onAuthenticationRequired: ((RestrictedActionContext, @escaping () -> Void) -> Void)?

    // MARK: Init
    init(
        rootView: SearchRootView,
        viewModel: SearchViewModel = SearchViewModel(),
        aiSearchAssistViewModel: AISearchAssistViewModel = AISearchAssistViewModel()
    ) {
        self.viewModel = viewModel
        self.aiSearchAssistViewModel = aiSearchAssistViewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        configureNavigationItem()
    }

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        //rootView.setUsesNavigationTitle(true)
        setupDelegates()
        setupKeyboardDismissal()
        bindViewModel()
        viewModel.send(.viewDidLoad)
        aiSearchAssistViewModel.send(.viewDidLoad)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        rootView.updateSearchResultsTableHeight(resultCount: results.count)
        rootView.updateScrollBottomInset(resolvedBottomScrollInset())
    }

    deinit {
        aiSearchAssistViewModel.cancelInFlightRequest()
    }

    // MARK: Setup

    private func configureNavigationItem() {
        UIView.performWithoutAnimation {
            navigationItem.title = L10n.Search.Tab.title
            navigationItem.largeTitleDisplayMode = .never
            let aiRecommendationButton = UIBarButtonItem(
                image: UIImage(systemName: "sparkles") ?? UIImage(systemName: "wand.and.stars"),
                style: .plain,
                target: self,
                action: #selector(didTapAIRecommendationButton)
            )
            aiRecommendationButton.accessibilityLabel = "AI 게임 추천"
            aiRecommendationButton.tintColor = .gpPrimary
            navigationItem.rightBarButtonItem = aiRecommendationButton
        }
    }

    private func setupDelegates() {
        rootView.searchTextField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        rootView.searchTextField.delegate = self
        rootView.clearButton.addTarget(self, action: #selector(didTapClearButton), for: .touchUpInside)
        rootView.aiSearchAssistView.assistButton.addTarget(self, action: #selector(didTapAISearchAssistButton), for: .touchUpInside)
        rootView.aiSearchAssistView.retryButton.addTarget(self, action: #selector(didTapAISearchAssistRetryButton), for: .touchUpInside)
        rootView.aiSearchAssistView.onSuggestedQueryTapped = { [weak self] query in
            self?.applySuggestedQuery(query)
        }
        rootView.aiSearchAssistView.onItemTapped = { [weak self] gameId in
            self?.aiSearchAssistViewModel.send(.itemTapped(gameId: gameId))
        }

        rootView.genreCollectionView.dataSource = self
        rootView.genreCollectionView.delegate = self
        rootView.scrollView.delegate = self

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }

    private func setupKeyboardDismissal() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        rootView.addGestureRecognizer(tap)
    }

    // MARK: ViewModel Binding

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state)
            }
        }
        aiSearchAssistViewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.latestAISearchAssistState = state
                self?.rootView.renderAISearchAssist(state)
                self?.updateSearchResultVisibility()
            }
        }
        aiSearchAssistViewModel.onRouteToGameDetail = { [weak self] gameId in
            self?.onGameSelected?(gameId)
        }
        aiSearchAssistViewModel.onAuthenticationRequired = { [weak self] context, action in
            self?.onAuthenticationRequired?(context, action)
        }
    }

    override func render(_ state: SearchState) {
        // Base state rendering (clear button visibility, search indicator, etc.)
        rootView.render(state, hasAISearchAssistResults: latestAISearchAssistState.hasResults)

        // Track genre selection changes reliably with a local variable.
        // (viewModel.state is already the new state when this fires, so comparing
        //  against it would always be equal — local var detects the delta.)
        let genresChanged = genres != state.genres
        let selectionChanged = selectedGenre != state.selectedGenre
        genres = state.genres
        selectedGenre = state.selectedGenre

        if genresChanged || selectionChanged {
            rootView.genreCollectionView.reloadData()
        }

        // Client-side genre filter applied on top of API results.
        // Covers the case where the backend does not support genre filtering.
        if selectedGenre == L10n.Search.Filter.all || selectedGenre.isEmpty {
            results = state.results
        } else {
            results = state.results.filter {
                $0.genre.localizedCaseInsensitiveContains(selectedGenre)
            }
        }
        GameDetailSeedStore.shared.store(games: results, screen: "Search.render")

        // Override the count label to reflect the client-filtered count.
        if !state.query.isEmpty {
            rootView.resultCountLabel.isHidden = false
            rootView.resultCountLabel.text = L10n.Search.Count.results(results.count)
        }

        // Sync empty state with the filtered result set.
        updateSearchResultVisibility()

        rootView.tableView.reloadData()
        rootView.updateSearchResultsTableHeight(resultCount: results.count)
    }

    // MARK: Actions

    @objc private func textFieldChanged(_ tf: UITextField) {
        let query = tf.text ?? ""
        if query.isEmpty {
            viewModel.send(.queryCleared)
        } else {
            viewModel.send(.queryChanged(query))
        }
        aiSearchAssistViewModel.send(.queryChanged(query))
    }

    @objc private func didTapClearButton() {
        rootView.searchTextField.text = ""
        rootView.searchTextField.layer.borderWidth = 0
        viewModel.send(.queryCleared)
        aiSearchAssistViewModel.send(.queryChanged(""))
    }

    @objc private func dismissKeyboard() {
        rootView.searchTextField.resignFirstResponder()
    }

    @objc private func didTapAIRecommendationButton() {
        onAIRecommendationRequested?()
    }

    @objc private func didTapAISearchAssistButton() {
        rootView.searchTextField.resignFirstResponder()
        aiSearchAssistViewModel.send(.aiAssistTapped)
    }

    @objc private func didTapAISearchAssistRetryButton() {
        aiSearchAssistViewModel.send(.retryTapped)
    }

    private func applySuggestedQuery(_ query: String) {
        rootView.searchTextField.text = query
        viewModel.send(.queryChanged(query))
        aiSearchAssistViewModel.send(.suggestedQueryTapped(query))
    }

    private func updateSearchResultVisibility() {
        let queryIsEmpty = viewModel.state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        rootView.updateSearchResultVisibility(
            queryIsEmpty: queryIsEmpty,
            hasSearchResults: !results.isEmpty,
            hasAISearchAssistResults: latestAISearchAssistState.hasResults
        )
    }

    private func resolvedBottomScrollInset() -> CGFloat {
        let safeAreaBottom = view.safeAreaInsets.bottom
        let tabBarOverlap = visibleTabBarOverlapHeight()
        let buildBadgeOverlap: CGFloat = AppConfig.shouldShowBuildIndicator ? 34 : 0
        let breathingRoom: CGFloat = 40
        return max(safeAreaBottom, tabBarOverlap + buildBadgeOverlap) + breathingRoom
    }

    private func visibleTabBarOverlapHeight() -> CGFloat {
        guard let tabBar = tabBarController?.tabBar,
              !tabBar.isHidden,
              tabBar.alpha > 0.01,
              let containerView = tabBar.superview else {
            return 0
        }

        let convertedFrame = view.convert(tabBar.frame, from: containerView)
        let overlap = view.bounds.intersection(convertedFrame)
        guard !overlap.isNull else { return 0 }
        return overlap.height
    }
}

// MARK: - UITextFieldDelegate

extension SearchViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.layer.borderWidth = 1.5
        textField.layer.borderColor = UIColor.gpPrimary.cgColor
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.text?.isEmpty ?? true {
            textField.layer.borderWidth = 0
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        aiSearchAssistViewModel.send(.searchSubmitted)
        return true
    }
}

// MARK: - Genre CollectionView

extension SearchViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        genres.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GenreChipCell.reuseId, for: indexPath) as! GenreChipCell
        let genre = genres[indexPath.item]
        cell.configure(genre: genre, isSelected: genre == selectedGenre)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        viewModel.send(.genreSelected(genres[indexPath.item]))
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let genre = genres[indexPath.item]
        return CGSize(width: GenreChipCell.estimatedWidth(for: genre), height: 36)
    }
}

// MARK: - Results TableView

extension SearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SearchResultCell.reuseId, for: indexPath) as! SearchResultCell
        let game = results[indexPath.row]
        cell.configure(with: game, resolvedTitle: game.resolvedTitle, resolvedSummary: game.resolvedSummary)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let game = results[indexPath.row]
        GameDetailSeedStore.shared.store(games: [game], screen: "Search.tap")
        viewModel.send(.didTapGame(id: game.id))
        onGameSelected?(game.id)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        rootView.searchTextField.resignFirstResponder()
    }
}
