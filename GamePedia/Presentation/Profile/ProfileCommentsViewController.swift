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
        bindViewModel()
        viewModel.loadIfNeeded()
    }

    override func render(_ state: ProfileCommentsState) {
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
        render(viewModel.state)
    }

    @objc private func didTapRetry() {
        viewModel.reload()
    }
}

extension ProfileCommentsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileCommentCell.reuseIdentifier, for: indexPath) as! ProfileCommentCell
        cell.configure(with: items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onCommentSelected?(items[indexPath.row])
    }
}

final class ProfileCommentsRootView: UIView {
    let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .gpBackground
        tableView.separatorStyle = .none
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
        tableView.isHidden = state.isEmpty || state.errorMessage != nil
        emptyLabel.text = state.errorMessage ?? L10n.tr("Localizable", "profile.comments.empty")
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
        tableView.register(ProfileCommentCell.self, forCellReuseIdentifier: ProfileCommentCell.reuseIdentifier)
        addSubview(tableView)
        addSubview(emptyLabel)
        addSubview(retryButton)
        addSubview(loadingIndicatorView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(with item: MyReviewCommentEntry) {
        gameLabel.text = item.gameTitle
        reviewSnippetLabel.text = item.reviewSnippet
        commentLabel.text = item.commentContent
        metaLabel.text = L10n.tr(
            "Localizable",
            "profile.comments.meta",
            item.formattedDate,
            String(item.likeCount),
            String(item.dislikeCount)
        )
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

        let stackView = UIStackView(arrangedSubviews: [gameLabel, reviewSnippetLabel, commentLabel, metaLabel])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        cardView.addSubview(stackView)

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
}
