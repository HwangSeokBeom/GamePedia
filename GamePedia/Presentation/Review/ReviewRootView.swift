import UIKit

// MARK: - ReviewRootView

final class ReviewRootView: UIView {

    private enum UIConstants {
        static let placeholderText = L10n.Review.Placeholder.content
        static let horizontalInset: CGFloat = 20
        static let verticalSpacing: CGFloat = 24
        static let submitButtonHeight: CGFloat = 52
        static let contentBottomInset: CGFloat = 24
    }

    private let contentStackView = UIStackView()
    private let composeTitleLabel = UILabel()
    private let bannerIconView = UIImageView()
    private let bannerLabel = UILabel()
    private let bannerView = UIView()
    private let bannerContentView = UIStackView()
    private let reviewTextContainerView = UIView()
    private let spoilerLabel = UILabel()
    private let validationMessageLabel = UILabel()
    private let submitSpacerView = UIView()

    // MARK: Subviews
    let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .gpBackground
        scrollView.keyboardDismissMode = .interactive
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    let closeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: "xmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        )
        configuration.baseForegroundColor = .gpTextPrimary
        configuration.contentInsets = .zero
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let gameThumbnailView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10
        imageView.layer.cornerCurve = .continuous
        imageView.backgroundColor = .gpSurfaceElevated
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    let gameTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        return label
    }()

    let gameDeveloperLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        return label
    }()

    let ratingPromptLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.Review.Prompt.rateGame
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.textAlignment = .center
        return label
    }()

    let starRatingView = InteractiveStarRatingView()

    let ratingDisplayLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.Review.Prompt.selectRating
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .gpTextTertiary
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    let reviewTitleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.Review.Label.content
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .gpTextPrimary
        return label
    }()

    let reviewTextView: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.textColor = .gpTextPrimary
        textView.font = .systemFont(ofSize: 14)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 14, bottom: 14, right: 14)
        textView.tintColor = .gpPrimary
        textView.keyboardAppearance = .default
        textView.showsVerticalScrollIndicator = true
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    private let reviewPlaceholderLabel: UILabel = {
        let label = UILabel()
        label.text = UIConstants.placeholderText
        label.font = .systemFont(ofSize: 14)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let charCountLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.Review.Count.characters(0, 500)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextTertiary
        label.textAlignment = .natural
        return label
    }()

    let spoilerToggleControl = ReviewSpoilerToggleControl()

    let submitButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = L10n.Review.Button.submit
        configuration.imagePadding = 8
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .gpOnPrimary
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isExclusiveTouch = true
        button.layer.shadowOffset = CGSize(width: 0, height: 8)
        button.layer.shadowRadius = 24
        button.layer.shadowOpacity = 0.35
        return button
    }()

    let deleteButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = L10n.Review.Button.delete
        configuration.baseBackgroundColor = .gpSurfaceElevated
        configuration.baseForegroundColor = .gpCoral
        configuration.cornerStyle = .capsule
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        applyDynamicLayerColors(isTextViewFocused: reviewTextView.isFirstResponder)
    }

    // MARK: Setup
    private func setup() {
        backgroundColor = .gpBackground

        composeTitleLabel.font = .gpSerif(ofSize: 20, weight: .semibold)
        composeTitleLabel.textColor = .gpTextPrimary
        composeTitleLabel.textAlignment = .center

        let headerRow = UIStackView(arrangedSubviews: [closeButton, composeTitleLabel, submitSpacerView])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        bannerIconView.contentMode = .scaleAspectFit
        bannerIconView.tintColor = .gpPrimary
        bannerIconView.translatesAutoresizingMaskIntoConstraints = false

        bannerLabel.font = .systemFont(ofSize: 13, weight: .medium)
        bannerLabel.textColor = .gpPrimary
        bannerLabel.numberOfLines = 2

        bannerContentView.axis = .horizontal
        bannerContentView.alignment = .center
        bannerContentView.spacing = 8
        bannerContentView.translatesAutoresizingMaskIntoConstraints = false
        bannerContentView.addArrangedSubview(bannerIconView)
        bannerContentView.addArrangedSubview(bannerLabel)

        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.addSubview(bannerContentView)

        let gameInfoStack = UIStackView(arrangedSubviews: [gameTitleLabel, gameDeveloperLabel])
        gameInfoStack.axis = .vertical
        gameInfoStack.spacing = 3

        let gameRow = UIStackView(arrangedSubviews: [gameThumbnailView, gameInfoStack])
        gameRow.axis = .horizontal
        gameRow.spacing = 14
        gameRow.alignment = .center
        gameRow.backgroundColor = .gpCardBackground
        gameRow.layer.cornerRadius = 14
        gameRow.layer.cornerCurve = .continuous
        gameRow.layer.borderWidth = 1
        gameRow.layer.borderColor = UIColor.gpSeparator.cgColor
        gameRow.isLayoutMarginsRelativeArrangement = true
        gameRow.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)

        let ratingSection = UIStackView(arrangedSubviews: [ratingPromptLabel, starRatingView, ratingDisplayLabel])
        ratingSection.axis = .vertical
        ratingSection.spacing = 12
        ratingSection.alignment = .center

        reviewTextContainerView.backgroundColor = .gpCardBackground
        reviewTextContainerView.layer.cornerRadius = 14
        reviewTextContainerView.layer.cornerCurve = .continuous
        reviewTextContainerView.layer.borderWidth = 1
        reviewTextContainerView.translatesAutoresizingMaskIntoConstraints = false
        reviewTextContainerView.addSubview(reviewTextView)
        reviewTextContainerView.addSubview(reviewPlaceholderLabel)

        validationMessageLabel.font = .systemFont(ofSize: 12, weight: .medium)
        validationMessageLabel.textColor = .gpOrange
        validationMessageLabel.numberOfLines = 0
        validationMessageLabel.isHidden = true

        spoilerLabel.text = L10n.tr("Localizable", "review.toggle.spoiler")
        spoilerLabel.font = .systemFont(ofSize: 14, weight: .medium)
        spoilerLabel.textColor = .gpTextPrimary

        let spoilerRow = UIStackView(arrangedSubviews: [spoilerLabel, UIView(), spoilerToggleControl])
        spoilerRow.axis = .horizontal
        spoilerRow.alignment = .center
        spoilerRow.backgroundColor = .gpCardBackground
        spoilerRow.layer.cornerRadius = 12
        spoilerRow.layer.cornerCurve = .continuous
        spoilerRow.isLayoutMarginsRelativeArrangement = true
        spoilerRow.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)

        contentStackView.axis = .vertical
        contentStackView.spacing = UIConstants.verticalSpacing
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(gameRow)
        contentStackView.addArrangedSubview(ratingSection)
        contentStackView.addArrangedSubview(reviewTitleLabel)
        contentStackView.addArrangedSubview(reviewTextContainerView)
        contentStackView.addArrangedSubview(charCountLabel)
        contentStackView.addArrangedSubview(validationMessageLabel)
        contentStackView.addArrangedSubview(spoilerRow)
        contentStackView.addArrangedSubview(submitButton)
        contentStackView.addArrangedSubview(deleteButton)
        contentStackView.setCustomSpacing(10, after: reviewTitleLabel)
        contentStackView.setCustomSpacing(6, after: reviewTextContainerView)
        contentStackView.setCustomSpacing(6, after: charCountLabel)
        contentStackView.setCustomSpacing(18, after: validationMessageLabel)

        addSubview(scrollView)
        scrollView.addSubview(headerRow)
        scrollView.addSubview(bannerView)
        scrollView.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            headerRow.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            headerRow.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: UIConstants.horizontalInset),
            headerRow.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -UIConstants.horizontalInset),

            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),
            submitSpacerView.widthAnchor.constraint(equalTo: closeButton.widthAnchor),

            bannerView.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 12),
            bannerView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),

            bannerContentView.topAnchor.constraint(equalTo: bannerView.topAnchor, constant: 10),
            bannerContentView.bottomAnchor.constraint(equalTo: bannerView.bottomAnchor, constant: -10),
            bannerContentView.leadingAnchor.constraint(equalTo: bannerView.leadingAnchor, constant: UIConstants.horizontalInset),
            bannerContentView.trailingAnchor.constraint(equalTo: bannerView.trailingAnchor, constant: -UIConstants.horizontalInset),
            bannerIconView.widthAnchor.constraint(equalToConstant: 16),
            bannerIconView.heightAnchor.constraint(equalToConstant: 16),

            contentStackView.topAnchor.constraint(equalTo: bannerView.bottomAnchor, constant: 12),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: UIConstants.horizontalInset),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -UIConstants.horizontalInset),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -UIConstants.contentBottomInset),

            gameThumbnailView.widthAnchor.constraint(equalToConstant: 56),
            gameThumbnailView.heightAnchor.constraint(equalToConstant: 56),

            reviewTextContainerView.heightAnchor.constraint(equalToConstant: 140),
            reviewTextView.topAnchor.constraint(equalTo: reviewTextContainerView.topAnchor),
            reviewTextView.leadingAnchor.constraint(equalTo: reviewTextContainerView.leadingAnchor),
            reviewTextView.trailingAnchor.constraint(equalTo: reviewTextContainerView.trailingAnchor),
            reviewTextView.bottomAnchor.constraint(equalTo: reviewTextContainerView.bottomAnchor),

            reviewPlaceholderLabel.topAnchor.constraint(equalTo: reviewTextContainerView.topAnchor, constant: 16),
            reviewPlaceholderLabel.leadingAnchor.constraint(equalTo: reviewTextContainerView.leadingAnchor, constant: 18),
            reviewPlaceholderLabel.trailingAnchor.constraint(equalTo: reviewTextContainerView.trailingAnchor, constant: -18),

            submitButton.heightAnchor.constraint(equalToConstant: UIConstants.submitButtonHeight),
            deleteButton.heightAnchor.constraint(equalToConstant: UIConstants.submitButtonHeight)
        ])

        applyDynamicLayerColors(isTextViewFocused: false)
    }

    // MARK: - State Rendering
    func render(_ state: ReviewState) {
        composeTitleLabel.text = state.navigationTitle
        gameTitleLabel.text = state.gameName
        gameDeveloperLabel.text = state.gameSubtitle
        gameDeveloperLabel.isHidden = state.gameSubtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        gameThumbnailView.loadImage(url: URL(string: state.gameThumbnailURL))

        let accentColor = state.isEditing ? UIColor.gpStar : .gpPrimary
        let bannerBackground = accentColor.withAlphaComponent(0.14)
        bannerView.backgroundColor = bannerBackground
        bannerIconView.image = UIImage(
            systemName: state.isEditing ? "pencil" : "plus.circle",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        )
        bannerIconView.tintColor = accentColor
        bannerLabel.text = state.modeBannerText
        bannerLabel.textColor = accentColor

        starRatingView.setRating(state.rating)
        ratingDisplayLabel.text = state.hasSelectedRating ? state.formattedRating : L10n.Review.Prompt.selectRating
        ratingDisplayLabel.textColor = state.hasSelectedRating ? accentColor : .gpTextTertiary

        if reviewTextView.text != state.reviewText {
            reviewTextView.text = state.reviewText
        }
        reviewPlaceholderLabel.isHidden = !state.reviewText.isEmpty
        charCountLabel.text = state.formattedCharCount
        charCountLabel.textColor = state.charCount >= state.maxChars ? .gpOrange : .gpTextTertiary
        validationMessageLabel.text = state.validationMessage
        validationMessageLabel.isHidden = state.validationMessage == nil || state.isProcessing
        reviewTextView.isEditable = !state.isProcessing
        starRatingView.isUserInteractionEnabled = !state.isProcessing
        spoilerToggleControl.isUserInteractionEnabled = !state.isProcessing
        spoilerToggleControl.setOn(state.isSpoilerEnabled, animated: false)

        updateSubmitButton(using: state, accentColor: accentColor)
        updateDeleteButton(using: state)
    }

    func setReviewTextInputFocused(_ isFocused: Bool) {
        applyDynamicLayerColors(isTextViewFocused: isFocused)
    }

    func setSubmitAreaBottomInset(_ inset: CGFloat) {
        let bottomInset = UIConstants.contentBottomInset + max(0, inset)
        scrollView.contentInset.bottom = bottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    private func updateSubmitButton(using state: ReviewState, accentColor: UIColor) {
        let allowsTap = !state.isProcessing
        var configuration = submitButton.configuration
        configuration?.title = state.isSubmitting ? state.submitLoadingTitle : state.submitButtonTitle
        configuration?.image = state.isSubmitting
            ? nil
            : UIImage(
                systemName: state.isEditing ? "checkmark" : "paperplane",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            )
        configuration?.showsActivityIndicator = state.isSubmitting
        configuration?.baseBackgroundColor = state.submitEnabled ? accentColor : .gpSurfaceElevated
        configuration?.baseForegroundColor = state.submitEnabled ? (state.isEditing ? .gpBackground : .gpOnPrimary) : .gpTextTertiary
        submitButton.configuration = configuration
        submitButton.isEnabled = allowsTap
        submitButton.alpha = state.submitEnabled || state.isSubmitting ? 1 : 0.76
        submitButton.layer.shadowOpacity = state.submitEnabled ? 0.3 : 0
        submitButton.layer.shadowColor = accentColor.resolvedCGColor(with: traitCollection)
    }

    private func updateDeleteButton(using state: ReviewState) {
        var configuration = deleteButton.configuration
        configuration?.title = state.deleteButtonTitle
        configuration?.image = state.isDeleting
            ? nil
            : UIImage(
                systemName: "trash",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            )
        configuration?.imagePadding = 8
        configuration?.showsActivityIndicator = state.isDeleting
        configuration?.baseBackgroundColor = UIColor.gpCoral.withAlphaComponent(0.12)
        configuration?.baseForegroundColor = .gpCoral
        deleteButton.configuration = configuration
        deleteButton.isHidden = !state.isEditing
        deleteButton.isEnabled = state.isEditing && !state.isProcessing
        deleteButton.alpha = state.isProcessing && !state.isDeleting ? 0.72 : 1
    }

    private func applyDynamicLayerColors(isTextViewFocused: Bool) {
        reviewTextContainerView.layer.borderColor = (isTextViewFocused ? UIColor.gpPrimary : .gpBorder)
            .resolvedCGColor(with: traitCollection)
        reviewTextContainerView.layer.shadowColor = isTextViewFocused
            ? UIColor.gpPrimary.withAlphaComponent(0.22).resolvedCGColor(with: traitCollection)
            : UIColor.clear.cgColor
        reviewTextContainerView.layer.shadowOpacity = isTextViewFocused ? 1 : 0
        reviewTextContainerView.layer.shadowRadius = isTextViewFocused ? 14 : 0
        reviewTextContainerView.layer.shadowOffset = .zero
    }
}

final class ReviewSpoilerToggleControl: UIControl {
    private let backgroundView = UIView()
    private let thumbView = UIView()
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!

    private(set) var isOn: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)
        backgroundView.addSubview(thumbView)

        backgroundView.layer.cornerRadius = 14
        backgroundView.layer.cornerCurve = .continuous
        backgroundView.translatesAutoresizingMaskIntoConstraints = false

        thumbView.backgroundColor = .white
        thumbView.layer.cornerRadius = 12
        thumbView.layer.cornerCurve = .continuous
        thumbView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 48),
            heightAnchor.constraint(equalToConstant: 28),

            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            thumbView.widthAnchor.constraint(equalToConstant: 24),
            thumbView.heightAnchor.constraint(equalToConstant: 24),
            thumbView.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor)
        ])

        leadingConstraint = thumbView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 2)
        trailingConstraint = thumbView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -2)
        leadingConstraint.isActive = true

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapToggle)))
        setOn(false, animated: false)
    }

    func setOn(_ isOn: Bool, animated: Bool) {
        self.isOn = isOn
        leadingConstraint.isActive = !isOn
        trailingConstraint.isActive = isOn
        backgroundView.backgroundColor = isOn ? .gpSuccess : .gpSeparator

        let updates = { self.layoutIfNeeded() }
        if animated {
            UIView.animate(withDuration: 0.18, animations: updates)
        } else {
            updates()
        }
    }

    @objc private func didTapToggle() {
        guard isUserInteractionEnabled else { return }
        setOn(!isOn, animated: true)
        sendActions(for: .valueChanged)
    }
}
