import UIKit

final class ProfileCommentsViewController: BaseViewController<ProfileCommentsRootView, ProfileCommentsState> {
    private let viewModel: ProfileCommentsViewModel
    private var items: [MyReviewCommentEntry] = []

    var onCommentSelected: ((MyReviewCommentEntry) -> Void)?

    init(rootView: ProfileCommentsRootView, viewModel: ProfileCommentsViewModel) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = L10n.tr("Localizable", "profile.comments.title")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)
        configureSortMenu(selected: viewModel.state.sortOption)
        bindViewModel()
        viewModel.loadIfNeeded()
    }

    override func render(_ state: ProfileCommentsState) {
        items = state.items
        rootView.render(state)
        configureSortMenu(selected: state.sortOption)
        rootView.tableView.reloadData()
    }

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state)
            }
        }
        render(viewModel.state)
    }

    @objc private func didTapRetry() {
        viewModel.reload()
    }

    private func configureSortMenu(selected: ReviewCommentSortOption) {
        let actions = ReviewCommentSortOption.allCases.map { option in
            UIAction(title: option.displayTitle, state: option == selected ? .on : .off) { [weak self] _ in
                self?.viewModel.updateSort(option)
            }
        }
        rootView.sortButton.menu = UIMenu(children: actions)
        rootView.sortButton.showsMenuAsPrimaryAction = true
        var configuration = rootView.sortButton.configuration
        configuration?.title = selected.displayTitle
        rootView.sortButton.configuration = configuration
    }
}

extension ProfileCommentsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileCommentCell.reuseIdentifier, for: indexPath) as! ProfileCommentCell
        let item = items[indexPath.row]
        cell.configure(with: item, isReactionLoading: viewModel.state.reactingCommentIds.contains(item.id))
        cell.onLikeTapped = { [weak self] in
            self?.viewModel.toggleLike(commentId: item.id)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onCommentSelected?(items[indexPath.row])
    }
}

final class ProfileCommentsRootView: UIView {
    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextSecondary
        return label
    }()

    let sortButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = .gpTextSecondary
        configuration.image = UIImage(
            systemName: "chevron.down",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        )
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 4
        configuration.contentInsets = .zero
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = .systemFont(ofSize: 12, weight: .medium)
            return updated
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .gpBackground
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 128
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .gpTextSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let loadingIndicatorView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.color = .gpPrimary
        view.hidesWhenStopped = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let retryButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = L10n.Common.Button.retry
        configuration.baseForegroundColor = .gpPrimary
        let button = UIButton(configuration: configuration)
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func render(_ state: ProfileCommentsState) {
        countLabel.text = state.countText
        tableView.isHidden = state.isEmpty || state.errorMessage != nil
        emptyLabel.text = state.errorMessage ?? L10n.tr("Localizable", "profile.comments.empty")
        emptyLabel.isHidden = !state.isEmpty && state.errorMessage == nil
        retryButton.isHidden = state.errorMessage == nil
        sortButton.isHidden = state.isEmpty || state.errorMessage != nil
        if state.isLoading {
            loadingIndicatorView.startAnimating()
        } else {
            loadingIndicatorView.stopAnimating()
        }
    }

    private func setup() {
        backgroundColor = .gpBackground
        tableView.register(ProfileCommentCell.self, forCellReuseIdentifier: ProfileCommentCell.reuseIdentifier)
        let headerStack = UIStackView(arrangedSubviews: [countLabel, UIView(), sortButton])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(headerStack)
        addSubview(tableView)
        addSubview(emptyLabel)
        addSubview(retryButton)
        addSubview(loadingIndicatorView)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),

            retryButton.topAnchor.constraint(equalTo: emptyLabel.bottomAnchor, constant: 12),
            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor),

            loadingIndicatorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicatorView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

private final class ProfileCommentCell: UITableViewCell {
    static let reuseIdentifier = "ProfileCommentCell"

    var onLikeTapped: (() -> Void)?

    private let gameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .gpPrimaryLight
        return label
    }()

    private let reviewSnippetLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        return label
    }()

    private let commentLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 0
        return label
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .gpTextTertiary
        return label
    }()

    private let likeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
        configuration.imagePadding = 4
        configuration.baseForegroundColor = .gpTextTertiary
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(with item: MyReviewCommentEntry, isReactionLoading: Bool) {
        gameLabel.text = item.gameTitle
        reviewSnippetLabel.text = item.reviewSnippet
        commentLabel.text = item.commentContent
        metaLabel.text = item.formattedDate

        let isLiked = item.myReaction == .like
        var configuration = likeButton.configuration
        configuration?.title = String(item.likeCount)
        configuration?.image = UIImage(
            systemName: isLiked ? "heart.fill" : "heart",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        )
        configuration?.baseForegroundColor = isLiked ? .gpCoral : .gpTextTertiary
        likeButton.configuration = configuration
        likeButton.isEnabled = !isReactionLoading && !item.isDeleted
        likeButton.alpha = item.likeCount == 0 && !isLiked ? 0.72 : 1
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        let cardView = UIView()
        cardView.backgroundColor = .gpCardBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.cornerCurve = .continuous
        cardView.translatesAutoresizingMaskIntoConstraints = false

        let metaRow = UIStackView(arrangedSubviews: [metaLabel, UIView(), likeButton])
        metaRow.axis = .horizontal
        metaRow.alignment = .center
        metaRow.spacing = 8

        let stackView = UIStackView(arrangedSubviews: [gameLabel, reviewSnippetLabel, commentLabel, metaRow])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        cardView.addSubview(stackView)
        likeButton.addTarget(self, action: #selector(didTapLike), for: .touchUpInside)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            stackView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            stackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            stackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            stackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onLikeTapped = nil
    }

    @objc private func didTapLike() {
        onLikeTapped?()
    }
}
