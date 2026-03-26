import UIKit

// MARK: - SearchViewController

final class SearchViewController: BaseViewController<SearchRootView, SearchState> {

    // MARK: Properties
    private let viewModel: SearchViewModel
    private var genres: [String] = []
    private var selectedGenre: String = ""
    private var results: [Game] = []

    // Set by SearchCoordinator.
    var onGameSelected: ((Int) -> Void)?

    // MARK: Init
    init(
        rootView: SearchRootView,
        viewModel: SearchViewModel = SearchViewModel()
    ) {
        self.viewModel = viewModel
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    // MARK: Setup

    private func configureNavigationItem() {
        UIView.performWithoutAnimation {
            navigationItem.title = "검색"
            navigationItem.largeTitleDisplayMode = .never
        }
    }

    private func setupDelegates() {
        rootView.searchTextField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        rootView.searchTextField.delegate = self
        rootView.clearButton.addTarget(self, action: #selector(didTapClearButton), for: .touchUpInside)

        rootView.genreCollectionView.dataSource = self
        rootView.genreCollectionView.delegate = self

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
    }

    override func render(_ state: SearchState) {
        // Base state rendering (clear button visibility, search indicator, etc.)
        rootView.render(state)

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
        if selectedGenre == "전체" || selectedGenre.isEmpty {
            results = state.results
        } else {
            results = state.results.filter {
                $0.genre.localizedCaseInsensitiveContains(selectedGenre)
            }
        }

        // Override the count label to reflect the client-filtered count.
        if !state.query.isEmpty {
            rootView.resultCountLabel.isHidden = false
            rootView.resultCountLabel.text = "검색 결과 \(results.count)건"
        }

        // Sync empty state with the filtered result set.
        let filteredEmpty = !state.query.isEmpty && results.isEmpty
        rootView.emptyStateView.isHidden = !filteredEmpty
        rootView.tableView.isHidden = filteredEmpty

        rootView.tableView.reloadData()
    }

    // MARK: Actions

    @objc private func textFieldChanged(_ tf: UITextField) {
        let query = tf.text ?? ""
        if query.isEmpty {
            viewModel.send(.queryCleared)
        } else {
            viewModel.send(.queryChanged(query))
        }
    }

    @objc private func didTapClearButton() {
        rootView.searchTextField.text = ""
        rootView.searchTextField.layer.borderWidth = 0
        viewModel.send(.queryCleared)
    }

    @objc private func dismissKeyboard() {
        rootView.searchTextField.resignFirstResponder()
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
        let resolvedTitle = viewModel.state.resolvedTitle(for: game)
        let resolvedSummary = viewModel.state.resolvedSummary(for: game)
        print("[UI] rendered resolvedTitle:", resolvedTitle)
        print("[UI] rendered resolvedSummary:", resolvedSummary ?? "")
        cell.configure(with: game, resolvedTitle: resolvedTitle, resolvedSummary: resolvedSummary)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let game = results[indexPath.row]
        viewModel.send(.didTapGame(id: game.id))
        onGameSelected?(game.id)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        rootView.searchTextField.resignFirstResponder()
    }
}
