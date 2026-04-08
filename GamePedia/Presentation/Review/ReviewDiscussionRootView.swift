import UIKit

final class ReviewDiscussionRootView: UIView {
    let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .gpBackground
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 112
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
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
        return label
    }()

    let composerModeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.numberOfLines = 1
        return label
    }()

    let cancelComposerModeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = L10n.Common.Button.cancel
        configuration.baseForegroundColor = .gpTextSecondary
        configuration.contentInsets = .zero
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let composerTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .gpTextPrimary
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    let composerPlaceholderLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let submitButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .gpPrimary
        button.tintColor = .white
        button.layer.cornerRadius = 14
        button.layer.cornerCurve = .continuous
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .gpTextSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let composerContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let composerTopBorderView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSeparator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let composerStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let composerContextContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSurfaceElevated
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let composerContextIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .gpPrimaryLight
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let composerAvatarView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpPrimary
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let composerAvatarIconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "person.fill"))
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let composerTextContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSurfaceElevated
        view.layer.cornerRadius = 19
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.gpSeparator.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var composerBottomConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func render(_ state: ReviewDiscussionState) {
        emptyLabel.text = state.errorMessage
        emptyLabel.isHidden = !(state.errorMessage != nil && state.review == nil)
        retryButton.isHidden = !(state.errorMessage != nil && state.review == nil)

        let composerState = state.composerState
        composerPlaceholderLabel.text = composerState.placeholder
        composerPlaceholderLabel.isHidden = !composerState.text.isEmpty

        let contextText = composerState.contextText
        composerModeLabel.text = contextText
        composerContextContainerView.isHidden = contextText == nil
        cancelComposerModeButton.isHidden = contextText == nil

        if composerTextView.text != composerState.text {
            composerTextView.text = composerState.text
        }
        composerTextView.isEditable = !composerState.isSubmitting

        noticeLabel.text = state.inlineNoticeMessage
        noticeLabel.isHidden = state.inlineNoticeMessage == nil

        if state.isLoading && state.review == nil {
            loadingIndicatorView.startAnimating()
        } else {
            loadingIndicatorView.stopAnimating()
        }

        applyComposerStyle(for: composerState)
    }

    func setComposerBottomInset(_ inset: CGFloat) {
        composerBottomConstraint?.constant = -inset
        layoutIfNeeded()
    }

    func focusComposer() {
        composerTextView.becomeFirstResponder()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    private func setup() {
        backgroundColor = .gpBackground
        tableView.register(ReviewCommentCell.self, forCellReuseIdentifier: ReviewCommentCell.reuseIdentifier)

        let composerContextRow = UIStackView(arrangedSubviews: [composerContextIconView, composerModeLabel, UIView(), cancelComposerModeButton])
        composerContextRow.axis = .horizontal
        composerContextRow.alignment = .center
        composerContextRow.spacing = 8
        composerContextRow.translatesAutoresizingMaskIntoConstraints = false

        composerContextContainerView.addSubview(composerContextRow)
        composerAvatarView.addSubview(composerAvatarIconView)

        let composerRow = UIStackView(arrangedSubviews: [composerAvatarView, composerTextContainerView])
        composerRow.axis = .horizontal
        composerRow.alignment = .center
        composerRow.spacing = 10
        composerRow.translatesAutoresizingMaskIntoConstraints = false

        composerTextContainerView.addSubview(composerTextView)
        composerTextContainerView.addSubview(composerPlaceholderLabel)
        composerTextContainerView.addSubview(submitButton)

        composerStackView.addArrangedSubview(noticeLabel)
        composerStackView.addArrangedSubview(composerContextContainerView)
        composerStackView.addArrangedSubview(composerRow)

        addSubview(tableView)
        addSubview(emptyLabel)
        addSubview(loadingIndicatorView)
        addSubview(retryButton)
        addSubview(composerContainerView)

        composerContainerView.addSubview(composerTopBorderView)
        composerContainerView.addSubview(composerStackView)

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

            composerTopBorderView.topAnchor.constraint(equalTo: composerContainerView.topAnchor),
            composerTopBorderView.leadingAnchor.constraint(equalTo: composerContainerView.leadingAnchor),
            composerTopBorderView.trailingAnchor.constraint(equalTo: composerContainerView.trailingAnchor),
            composerTopBorderView.heightAnchor.constraint(equalToConstant: 1),

            composerStackView.topAnchor.constraint(equalTo: composerContainerView.topAnchor, constant: 8),
            composerStackView.leadingAnchor.constraint(equalTo: composerContainerView.leadingAnchor, constant: 16),
            composerStackView.trailingAnchor.constraint(equalTo: composerContainerView.trailingAnchor, constant: -16),
            composerStackView.bottomAnchor.constraint(equalTo: composerContainerView.bottomAnchor, constant: -12),

            composerContextRow.topAnchor.constraint(equalTo: composerContextContainerView.topAnchor, constant: 8),
            composerContextRow.leadingAnchor.constraint(equalTo: composerContextContainerView.leadingAnchor, constant: 16),
            composerContextRow.trailingAnchor.constraint(equalTo: composerContextContainerView.trailingAnchor, constant: -16),
            composerContextRow.bottomAnchor.constraint(equalTo: composerContextContainerView.bottomAnchor, constant: -8),

            composerContextIconView.widthAnchor.constraint(equalToConstant: 12),
            composerContextIconView.heightAnchor.constraint(equalToConstant: 12),

            composerAvatarView.widthAnchor.constraint(equalToConstant: 32),
            composerAvatarView.heightAnchor.constraint(equalToConstant: 32),
            composerAvatarIconView.centerXAnchor.constraint(equalTo: composerAvatarView.centerXAnchor),
            composerAvatarIconView.centerYAnchor.constraint(equalTo: composerAvatarView.centerYAnchor),
            composerAvatarIconView.widthAnchor.constraint(equalToConstant: 14),
            composerAvatarIconView.heightAnchor.constraint(equalToConstant: 14),

            composerTextContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 38),

            composerTextView.topAnchor.constraint(equalTo: composerTextContainerView.topAnchor),
            composerTextView.leadingAnchor.constraint(equalTo: composerTextContainerView.leadingAnchor, constant: 14),
            composerTextView.trailingAnchor.constraint(equalTo: submitButton.leadingAnchor, constant: -8),
            composerTextView.bottomAnchor.constraint(equalTo: composerTextContainerView.bottomAnchor),

            composerPlaceholderLabel.leadingAnchor.constraint(equalTo: composerTextContainerView.leadingAnchor, constant: 14),
            composerPlaceholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: submitButton.leadingAnchor, constant: -8),
            composerPlaceholderLabel.centerYAnchor.constraint(equalTo: composerTextContainerView.centerYAnchor),

            submitButton.trailingAnchor.constraint(equalTo: composerTextContainerView.trailingAnchor, constant: -6),
            submitButton.centerYAnchor.constraint(equalTo: composerTextContainerView.centerYAnchor),
            submitButton.widthAnchor.constraint(equalToConstant: 28),
            submitButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func applyComposerStyle(for state: ReviewDiscussionComposerState) {
        let symbolName: String
        let contextIconName: String
        let accentColor: UIColor

        switch state.mode {
        case .comment:
            symbolName = "arrow.up"
            contextIconName = "arrow.turn.up.left"
            accentColor = .gpSeparator
        case .reply:
            symbolName = "arrow.up"
            contextIconName = "arrow.turn.up.left"
            accentColor = .gpPrimary
        case .edit:
            symbolName = "checkmark"
            contextIconName = "pencil.line"
            accentColor = .gpOrange
        }

        composerContextIconView.image = UIImage(
            systemName: contextIconName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        )
        composerContextIconView.tintColor = accentColor == .gpSeparator ? .gpPrimaryLight : accentColor
        composerModeLabel.textColor = accentColor == .gpSeparator ? .gpPrimaryLight : accentColor

        let showsContext = state.contextText != nil
        composerTextContainerView.layer.borderColor = (showsContext ? accentColor : UIColor.gpSeparator).cgColor
        composerTextContainerView.layer.borderWidth = showsContext ? 1.5 : 1

        submitButton.isEnabled = state.canSubmit
        submitButton.accessibilityLabel = state.submitTitle
        submitButton.setImage(
            UIImage(
                systemName: symbolName,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
            ),
            for: .normal
        )
        submitButton.backgroundColor = state.canSubmit ? (showsContext && accentColor != .gpSeparator ? accentColor : .gpPrimary) : .gpSurfaceElevated
        submitButton.tintColor = state.canSubmit ? .white : .gpTextTertiary
    }
}

final class ReviewDiscussionHeaderView: UIView {
    var onLikeTapped: (() -> Void)?
    private var currentReviewId: String?

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.gpSeparator.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10
        imageView.backgroundColor = .gpSurfaceElevated
        imageView.tintColor = .gpTextTertiary
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let gameTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextTertiary
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        return label
    }()

    private let authorAvatarView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = .gpSurfaceElevated
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let authorAvatarInitialLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .gpAvatarInitialText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let authorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextSecondary
        return label
    }()

    private let likeMetaButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = .zero
        configuration.imagePadding = 4
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        configuration.baseForegroundColor = .gpTextTertiary
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = .systemFont(ofSize: 12, weight: .medium)
            return updated
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let mineBadgeLabel: UILabel = {
        let label = InsetLabel(insets: UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6))
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = .gpPrimary
        label.layer.cornerRadius = 9
        label.layer.cornerCurve = .continuous
        label.layer.masksToBounds = true
        label.text = L10n.tr("Localizable", "review.comment.badge.mine")
        label.isHidden = true
        return label
    }()

    private let starView = StarRatingView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(with state: ReviewDiscussionHeaderState) {
        let review = state.review
        currentReviewId = review.id

        coverImageView.cancelLoad()
        coverImageView.loadImage(
            url: GameDetailSeedStore.shared.seed(for: state.gameId)?.coverImageURL,
            placeholder: UIImage(systemName: "gamecontroller.fill")
        )

        gameTitleLabel.text = state.gameTitle
        let absoluteDate = review.updatedAt.toAbsoluteDateString()
        dateLabel.text = absoluteDate.isEmpty ? review.createdAt.toAbsoluteDateString() : absoluteDate
        bodyLabel.text = review.body
        starView.configure(rating: review.rating)

        let avatarColor = ReviewAvatarPalette.color(for: review.authorName)
        authorAvatarView.backgroundColor = avatarColor
        authorAvatarInitialLabel.text = String(review.authorName.first ?? " ")
        authorAvatarView.loadImage(url: review.authorAvatarURL)
        authorLabel.text = review.authorName
        mineBadgeLabel.isHidden = !review.isMine

        var likeConfiguration = likeMetaButton.configuration
        likeConfiguration?.title = String(review.likeCount)
        likeConfiguration?.image = UIImage(
            systemName: review.isLikedByCurrentUser ? "heart.fill" : "heart",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        )
        likeConfiguration?.baseForegroundColor = review.isLikedByCurrentUser ? .gpCoral : .gpTextTertiary
        likeMetaButton.configuration = likeConfiguration
        likeMetaButton.isEnabled = !state.isLikeLoading
        likeMetaButton.alpha = review.likeCount == 0 && !review.isLikedByCurrentUser ? 0.72 : 1
        likeMetaButton.accessibilityLabel = L10n.tr("Localizable", "review.comment.accessibility.like", String(review.likeCount))
    }

    func containsCard(at point: CGPoint) -> Bool {
        return cardView.frame.contains(point)
    }

    private func setup() {
        backgroundColor = .clear
        preservesSuperviewLayoutMargins = true
        directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20)
        cardView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)

        authorAvatarView.addSubview(authorAvatarInitialLabel)

        let infoStack = UIStackView(arrangedSubviews: [gameTitleLabel, makeMetaRow()])
        infoStack.axis = .vertical
        infoStack.spacing = 3
        infoStack.alignment = .fill
        infoStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let topRow = UIStackView(arrangedSubviews: [coverImageView, infoStack])
        topRow.axis = .horizontal
        topRow.alignment = .top
        topRow.spacing = 12

        let authorInfoRow = UIStackView(arrangedSubviews: [authorAvatarView, authorLabel, mineBadgeLabel])
        authorInfoRow.axis = .horizontal
        authorInfoRow.alignment = .center
        authorInfoRow.spacing = 8
        authorInfoRow.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let authorRow = UIStackView(arrangedSubviews: [authorInfoRow, likeMetaButton])
        authorRow.axis = .horizontal
        authorRow.alignment = .center
        authorRow.distribution = .equalSpacing
        authorRow.spacing = 8

        likeMetaButton.addTarget(self, action: #selector(didTapLike), for: .touchUpInside)

        contentStackView.addArrangedSubview(topRow)
        contentStackView.addArrangedSubview(bodyLabel)
        contentStackView.addArrangedSubview(authorRow)

        addSubview(cardView)
        cardView.addSubview(contentStackView)

        gameTitleLabel.lineBreakMode = .byTruncatingTail
        dateLabel.lineBreakMode = .byTruncatingTail
        authorLabel.lineBreakMode = .byTruncatingTail
        bodyLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        authorLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        mineBadgeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        likeMetaButton.setContentHuggingPriority(.required, for: .horizontal)
        likeMetaButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        coverImageView.setContentHuggingPriority(.required, for: .horizontal)
        coverImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let cardTopConstraint = cardView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor)
        let cardLeadingConstraint = cardView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor)
        let cardTrailingConstraint = cardView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor)
        let cardBottomConstraint = cardView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)

        [cardTopConstraint, cardLeadingConstraint, cardTrailingConstraint, cardBottomConstraint].forEach {
            $0.priority = UILayoutPriority(999)
        }

        NSLayoutConstraint.activate([
            cardTopConstraint,
            cardLeadingConstraint,
            cardTrailingConstraint,
            cardBottomConstraint,

            coverImageView.widthAnchor.constraint(equalToConstant: 48),
            coverImageView.heightAnchor.constraint(equalToConstant: 48),

            authorAvatarView.widthAnchor.constraint(equalToConstant: 24),
            authorAvatarView.heightAnchor.constraint(equalToConstant: 24),
            authorAvatarInitialLabel.centerXAnchor.constraint(equalTo: authorAvatarView.centerXAnchor),
            authorAvatarInitialLabel.centerYAnchor.constraint(equalTo: authorAvatarView.centerYAnchor),
        ])

        let contentTopConstraint = contentStackView.topAnchor.constraint(equalTo: cardView.layoutMarginsGuide.topAnchor)
        let contentLeadingConstraint = contentStackView.leadingAnchor.constraint(equalTo: cardView.layoutMarginsGuide.leadingAnchor)
        let contentTrailingConstraint = contentStackView.trailingAnchor.constraint(equalTo: cardView.layoutMarginsGuide.trailingAnchor)
        let contentBottomConstraint = contentStackView.bottomAnchor.constraint(equalTo: cardView.layoutMarginsGuide.bottomAnchor)

        [contentTopConstraint, contentLeadingConstraint, contentTrailingConstraint, contentBottomConstraint].forEach {
            $0.priority = UILayoutPriority(999)
        }

        NSLayoutConstraint.activate([
            contentTopConstraint,
            contentLeadingConstraint,
            contentTrailingConstraint,
            contentBottomConstraint
        ])
    }

    private func makeMetaRow() -> UIStackView {
        let metaRow = UIStackView(arrangedSubviews: [starView, dateLabel])
        metaRow.axis = .horizontal
        metaRow.alignment = .center
        metaRow.spacing = 6
        dateLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        starView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return metaRow
    }

    @objc private func didTapLike() {
        ReviewDiscussionTrace.log("[ReviewDiscussionHeaderView] likeTapped reviewId=\(currentReviewId ?? "nil")")
        onLikeTapped?()
    }
}

final class ReviewDiscussionEmptyStateView: UIView {
    let actionButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = L10n.tr("Localizable", "review.comment.empty.cta")
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.gpSeparator.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let iconView: UIImageView = {
        let imageView = UIImageView(
            image: UIImage(systemName: "message.circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .medium))
        )
        imageView.tintColor = .gpTextTertiary
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .gpTextPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
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

    func configure(title: String, message: String, buttonTitle: String) {
        titleLabel.text = title
        messageLabel.text = message
        var configuration = actionButton.configuration
        configuration?.title = buttonTitle
        actionButton.configuration = configuration
    }

    private func setup() {
        backgroundColor = .clear
        directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 20, bottom: 12, trailing: 20)

        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        messageLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        contentStackView.addArrangedSubview(iconView)
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(messageLabel)
        contentStackView.addArrangedSubview(actionButton)

        addSubview(cardView)
        cardView.addSubview(contentStackView)

        let cardTopConstraint = cardView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor)
        let cardLeadingConstraint = cardView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor)
        let cardTrailingConstraint = cardView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor)
        let cardBottomConstraint = cardView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)

        [cardTopConstraint, cardLeadingConstraint, cardTrailingConstraint, cardBottomConstraint].forEach {
            $0.priority = UILayoutPriority(999)
        }

        NSLayoutConstraint.activate([
            cardTopConstraint,
            cardLeadingConstraint,
            cardTrailingConstraint,
            cardBottomConstraint,

            contentStackView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            contentStackView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            contentStackView.topAnchor.constraint(greaterThanOrEqualTo: cardView.topAnchor, constant: 32),
            contentStackView.leadingAnchor.constraint(greaterThanOrEqualTo: cardView.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -20),
            contentStackView.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -32),

            actionButton.heightAnchor.constraint(equalToConstant: 38)
        ])
    }
}

final class ReviewDiscussionHeaderCardCell: UITableViewCell {
    static let reuseIdentifier = "ReviewDiscussionHeaderCardCell"

    var onLikeTapped: (() -> Void)? {
        didSet {
            headerView.onLikeTapped = onLikeTapped
        }
    }

    private let headerView = ReviewDiscussionHeaderView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(with state: ReviewDiscussionHeaderState) {
        ReviewDiscussionTrace.log(
            "[ReviewDiscussionHeaderCardCell] configure cellClass=\(String(describing: type(of: self))) reviewId=\(state.review.id) likeCount=\(state.review.likeCount)"
        )
        headerView.configure(with: state)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onLikeTapped = nil
    }

    func containsCard(at point: CGPoint) -> Bool {
        let headerPoint = convert(point, to: headerView)
        return headerView.containsCard(at: headerPoint)
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        headerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            headerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
}

final class ReviewDiscussionSectionHeaderCell: UITableViewCell {
    static let reuseIdentifier = "ReviewDiscussionSectionHeaderCell"
    var onSortButtonTouchDown: (() -> Void)?

    let sortButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = .gpTextTertiary
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
        button.accessibilityIdentifier = "reviewDiscussion.sortButton"
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .gpSerif(ofSize: 18, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.text = L10n.tr("Localizable", "review.comment.section.title")
        return label
    }()

    private let commentCountBadgeLabel: UILabel = {
        let label = InsetLabel(insets: UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .gpTextSecondary
        label.backgroundColor = .gpSurfaceElevated
        label.layer.cornerRadius = 11
        label.layer.cornerCurve = .continuous
        label.layer.borderWidth = 1
        label.layer.borderColor = UIColor.gpSeparator.cgColor
        label.layer.masksToBounds = true
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

    override func prepareForReuse() {
        super.prepareForReuse()
        onSortButtonTouchDown = nil
    }

    func configure(with state: ReviewDiscussionSectionState, sortMenu: UIMenu?) {
        commentCountBadgeLabel.text = "\(state.commentCount)"
        var configuration = sortButton.configuration
        configuration?.title = state.sortTitle
        sortButton.configuration = configuration
        sortButton.menu = sortMenu
        sortButton.showsMenuAsPrimaryAction = true
        sortButton.isHidden = state.contentState.isEmpty
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, commentCountBadgeLabel])
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 8

        let rowStack = UIStackView(arrangedSubviews: [titleRow, sortButton])
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.distribution = .equalSpacing
        rowStack.spacing = 12
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(rowStack)
        sortButton.addTarget(self, action: #selector(didTouchDownSortButton), for: .touchDown)

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            rowStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            rowStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            rowStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }

    @objc private func didTouchDownSortButton() {
        onSortButtonTouchDown?()
    }
}

final class ReviewDiscussionEmptyStateCell: UITableViewCell {
    static let reuseIdentifier = "ReviewDiscussionEmptyStateCell"

    private let emptyStateView = ReviewDiscussionEmptyStateView()
    var onActionTapped: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(title: String, message: String, buttonTitle: String) {
        emptyStateView.configure(title: title, message: message, buttonTitle: buttonTitle)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onActionTapped = nil
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(emptyStateView)
        emptyStateView.actionButton.addTarget(self, action: #selector(didTapAction), for: .touchUpInside)

        NSLayoutConstraint.activate([
            emptyStateView.topAnchor.constraint(equalTo: contentView.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    @objc private func didTapAction() {
        onActionTapped?()
    }
}

private enum ReviewAvatarPalette {
    private static let colors: [UIColor] = [
        UIColor(hex: "#6366F1"),
        UIColor(hex: "#3B5998"),
        UIColor(hex: "#2E8B57"),
        UIColor(hex: "#8B5CF6"),
        UIColor(hex: "#E85A4F"),
        UIColor(hex: "#FFB547")
    ]

    static func color(for seed: String) -> UIColor {
        colors[abs(seed.hashValue) % colors.count]
    }
}

private final class InsetLabel: UILabel {
    private let insets: UIEdgeInsets

    init(insets: UIEdgeInsets) {
        self.insets = insets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}
