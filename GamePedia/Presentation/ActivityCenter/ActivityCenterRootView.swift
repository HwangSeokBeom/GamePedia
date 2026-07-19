import UIKit

final class ActivityCenterRootView: UIView {

    let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .gpBackground
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    /// Degraded/offline notice shown above the list. The list stays
    /// usable underneath it; retry stays available.
    private let noticeContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.gpCoral.withAlphaComponent(0.14)
        view.layer.cornerRadius = 12
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let noticeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let noticeRetryButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = L10n.Common.Button.retry
        configuration.baseForegroundColor = .gpPrimary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8)
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let emptyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .gpTextSecondary
        label.text = L10n.tr("Localizable", "activityCenter.empty")
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let loadingIndicatorView: UIActivityIndicatorView = {
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

    private var tableTopToNoticeConstraint: NSLayoutConstraint?
    private var tableTopToSafeAreaConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(_ state: ActivityCenterState) {
        if state.isLoading {
            loadingIndicatorView.startAnimating()
        } else {
            loadingIndicatorView.stopAnimating()
        }

        if let noticeText = state.degradedNoticeText {
            noticeLabel.text = noticeText
            noticeContainerView.isHidden = false
            tableTopToSafeAreaConstraint?.isActive = false
            tableTopToNoticeConstraint?.isActive = true
        } else {
            noticeContainerView.isHidden = true
            tableTopToNoticeConstraint?.isActive = false
            tableTopToSafeAreaConstraint?.isActive = true
        }

        retryButton.isHidden = state.errorMessage == nil
        if let errorMessage = state.errorMessage {
            emptyLabel.text = errorMessage
            emptyLabel.isHidden = false
        } else {
            emptyLabel.text = L10n.tr("Localizable", "activityCenter.empty")
            emptyLabel.isHidden = !state.isEmpty
        }
    }

    private func setup() {
        backgroundColor = .gpBackground
        addSubview(noticeContainerView)
        noticeContainerView.addSubview(noticeLabel)
        noticeContainerView.addSubview(noticeRetryButton)
        addSubview(tableView)
        addSubview(emptyLabel)
        addSubview(loadingIndicatorView)
        addSubview(retryButton)

        let tableTopToNotice = tableView.topAnchor.constraint(
            equalTo: noticeContainerView.bottomAnchor,
            constant: 8
        )
        let tableTopToSafeArea = tableView.topAnchor.constraint(
            equalTo: safeAreaLayoutGuide.topAnchor
        )
        tableTopToNoticeConstraint = tableTopToNotice
        tableTopToSafeAreaConstraint = tableTopToSafeArea
        tableTopToSafeArea.isActive = true

        NSLayoutConstraint.activate([
            noticeContainerView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            noticeContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            noticeContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            noticeLabel.topAnchor.constraint(equalTo: noticeContainerView.topAnchor, constant: 10),
            noticeLabel.leadingAnchor.constraint(equalTo: noticeContainerView.leadingAnchor, constant: 12),
            noticeLabel.bottomAnchor.constraint(equalTo: noticeContainerView.bottomAnchor, constant: -10),

            noticeRetryButton.centerYAnchor.constraint(equalTo: noticeContainerView.centerYAnchor),
            noticeRetryButton.leadingAnchor.constraint(equalTo: noticeLabel.trailingAnchor, constant: 8),
            noticeRetryButton.trailingAnchor.constraint(equalTo: noticeContainerView.trailingAnchor, constant: -8),

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
            loadingIndicatorView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 20)
        ])

        noticeRetryButton.setContentHuggingPriority(.required, for: .horizontal)
        noticeRetryButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
