import UIKit

final class AIRecommendationRootView: UIView {
    let queryTextView: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = .gpSurface
        textView.textColor = .gpTextPrimary
        textView.font = .systemFont(ofSize: 15)
        textView.tintColor = .gpPrimary
        textView.layer.cornerRadius = 14
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.returnKeyType = .default
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    let recommendButton: UIButton = {
        let button = UIButton(configuration: .filled())
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let retryButton: UIButton = {
        let button = UIButton(configuration: .bordered())
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let refreshButton: UIButton = {
        let button = UIButton(configuration: .bordered())
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 156
        tableView.isScrollEnabled = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    let chipStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let chipScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("Localizable", "aiRecommendation.title")
        label.font = .systemFont(ofSize: 26, weight: .bold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        return label
    }()

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("Localizable", "aiRecommendation.placeholder")
        label.font = .systemFont(ofSize: 15)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let privacyNoticeLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("Localizable", "aiRecommendation.privacyNotice")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 0
        return label
    }()

    private let aiNoticeLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("Localizable", "aiRecommendation.aiNotice")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 0
        return label
    }()

    private let resultTitleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("Localizable", "aiRecommendation.resultTitle")
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .gpTextPrimary
        return label
    }()

    private let helperMessageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        return label
    }()

    private let helperContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSurface
        view.layer.cornerRadius = 12
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.configure(icon: "sparkles", message: L10n.tr("Localizable", "aiRecommendation.emptyMessage"))
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let errorContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSurface
        view.layer.cornerRadius = 14
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .gpTextSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .gpTextSecondary
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private var tableHeightConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configureChips(_ examples: [String], target: Any?, action: Selector) {
        chipStackView.arrangedSubviews.forEach {
            chipStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        examples.forEach { example in
            let button = UIButton(type: .system)
            button.setTitle(example, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            button.setTitleColor(.gpTextSecondary, for: .normal)
            button.backgroundColor = .gpSurface
            button.layer.cornerRadius = 18
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
            button.accessibilityLabel = L10n.tr("Localizable", "aiRecommendation.example.accessibility", example)
            button.addTarget(target, action: action, for: .touchUpInside)
            chipStackView.addArrangedSubview(button)
        }
    }

    func render(_ state: AIRecommendationState) {
        if queryTextView.text != state.query {
            queryTextView.text = state.query
        }
        placeholderLabel.isHidden = !state.query.isEmpty

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = state.isLoading
            ? L10n.tr("Localizable", "aiRecommendation.button.loading")
            : L10n.tr("Localizable", "aiRecommendation.button.recommend")
        buttonConfiguration.baseBackgroundColor = state.isRecommendButtonEnabled ? .gpPrimary : .gpSurface
        buttonConfiguration.baseForegroundColor = state.isRecommendButtonEnabled ? .gpOnPrimary : .gpTextTertiary
        buttonConfiguration.cornerStyle = .capsule
        recommendButton.configuration = buttonConfiguration
        recommendButton.isEnabled = state.isRecommendButtonEnabled

        var retryConfiguration = UIButton.Configuration.bordered()
        retryConfiguration.title = L10n.tr("Localizable", "ai_recommendation_error_retry")
        retryConfiguration.baseForegroundColor = .gpPrimary
        retryConfiguration.cornerStyle = .capsule
        retryButton.configuration = retryConfiguration

        var refreshConfiguration = UIButton.Configuration.bordered()
        refreshConfiguration.title = L10n.tr("Localizable", "ai_recommendation_refresh_button")
        refreshConfiguration.baseForegroundColor = .gpPrimary
        refreshConfiguration.cornerStyle = .capsule
        refreshButton.configuration = refreshConfiguration
        refreshButton.isHidden = !state.isStale

        if state.isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }

        errorLabel.text = state.errorMessage ?? L10n.tr("Localizable", "aiRecommendation.error.default")
        errorContainerView.isHidden = state.errorMessage == nil
        helperMessageLabel.text = state.helperMessage
        helperContainerView.isHidden = state.helperMessage == nil || state.errorMessage != nil
        emptyStateView.configure(icon: "sparkles", message: state.emptyMessage)
        tableView.isHidden = state.recommendations.isEmpty || state.errorMessage != nil
        emptyStateView.isHidden = !state.showsEmptyState
        resultTitleLabel.isHidden = state.recommendations.isEmpty && state.errorMessage == nil && !state.showsEmptyState
    }

    func updateTableHeight() {
        tableView.layoutIfNeeded()
        tableHeightConstraint?.constant = tableView.isHidden ? 0 : tableView.contentSize.height
        layoutIfNeeded()
    }

    func setKeyboardBottomInset(_ bottomInset: CGFloat) {
        scrollView.contentInset.bottom = bottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    private func setup() {
        backgroundColor = .gpBackground
        addSubview(scrollView)
        scrollView.addSubview(contentView)

        queryTextView.addSubview(placeholderLabel)
        tableView.register(AIRecommendationResultCell.self, forCellReuseIdentifier: AIRecommendationResultCell.reuseId)

        let noticesStackView = UIStackView(arrangedSubviews: [aiNoticeLabel, privacyNoticeLabel])
        noticesStackView.axis = .vertical
        noticesStackView.spacing = 6

        chipScrollView.addSubview(chipStackView)

        let headerStackView = UIStackView(arrangedSubviews: [
            titleLabel,
            queryTextView,
            chipScrollView,
            recommendButton,
            noticesStackView
        ])
        headerStackView.axis = .vertical
        headerStackView.spacing = 14
        headerStackView.translatesAutoresizingMaskIntoConstraints = false

        let errorStackView = UIStackView(arrangedSubviews: [errorLabel, retryButton])
        errorStackView.axis = .vertical
        errorStackView.spacing = 12
        errorStackView.alignment = .center
        errorStackView.translatesAutoresizingMaskIntoConstraints = false
        errorContainerView.addSubview(errorStackView)

        let helperStackView = UIStackView(arrangedSubviews: [helperMessageLabel, refreshButton])
        helperStackView.axis = .vertical
        helperStackView.spacing = 10
        helperStackView.alignment = .fill
        helperStackView.translatesAutoresizingMaskIntoConstraints = false
        helperContainerView.addSubview(helperStackView)

        let resultStackView = UIStackView(arrangedSubviews: [
            resultTitleLabel,
            helperContainerView,
            activityIndicator,
            errorContainerView,
            emptyStateView,
            tableView
        ])
        resultStackView.axis = .vertical
        resultStackView.spacing = 12
        resultStackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(headerStackView)
        contentView.addSubview(resultStackView)

        let tableHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 0)
        self.tableHeightConstraint = tableHeightConstraint

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            headerStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            queryTextView.heightAnchor.constraint(equalToConstant: 124),
            chipScrollView.heightAnchor.constraint(equalToConstant: 36),
            chipStackView.topAnchor.constraint(equalTo: chipScrollView.contentLayoutGuide.topAnchor),
            chipStackView.leadingAnchor.constraint(equalTo: chipScrollView.contentLayoutGuide.leadingAnchor),
            chipStackView.trailingAnchor.constraint(equalTo: chipScrollView.contentLayoutGuide.trailingAnchor),
            chipStackView.bottomAnchor.constraint(equalTo: chipScrollView.contentLayoutGuide.bottomAnchor),
            chipStackView.heightAnchor.constraint(equalTo: chipScrollView.frameLayoutGuide.heightAnchor),
            recommendButton.heightAnchor.constraint(equalToConstant: 48),

            placeholderLabel.topAnchor.constraint(equalTo: queryTextView.topAnchor, constant: 18),
            placeholderLabel.leadingAnchor.constraint(equalTo: queryTextView.leadingAnchor, constant: 16),
            placeholderLabel.trailingAnchor.constraint(equalTo: queryTextView.trailingAnchor, constant: -16),

            resultStackView.topAnchor.constraint(equalTo: headerStackView.bottomAnchor, constant: 24),
            resultStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            resultStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            resultStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),

            tableHeightConstraint,
            emptyStateView.heightAnchor.constraint(equalToConstant: 180),

            errorStackView.topAnchor.constraint(equalTo: errorContainerView.topAnchor, constant: 18),
            errorStackView.leadingAnchor.constraint(equalTo: errorContainerView.leadingAnchor, constant: 16),
            errorStackView.trailingAnchor.constraint(equalTo: errorContainerView.trailingAnchor, constant: -16),
            errorStackView.bottomAnchor.constraint(equalTo: errorContainerView.bottomAnchor, constant: -18),
            retryButton.heightAnchor.constraint(equalToConstant: 36),

            helperStackView.topAnchor.constraint(equalTo: helperContainerView.topAnchor, constant: 12),
            helperStackView.leadingAnchor.constraint(equalTo: helperContainerView.leadingAnchor, constant: 14),
            helperStackView.trailingAnchor.constraint(equalTo: helperContainerView.trailingAnchor, constant: -14),
            helperStackView.bottomAnchor.constraint(equalTo: helperContainerView.bottomAnchor, constant: -12),
            refreshButton.heightAnchor.constraint(equalToConstant: 34)
        ])
    }
}
