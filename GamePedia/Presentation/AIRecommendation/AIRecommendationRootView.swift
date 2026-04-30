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
        label.text = "어떤 게임을 찾고 있나요?"
        label.font = .systemFont(ofSize: 26, weight: .bold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        return label
    }()

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "예: 퇴근하고 30분 정도 할 수 있는 힐링 게임 추천해줘"
        label.font = .systemFont(ofSize: 15)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let privacyNoticeLabel: UILabel = {
        let label = UILabel()
        label.text = "AI 추천을 위해 입력한 문장이 서버로 전송될 수 있습니다. 민감한 개인정보는 입력하지 마세요."
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 0
        return label
    }()

    private let aiNoticeLabel: UILabel = {
        let label = UILabel()
        label.text = "AI 추천은 사용자의 입력과 게임 데이터 기반으로 생성되며, 실제 취향과 다를 수 있습니다."
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 0
        return label
    }()

    private let resultTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "추천 결과"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .gpTextPrimary
        return label
    }()

    private let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.configure(icon: "sparkles", message: "조건에 맞는 추천 결과가 없습니다.")
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
            button.accessibilityLabel = "AI 추천 예시: \(example)"
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
        buttonConfiguration.title = state.isLoading ? "추천 중..." : "추천받기"
        buttonConfiguration.baseBackgroundColor = state.isRecommendButtonEnabled ? .gpPrimary : .gpSurface
        buttonConfiguration.baseForegroundColor = state.isRecommendButtonEnabled ? .gpOnPrimary : .gpTextTertiary
        buttonConfiguration.cornerStyle = .capsule
        recommendButton.configuration = buttonConfiguration
        recommendButton.isEnabled = state.isRecommendButtonEnabled

        var retryConfiguration = UIButton.Configuration.bordered()
        retryConfiguration.title = "다시 시도"
        retryConfiguration.baseForegroundColor = .gpPrimary
        retryConfiguration.cornerStyle = .capsule
        retryButton.configuration = retryConfiguration

        if state.isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }

        errorLabel.text = state.errorMessage ?? "추천을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요."
        errorContainerView.isHidden = state.errorMessage == nil
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

        let resultStackView = UIStackView(arrangedSubviews: [
            resultTitleLabel,
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
            retryButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
}
