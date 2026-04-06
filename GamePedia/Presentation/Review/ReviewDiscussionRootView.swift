import UIKit

final class ReviewDiscussionRootView: UIView {
    private struct HeaderViewState: Equatable {
        let review: Review?
        let gameTitle: String
        let commentCount: Int
    }

    let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .gpBackground
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    let emptyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .gpTextSecondary
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

    let noticeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let composerModeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .gpPrimaryLight
        label.numberOfLines = 1
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let cancelComposerModeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "xmark.circle.fill")
        configuration.baseForegroundColor = .gpTextSecondary
        configuration.contentInsets = .zero
        let button = UIButton(configuration: configuration)
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let composerTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .gpTextPrimary
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    let composerPlaceholderLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let submitButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .white
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let composerContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 20
        view.layer.cornerCurve = .continuous
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.gpSeparator.withAlphaComponent(0.22).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let composerTextContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSurfaceElevated.withAlphaComponent(0.78)
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var composerBottomConstraint: NSLayoutConstraint?
    private let headerView = ReviewDiscussionHeaderView()
    private var headerViewState: HeaderViewState?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func render(_ state: ReviewDiscussionState) {
        headerViewState = HeaderViewState(
            review: state.review,
            gameTitle: state.navigationTitle,
            commentCount: state.comments.count
        )
        updateTableHeaderIfNeeded()

        emptyLabel.text = state.emptyMessage
        emptyLabel.isHidden = !(state.review != nil && !state.isLoading && state.comments.isEmpty && state.errorMessage == nil)

        composerPlaceholderLabel.text = state.composerPlaceholder
        composerPlaceholderLabel.isHidden = !state.composerText.isEmpty
        composerModeLabel.text = state.composerContextText
        composerModeLabel.isHidden = state.composerContextText == nil
        cancelComposerModeButton.isHidden = state.composerContextText == nil
        if composerTextView.text != state.composerText {
            composerTextView.text = state.composerText
        }
        composerTextView.isEditable = !state.isSubmitting
        submitButton.isEnabled = state.canSubmit
        var submitConfiguration = submitButton.configuration
        submitConfiguration?.title = state.composerSubmitTitle
        submitButton.configuration = submitConfiguration
        submitButton.alpha = state.canSubmit ? 1.0 : 0.55

        noticeLabel.text = state.inlineNoticeMessage
        noticeLabel.isHidden = state.inlineNoticeMessage == nil
        retryButton.isHidden = state.errorMessage == nil
        if let errorMessage = state.errorMessage, state.review == nil {
            emptyLabel.text = errorMessage
            emptyLabel.isHidden = false
        }

        if state.isLoading && state.review == nil {
            loadingIndicatorView.startAnimating()
        } else {
            loadingIndicatorView.stopAnimating()
        }
    }

    func setComposerBottomInset(_ inset: CGFloat) {
        composerBottomConstraint?.constant = -inset
        layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateTableHeaderIfNeeded()
    }

    private func setup() {
        backgroundColor = .gpBackground
        tableView.register(ReviewCommentCell.self, forCellReuseIdentifier: ReviewCommentCell.reuseIdentifier)

        addSubview(tableView)
        addSubview(emptyLabel)
        addSubview(loadingIndicatorView)
        addSubview(retryButton)
        addSubview(composerContainerView)

        composerContainerView.addSubview(noticeLabel)
        composerContainerView.addSubview(composerModeLabel)
        composerContainerView.addSubview(cancelComposerModeButton)
        composerContainerView.addSubview(composerTextContainerView)
        composerContainerView.addSubview(submitButton)
        composerTextContainerView.addSubview(composerTextView)
        composerTextContainerView.addSubview(composerPlaceholderLabel)

        composerBottomConstraint = composerContainerView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        composerBottomConstraint?.isActive = true

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: composerContainerView.topAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),

            retryButton.topAnchor.constraint(equalTo: emptyLabel.bottomAnchor, constant: 12),
            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor),

            loadingIndicatorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicatorView.centerYAnchor.constraint(equalTo: centerYAnchor),

            composerContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            composerContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),

            noticeLabel.topAnchor.constraint(equalTo: composerContainerView.topAnchor, constant: 10),
            noticeLabel.leadingAnchor.constraint(equalTo: composerContainerView.leadingAnchor, constant: 20),
            noticeLabel.trailingAnchor.constraint(equalTo: composerContainerView.trailingAnchor, constant: -20),

            composerModeLabel.topAnchor.constraint(equalTo: noticeLabel.bottomAnchor, constant: 6),
            composerModeLabel.leadingAnchor.constraint(equalTo: composerContainerView.leadingAnchor, constant: 20),
            composerModeLabel.trailingAnchor.constraint(lessThanOrEqualTo: cancelComposerModeButton.leadingAnchor, constant: -8),

            cancelComposerModeButton.centerYAnchor.constraint(equalTo: composerModeLabel.centerYAnchor),
            cancelComposerModeButton.trailingAnchor.constraint(equalTo: composerContainerView.trailingAnchor, constant: -20),

            submitButton.trailingAnchor.constraint(equalTo: composerContainerView.trailingAnchor, constant: -20),
            submitButton.bottomAnchor.constraint(equalTo: composerContainerView.bottomAnchor, constant: -16),

            composerTextContainerView.topAnchor.constraint(equalTo: composerModeLabel.bottomAnchor, constant: 10),
            composerTextContainerView.leadingAnchor.constraint(equalTo: composerContainerView.leadingAnchor, constant: 20),
            composerTextContainerView.trailingAnchor.constraint(equalTo: submitButton.leadingAnchor, constant: -12),
            composerTextContainerView.bottomAnchor.constraint(equalTo: composerContainerView.bottomAnchor, constant: -12),
            composerTextContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 46),

            composerTextView.topAnchor.constraint(equalTo: composerTextContainerView.topAnchor),
            composerTextView.leadingAnchor.constraint(equalTo: composerTextContainerView.leadingAnchor, constant: 12),
            composerTextView.trailingAnchor.constraint(equalTo: composerTextContainerView.trailingAnchor, constant: -12),
            composerTextView.bottomAnchor.constraint(equalTo: composerTextContainerView.bottomAnchor),

            composerPlaceholderLabel.topAnchor.constraint(equalTo: composerTextContainerView.topAnchor, constant: 11),
            composerPlaceholderLabel.leadingAnchor.constraint(equalTo: composerTextContainerView.leadingAnchor, constant: 16),
            composerPlaceholderLabel.trailingAnchor.constraint(equalTo: composerTextContainerView.trailingAnchor, constant: -16)
        ])
    }

    private func updateTableHeaderIfNeeded() {
        guard let headerViewState else { return }

        headerView.configure(
            review: headerViewState.review,
            gameTitle: headerViewState.gameTitle,
            commentCount: headerViewState.commentCount
        )

        if tableView.tableHeaderView !== headerView {
            tableView.tableHeaderView = headerView
        }

        let targetWidth = tableView.bounds.width > 0 ? tableView.bounds.width : bounds.width
        guard targetWidth > 0 else { return }

        headerView.frame = CGRect(origin: .zero, size: CGSize(width: targetWidth, height: headerView.frame.height))
        headerView.setNeedsLayout()
        headerView.layoutIfNeeded()

        let headerSize = headerView.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let resolvedHeight = ceil(headerSize.height)
        let resolvedSize = CGSize(width: targetWidth, height: resolvedHeight)
        guard headerView.frame.size != resolvedSize else { return }

        headerView.frame = CGRect(origin: .zero, size: resolvedSize)
        tableView.tableHeaderView = headerView
    }
}

private final class ReviewDiscussionHeaderView: UIView {
    private let gameTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        return label
    }()

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 14
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 14
        imageView.backgroundColor = .gpSurfaceElevated
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let avatarInitialLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .gpAvatarInitialText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let authorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .gpTextPrimary
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = .gpTextTertiary
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        return label
    }()

    private let starView = StarRatingView()
    private let commentCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .gpTextSecondary
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(review: Review?, gameTitle: String, commentCount: Int) {
        gameTitleLabel.text = gameTitle
        if let review {
            let avatarColors: [UIColor] = [
                UIColor(hex: "#6C63FF"), UIColor(hex: "#4ECDC4"),
                UIColor(hex: "#FF6B6B"), UIColor(hex: "#45B7D1"),
                UIColor(hex: "#96CEB4"), UIColor(hex: "#FFEAA7")
            ]
            let colorIndex = abs(review.authorName.hashValue) % avatarColors.count
            avatarView.backgroundColor = avatarColors[colorIndex]
            avatarInitialLabel.text = String(review.authorName.first ?? " ")
            avatarView.loadImage(url: review.authorAvatarURL)
            authorLabel.text = review.authorName
            dateLabel.text = review.formattedDate
            bodyLabel.text = review.body
            starView.configure(rating: review.rating)
        }
        commentCountLabel.text = L10n.tr("Localizable", "review.comment.count", commentCount)
    }

    private func setup() {
        backgroundColor = .clear
        avatarView.addSubview(avatarInitialLabel)

        let authorInfoStack = UIStackView(arrangedSubviews: [authorLabel, dateLabel])
        authorInfoStack.axis = .vertical
        authorInfoStack.spacing = 2

        let userStack = UIStackView(arrangedSubviews: [avatarView, authorInfoStack])
        userStack.axis = .horizontal
        userStack.alignment = .center
        userStack.spacing = 8

        let headerRow = UIStackView(arrangedSubviews: [userStack, UIView(), starView])
        headerRow.axis = .horizontal
        headerRow.alignment = .center

        let cardStack = UIStackView(arrangedSubviews: [headerRow, bodyLabel])
        cardStack.axis = .vertical
        cardStack.spacing = 8
        cardStack.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(cardStack)

        let stackView = UIStackView(arrangedSubviews: [gameTitleLabel, cardView, commentCountLabel])
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            avatarView.widthAnchor.constraint(equalToConstant: 28),
            avatarView.heightAnchor.constraint(equalToConstant: 28),
            avatarInitialLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarInitialLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            cardStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            cardStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            cardStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            cardStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14)
        ])
    }
}
