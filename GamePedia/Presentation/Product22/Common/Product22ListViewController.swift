import Kingfisher
import UIKit

// MARK: - Product22ListSection
//
// The shape every Product 2.2 detail screen renders. Keeping one shape means
// the loading, empty, error and stale states are written once and behave
// identically everywhere, rather than each screen inventing its own.

struct Product22ListSection: Hashable {
    let id: String
    let title: String?
    let rows: [Product22ListRow]
}

struct Product22ListRow: Hashable {
    let id: String
    /// Server content where it exists — a game title, a headline. Not
    /// localized, not reformatted.
    let title: String
    let subtitle: String?
    let details: [String]
    /// Nil when the row is informational. A row with no action is not
    /// presented as tappable.
    let actionTitle: String?
    let accessibilityLabel: String

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        details: [String] = [],
        actionTitle: String? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.details = details
        self.actionTitle = actionTitle
        self.accessibilityLabel = accessibilityLabel
            ?? ([title, subtitle].compactMap { $0 } + details).joined(separator: ", ")
    }
}

// MARK: - Product22ListState

enum Product22ListState: Equatable {
    case loading
    case loaded([Product22ListSection])
    /// Nothing to show, but nothing went wrong.
    case empty(message: String)
    /// The feature's kill switch is off. Never retryable.
    case disabled(message: String)
    /// It failed. Retryable.
    case failed(message: String)
}

// MARK: - Product22ListViewController
//
// A table-backed list with pull-to-refresh and the five states above.
//
// Subclasses override `loadContent()` and return a state. Everything else —
// cancellation of a superseded load, discarding a response that outlived its
// request, refresh control lifecycle — is handled here so no screen has to get
// it right individually.

class Product22ListViewController: UIViewController {

    // MARK: Views

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let refreshControl = UIRefreshControl()
    private let statusLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let statusStack = UIStackView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    // MARK: State

    private var sections: [Product22ListSection] = []
    private var loadTask: Task<Void, Never>?
    /// Monotonic; a response whose token is no longer the newest is discarded
    /// rather than rendered, so a slow earlier load cannot replace a faster
    /// later one.
    private var loadToken: UInt64 = 0

    deinit { loadTask?.cancel() }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gpBackground
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpTextSecondary)
        setupViews()
        reload()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Decoded images are the largest thing a Product 2.2 screen holds, and
        // the cheapest to rebuild. The list content itself is kept.
        KingfisherManager.shared.cache.clearMemoryCache()
    }

    private func setupViews() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .gpBackground
        tableView.separatorColor = .gpSeparator
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.register(Product22ListCell.self, forCellReuseIdentifier: Product22ListCell.reuseId)
        refreshControl.addTarget(self, action: #selector(pulledToRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
        view.addSubview(tableView)

        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .gpTextSecondary
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center

        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        retryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        retryButton.setTitle(L10n.Common.Button.retry, for: .normal)
        retryButton.setTitleColor(.gpPrimary, for: .normal)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        statusStack.axis = .vertical
        statusStack.spacing = 12
        statusStack.alignment = .center
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusStack.addArrangedSubview(statusLabel)
        statusStack.addArrangedSubview(retryButton)
        statusStack.isHidden = true
        view.addSubview(statusStack)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            statusStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: Subclass hooks

    /// Produce the screen's content. Called on a background task; never call
    /// it directly — use `reload()`.
    func loadContent() async -> Product22ListState {
        .empty(message: L10n.Common.State.empty)
    }

    /// Called when a row with an `actionTitle` is selected.
    func didSelectRow(_ row: Product22ListRow, in section: Product22ListSection) {}

    // MARK: Loading

    final func reload() {
        loadTask?.cancel()
        loadToken &+= 1
        let token = loadToken

        if sections.isEmpty && !refreshControl.isRefreshing {
            activityIndicator.startAnimating()
            statusStack.isHidden = true
        }

        loadTask = Task { [weak self] in
            guard let self else { return }
            let state = await self.loadContent()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                // Discard anything that is no longer the newest request.
                guard token == self.loadToken else { return }
                self.apply(state)
            }
        }
    }

    @MainActor
    private func apply(_ state: Product22ListState) {
        activityIndicator.stopAnimating()
        refreshControl.endRefreshing()

        switch state {
        case .loading:
            activityIndicator.startAnimating()

        case .loaded(let sections):
            self.sections = sections
            statusStack.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()

        case .empty(let message):
            sections = []
            tableView.reloadData()
            show(message: message, showsRetry: false)

        case .disabled(let message):
            // A kill switch is never retryable.
            sections = []
            tableView.reloadData()
            show(message: message, showsRetry: false)

        case .failed(let message):
            sections = []
            tableView.reloadData()
            show(message: message, showsRetry: true)
        }
    }

    private func show(message: String, showsRetry: Bool) {
        statusLabel.text = message
        retryButton.isHidden = !showsRetry
        statusStack.isHidden = false
        tableView.isHidden = true
    }

    @objc private func pulledToRefresh() { reload() }
    @objc private func retryTapped() { reload() }
}

// MARK: - UITableViewDataSource / Delegate

extension Product22ListViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: Product22ListCell.reuseId, for: indexPath
        ) as! Product22ListCell
        cell.configure(with: sections[indexPath.section].rows[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let section = sections[indexPath.section]
        let row = section.rows[indexPath.row]
        guard row.actionTitle != nil else { return }
        didSelectRow(row, in: section)
    }
}

// MARK: - Product22ListCell

final class Product22ListCell: UITableViewCell {

    static let reuseId = "Product22ListCell"

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let detailStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(style:reuseIdentifier:)") }

    private func setup() {
        backgroundColor = .gpCardBackground
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .gpTextPrimary
        titleLabel.numberOfLines = 0

        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .gpTextSecondary
        subtitleLabel.numberOfLines = 0

        detailStack.axis = .vertical
        detailStack.spacing = 2

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, detailStack])
        stack.axis = .vertical
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        isAccessibilityElement = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        detailStack.arrangedSubviews.forEach {
            detailStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    func configure(with row: Product22ListRow) {
        titleLabel.text = row.title
        subtitleLabel.text = row.subtitle
        subtitleLabel.isHidden = (row.subtitle ?? "").isEmpty

        for detail in row.details {
            let label = UILabel()
            label.font = .preferredFont(forTextStyle: .footnote)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .gpTextSecondary
            label.numberOfLines = 0
            label.text = detail
            detailStack.addArrangedSubview(label)
        }
        detailStack.isHidden = row.details.isEmpty

        accessibilityLabel = row.accessibilityLabel
        accessibilityTraits = row.actionTitle == nil ? .staticText : .button
        selectionStyle = row.actionTitle == nil ? .none : .default
        accessoryType = row.actionTitle == nil ? .none : .disclosureIndicator
    }
}
