import UIKit

final class ProfileReviewsViewController: BaseViewController<ProfileReviewsRootView, ProfileReviewsState> {
    private let viewModel: ProfileReviewsViewModel
    private var items: [ReviewedGame] = []
    private var lastPresentedErrorMessage: String?

    var onReviewSelected: ((ReviewedGame) -> Void)?
    var onEditReviewSelected: ((ReviewedGame) -> Void)?

    init(rootView: ProfileReviewsRootView, viewModel: ProfileReviewsViewModel) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = L10n.tr("Localizable", "profile.reviews.title")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)
        bindViewModel()
        configureSortMenu(selected: viewModel.state.sortOption)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.refreshOnAppear()
    }

    func reload() {
        viewModel.reload()
    }

    override func render(_ state: ProfileReviewsState) {
        items = state.items
        rootView.render(state)
        configureSortMenu(selected: state.sortOption)
        rootView.tableView.reloadData()

        if let errorMessage = state.errorMessage,
           errorMessage != lastPresentedErrorMessage {
            lastPresentedErrorMessage = errorMessage
            let alertController = UIAlertController(title: L10n.Common.Error.title, message: errorMessage, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: L10n.Common.Button.confirm, style: .default))
            present(alertController, animated: true)
        } else if state.errorMessage == nil {
            lastPresentedErrorMessage = nil
        }
    }

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state)
            }
        }
        render(viewModel.state)
    }

    private func configureSortMenu(selected: ReviewSortOption) {
        let actions = ReviewSortOption.allCases.map { option in
            UIAction(
                title: option.profileDisplayTitle,
                state: option == selected ? .on : .off
            ) { [weak self] _ in
                self?.viewModel.updateSort(option)
            }
        }
        rootView.sortButton.menu = UIMenu(children: actions)
        rootView.sortButton.showsMenuAsPrimaryAction = true
        var configuration = rootView.sortButton.configuration
        configuration?.title = selected.profileDisplayTitle
        rootView.sortButton.configuration = configuration
    }

    @objc private func didTapRetry() {
        viewModel.reload()
    }

    private func presentReviewActionSheet(for review: ReviewedGame) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: L10n.Review.Action.edit, style: .default) { [weak self] _ in
            self?.onEditReviewSelected?(review)
        })
        alertController.addAction(UIAlertAction(title: L10n.Review.Action.delete, style: .destructive) { [weak self] _ in
            self?.presentDeleteConfirmationAlert(for: review)
        })
        alertController.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        present(alertController, animated: true)
    }

    private func presentDeleteConfirmationAlert(for review: ReviewedGame) {
        let alertController = UIAlertController(
            title: L10n.Review.Alert.deleteTitle,
            message: L10n.Review.Alert.deleteMessage,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        alertController.addAction(UIAlertAction(title: L10n.Review.Button.delete, style: .destructive) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.viewModel.delete(review: review)
            }
        })
        present(alertController, animated: true)
    }
}

extension ProfileReviewsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileReviewCell.reuseIdentifier, for: indexPath) as! ProfileReviewCell
        let item = items[indexPath.row]
        cell.configure(with: item, isDeleting: item.reviewId == viewModel.state.deletingReviewId)
        cell.onMoreTapped = { [weak self] in
            self?.presentReviewActionSheet(for: item)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard items.indices.contains(indexPath.row) else { return }
        onReviewSelected?(items[indexPath.row])
    }
}

final class ProfileReviewsRootView: UIView {
    let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .gpBackground
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 112
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

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

    func render(_ state: ProfileReviewsState) {
        countLabel.text = state.reviewCountText
        tableView.isHidden = state.isEmpty || state.errorMessage != nil
        emptyLabel.text = state.errorMessage ?? L10n.tr("Localizable", "profile.reviews.empty")
        emptyLabel.isHidden = !state.isEmpty && state.errorMessage == nil
        retryButton.isHidden = state.errorMessage == nil
        if state.isLoading {
            loadingIndicatorView.startAnimating()
        } else {
            loadingIndicatorView.stopAnimating()
        }
    }

    private func setup() {
        backgroundColor = .gpBackground
        tableView.register(ProfileReviewCell.self, forCellReuseIdentifier: ProfileReviewCell.reuseIdentifier)

        let headerStackView = UIStackView(arrangedSubviews: [countLabel, UIView(), sortButton])
        headerStackView.axis = .horizontal
        headerStackView.alignment = .center
        headerStackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(headerStackView)
        addSubview(tableView)
        addSubview(emptyLabel)
        addSubview(retryButton)
        addSubview(loadingIndicatorView)

        NSLayoutConstraint.activate([
            headerStackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            headerStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            headerStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: headerStackView.bottomAnchor, constant: 10),
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

private final class ProfileReviewCell: UITableViewCell {
    static let reuseIdentifier = "ProfileReviewCell"

    var onMoreTapped: (() -> Void)?

    private let coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10
        imageView.layer.cornerCurve = .continuous
        imageView.backgroundColor = .gpSurfaceElevated
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        return label
    }()

    private let starView = StarRatingView()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .gpTextTertiary
        return label
    }()

    private let snippetLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        return label
    }()

    private let moreButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: "ellipsis",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        )
        configuration.baseForegroundColor = .gpTextTertiary
        configuration.contentInsets = .zero
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

    func configure(with item: ReviewedGame, isDeleting: Bool) {
        coverImageView.loadImage(url: item.game.coverImageURL)
        titleLabel.text = item.game.displayTitle
        starView.configure(rating: item.rating)
        dateLabel.text = item.createdAt.toAbsoluteDateString()
        snippetLabel.text = item.contentPreview
        moreButton.isEnabled = !isDeleting
        contentView.alpha = isDeleting ? 0.6 : 1.0
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        coverImageView.cancelLoad()
        coverImageView.image = nil
        onMoreTapped = nil
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        let cardView = UIView()
        cardView.backgroundColor = .gpCardBackground
        cardView.layer.cornerRadius = 18
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.gpSeparator.cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, moreButton])
        titleRow.axis = .horizontal
        titleRow.alignment = .top
        titleRow.spacing = 8

        let metaRow = UIStackView(arrangedSubviews: [starView, dateLabel])
        metaRow.axis = .horizontal
        metaRow.alignment = .center
        metaRow.spacing = 8

        let textStackView = UIStackView(arrangedSubviews: [titleRow, metaRow, snippetLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 6
        textStackView.translatesAutoresizingMaskIntoConstraints = false

        let contentStackView = UIStackView(arrangedSubviews: [coverImageView, textStackView])
        contentStackView.axis = .horizontal
        contentStackView.alignment = .top
        contentStackView.spacing = 14
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        cardView.addSubview(contentStackView)
        moreButton.addTarget(self, action: #selector(didTapMore), for: .touchUpInside)

        NSLayoutConstraint.activate([
            coverImageView.widthAnchor.constraint(equalToConstant: 64),
            coverImageView.heightAnchor.constraint(equalToConstant: 82),
            moreButton.widthAnchor.constraint(equalToConstant: 24),
            moreButton.heightAnchor.constraint(equalToConstant: 24),

            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),

            contentStackView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            contentStackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            contentStackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            contentStackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14)
        ])
    }

    @objc private func didTapMore() {
        onMoreTapped?()
    }
}

private extension ReviewSortOption {
    var profileDisplayTitle: String {
        switch self {
        case .latest:
            return L10n.tr("Localizable", "profile.reviews.sort.latest")
        case .oldest:
            return L10n.tr("Localizable", "profile.reviews.sort.oldest")
        case .ratingDescending:
            return L10n.tr("Localizable", "profile.reviews.sort.ratingDescending")
        case .ratingAscending:
            return L10n.tr("Localizable", "profile.reviews.sort.ratingAscending")
        }
    }
}
