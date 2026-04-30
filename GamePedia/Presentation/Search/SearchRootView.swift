import UIKit

// MARK: - SearchRootView

final class SearchRootView: UIView {

    // MARK: Subviews

    let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .gpBackground
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    let searchTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = L10n.Search.placeholder
        textField.textColor = .gpTextPrimary
        textField.font = .systemFont(ofSize: 15)
        textField.backgroundColor = .gpSurface
        textField.layer.cornerRadius = 14
        textField.returnKeyType = .search
        textField.tintColor = .gpPrimary

        let leftContainerView = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 48))
        let iconImageView = UIImageView(
            image: UIImage(
                systemName: "magnifyingglass",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
            )
        )
        iconImageView.tintColor = .gpPrimary
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.frame = CGRect(x: 14, y: 14, width: 20, height: 20)
        leftContainerView.addSubview(iconImageView)
        textField.leftView = leftContainerView
        textField.leftViewMode = .always

        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    let clearButton: UIButton = {
        let button = UIButton(type: .custom)
        let configuration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: configuration), for: .normal)
        button.tintColor = .gpTextSecondary
        return button
    }()

    let genreCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    let resultCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let aiSearchAssistView: AISearchAssistView = {
        let view = AISearchAssistView()
        view.isHidden = true
        return view
    }()

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .gpBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = SearchResultCell.height
        tableView.isScrollEnabled = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    let emptyStateView: EmptyStateView = {
        let emptyStateView = EmptyStateView()
        emptyStateView.isHidden = true
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        return emptyStateView
    }()

    let activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.color = .gpTextSecondary
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()

    private let contentView = UIView()
    private let contentStackView = UIStackView()
    private let searchContainerView = UIView()
    private let aiSearchAssistContainerView = UIView()
    private let resultCountContainerView = UIView()
    private let tableContainerView = UIView()
    private let emptyStateContainerView = UIView()
    private var tableHeightConstraint: NSLayoutConstraint?
    private var scrollViewBottomInset: CGFloat = Layout.minimumBottomInset

    private enum Layout {
        static let horizontalMargin: CGFloat = 20
        static let contentBottomSpacing: CGFloat = 32
        static let minimumBottomInset: CGFloat = 32
    }

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: Setup

    private func setup() {
        backgroundColor = .gpBackground

        let clearContainerView = UIView(frame: CGRect(x: 0, y: 0, width: 36, height: 48))
        clearButton.frame = CGRect(x: 4, y: 14, width: 18, height: 20)
        clearContainerView.addSubview(clearButton)
        searchTextField.rightView = clearContainerView
        searchTextField.rightViewMode = .never

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 10
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        [searchContainerView, aiSearchAssistContainerView, resultCountContainerView, tableContainerView, emptyStateContainerView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        genreCollectionView.register(GenreChipCell.self, forCellWithReuseIdentifier: GenreChipCell.reuseId)
        tableView.register(SearchResultCell.self, forCellReuseIdentifier: SearchResultCell.reuseId)

        emptyStateView.configure(icon: "magnifyingglass", message: L10n.Search.Empty.noResults)

        addSubview(scrollView)
        addSubview(activityIndicator)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStackView)

        searchContainerView.addSubview(searchTextField)
        aiSearchAssistContainerView.addSubview(aiSearchAssistView)
        resultCountContainerView.addSubview(resultCountLabel)
        tableContainerView.addSubview(tableView)
        emptyStateContainerView.addSubview(emptyStateView)

        [
            searchContainerView,
            genreCollectionView,
            aiSearchAssistContainerView,
            resultCountContainerView,
            tableContainerView,
            emptyStateContainerView
        ].forEach {
            contentStackView.addArrangedSubview($0)
        }

        aiSearchAssistContainerView.isHidden = true
        resultCountContainerView.isHidden = true
        tableContainerView.isHidden = true
        emptyStateContainerView.isHidden = true

        let tableHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 0)
        self.tableHeightConstraint = tableHeightConstraint

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Layout.contentBottomSpacing),

            searchTextField.topAnchor.constraint(equalTo: searchContainerView.topAnchor),
            searchTextField.leadingAnchor.constraint(equalTo: searchContainerView.leadingAnchor, constant: Layout.horizontalMargin),
            searchTextField.trailingAnchor.constraint(equalTo: searchContainerView.trailingAnchor, constant: -Layout.horizontalMargin),
            searchTextField.bottomAnchor.constraint(equalTo: searchContainerView.bottomAnchor),
            searchTextField.heightAnchor.constraint(equalToConstant: 48),

            genreCollectionView.heightAnchor.constraint(equalToConstant: 36),

            aiSearchAssistView.topAnchor.constraint(equalTo: aiSearchAssistContainerView.topAnchor, constant: 2),
            aiSearchAssistView.leadingAnchor.constraint(equalTo: aiSearchAssistContainerView.leadingAnchor, constant: Layout.horizontalMargin),
            aiSearchAssistView.trailingAnchor.constraint(equalTo: aiSearchAssistContainerView.trailingAnchor, constant: -Layout.horizontalMargin),
            aiSearchAssistView.bottomAnchor.constraint(equalTo: aiSearchAssistContainerView.bottomAnchor, constant: -2),

            resultCountLabel.topAnchor.constraint(equalTo: resultCountContainerView.topAnchor, constant: 2),
            resultCountLabel.leadingAnchor.constraint(equalTo: resultCountContainerView.leadingAnchor, constant: Layout.horizontalMargin),
            resultCountLabel.trailingAnchor.constraint(lessThanOrEqualTo: resultCountContainerView.trailingAnchor, constant: -Layout.horizontalMargin),
            resultCountLabel.bottomAnchor.constraint(equalTo: resultCountContainerView.bottomAnchor, constant: -2),

            tableView.topAnchor.constraint(equalTo: tableContainerView.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: tableContainerView.leadingAnchor, constant: Layout.horizontalMargin),
            tableView.trailingAnchor.constraint(equalTo: tableContainerView.trailingAnchor, constant: -Layout.horizontalMargin),
            tableView.bottomAnchor.constraint(equalTo: tableContainerView.bottomAnchor),
            tableHeightConstraint,

            emptyStateContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),
            emptyStateView.centerXAnchor.constraint(equalTo: emptyStateContainerView.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: emptyStateContainerView.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: emptyStateContainerView.leadingAnchor, constant: Layout.horizontalMargin),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: emptyStateContainerView.trailingAnchor, constant: -Layout.horizontalMargin),

            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateScrollBottomInset(max(Layout.minimumBottomInset, safeAreaInsets.bottom + Layout.contentBottomSpacing))
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateScrollBottomInset(max(Layout.minimumBottomInset, safeAreaInsets.bottom + Layout.contentBottomSpacing))
    }

    // MARK: - State Rendering

    func render(_ state: SearchState, hasAISearchAssistResults: Bool = false) {
        searchTextField.rightViewMode = state.query.isEmpty ? .never : .always

        if !state.query.isEmpty {
            resultCountLabel.text = L10n.Search.Count.results(state.resultCount)
        }
        resultCountContainerView.isHidden = state.query.isEmpty

        let shouldShowEmptyResult = state.showEmptyResult && !hasAISearchAssistResults
        emptyStateContainerView.isHidden = !shouldShowEmptyResult
        emptyStateView.isHidden = !shouldShowEmptyResult
        tableContainerView.isHidden = shouldShowEmptyResult || state.resultCount == 0
        updateSearchResultsTableHeight(resultCount: state.resultCount)

        if state.isSearching {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    func renderAISearchAssist(_ state: AISearchAssistState) {
        aiSearchAssistContainerView.isHidden = !state.shouldShowSection
        aiSearchAssistView.render(state)
        setNeedsLayout()
        layoutIfNeeded()
    }

    func updateSearchResultVisibility(
        queryIsEmpty: Bool,
        hasSearchResults: Bool,
        hasAISearchAssistResults: Bool
    ) {
        let shouldShowEmptyResult = !queryIsEmpty && !hasSearchResults && !hasAISearchAssistResults
        emptyStateContainerView.isHidden = !shouldShowEmptyResult
        emptyStateView.isHidden = !shouldShowEmptyResult
        tableContainerView.isHidden = !hasSearchResults || shouldShowEmptyResult
        resultCountContainerView.isHidden = queryIsEmpty || (!hasSearchResults && hasAISearchAssistResults)
        aiSearchAssistView.setShowsNoSearchResultsNotice(!queryIsEmpty && !hasSearchResults && hasAISearchAssistResults)
        updateSearchResultsTableHeight(resultCount: hasSearchResults ? Int(tableView.numberOfRows(inSection: 0)) : 0)
    }

    func updateSearchResultsTableHeight(resultCount: Int) {
        let tableHeight = CGFloat(resultCount) * SearchResultCell.height
        guard abs((tableHeightConstraint?.constant ?? 0) - tableHeight) > 0.5 else { return }
        tableHeightConstraint?.constant = tableHeight
    }

    func updateScrollBottomInset(_ bottomInset: CGFloat) {
        let resolvedBottomInset = max(Layout.minimumBottomInset, bottomInset)
        guard abs(scrollViewBottomInset - resolvedBottomInset) > 0.5 else { return }

        scrollViewBottomInset = resolvedBottomInset
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: resolvedBottomInset, right: 0)
        scrollView.verticalScrollIndicatorInsets.bottom = resolvedBottomInset
    }
}
