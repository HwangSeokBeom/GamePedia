import UIKit

// MARK: - ReviewRootView

final class ReviewRootView: UIView {

    private enum UIConstants {
        static let placeholderText = "플레이 경험, 좋았던 점, 아쉬운 점을 자유롭게 남겨보세요."
        static let submitAreaHorizontalInset: CGFloat = 20
        static let submitAreaVerticalInset: CGFloat = 12
        static let submitButtonHeight: CGFloat = 56
        static let submitButtonSpacing: CGFloat = 12
    }

    private var submitAreaBottomConstraint: NSLayoutConstraint?
    private var lastLoggedSubmitEnabledState: Bool?

    // MARK: Subviews
    let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.keyboardDismissMode = .interactive
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let submitAreaView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpBackground
        view.isUserInteractionEnabled = true
        view.layer.shadowOpacity = 0.18
        view.layer.shadowRadius = 18
        view.layer.shadowOffset = CGSize(width: 0, height: -6)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let submitAreaSeparatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSeparator.withAlphaComponent(0.7)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // Game info row
    let gameThumbnailView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 10
        iv.backgroundColor = .gpSurfaceElevated
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
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
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        return label
    }()

    // Rating
    let ratingPromptLabel: UILabel = {
        let label = UILabel()
        label.text = "이 게임의 평점을 남겨주세요"
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.textAlignment = .center
        return label
    }()

    let starRatingView: InteractiveStarRatingView = {
        let v = InteractiveStarRatingView()
        return v
    }()

    let ratingDisplayLabel: UILabel = {
        let label = UILabel()
        label.text = "별점을 선택해주세요"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .gpTextTertiary
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    // Text
    let reviewTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "리뷰 내용"
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .gpTextPrimary
        return label
    }()

    let reviewTextView: UITextView = {
        let tv = UITextView()
        tv.backgroundColor = .gpSurfaceElevated
        tv.textColor = .gpTextPrimary
        tv.font = .systemFont(ofSize: 14)
        tv.layer.cornerRadius = 14
        tv.layer.borderWidth = 1
        tv.textContainerInset = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        tv.tintColor = .gpPrimary
        tv.keyboardAppearance = .default
        tv.showsVerticalScrollIndicator = true
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
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
        label.text = "0 / 500자"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextTertiary
        label.textAlignment = .natural
        return label
    }()

    private let validationMessageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemOrange
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    // Submit
    let submitButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "리뷰 작성하기"
        config.image = UIImage(systemName: "square.and.pencil")
        config.imagePadding = 8
        config.baseBackgroundColor = .gpPrimary
        config.baseForegroundColor = .gpOnPrimary
        config.cornerStyle = .capsule
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isUserInteractionEnabled = true
        button.isExclusiveTouch = true
        button.layer.shadowOffset = CGSize(width: 0, height: 8)
        button.layer.shadowRadius = 12
        button.layer.shadowOpacity = 0.35
        return button
    }()

    let deleteButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "삭제"
        configuration.baseBackgroundColor = .gpSurfaceElevated
        configuration.baseForegroundColor = .gpCoral
        configuration.cornerStyle = .capsule
        configuration.background.strokeColor = UIColor.gpCoral.withAlphaComponent(0.35)
        configuration.background.strokeWidth = 1
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isUserInteractionEnabled = true
        button.isExclusiveTouch = true
        button.isHidden = true
        return button
    }()

    private lazy var ctaStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [deleteButton, submitButton])
        stackView.axis = .horizontal
        stackView.spacing = UIConstants.submitButtonSpacing
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
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
        addSubview(scrollView)
        addSubview(submitAreaView)
        bringSubviewToFront(submitAreaView)
        reviewTextView.addSubview(reviewPlaceholderLabel)
        submitAreaView.addSubview(submitAreaSeparatorView)
        submitAreaView.addSubview(ctaStackView)

        // Game info card
        let gameInfoStack = UIStackView(arrangedSubviews: [gameTitleLabel, gameDeveloperLabel])
        gameInfoStack.axis = .vertical
        gameInfoStack.spacing = 3

        let gameRow = UIStackView(arrangedSubviews: [gameThumbnailView, gameInfoStack])
        gameRow.axis = .horizontal
        gameRow.spacing = 14
        gameRow.alignment = .center
        gameRow.backgroundColor = .gpCardBackground
        gameRow.layer.cornerRadius = 14
        gameRow.clipsToBounds = true
        gameRow.isLayoutMarginsRelativeArrangement = true
        gameRow.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)

        // Rating section
        let ratingSection = UIStackView(arrangedSubviews: [ratingPromptLabel, starRatingView, ratingDisplayLabel])
        ratingSection.axis = .vertical
        ratingSection.spacing = 12
        ratingSection.alignment = .center

        // Content stack — no divider between game card and rating
        let contentStack = UIStackView(arrangedSubviews: [
            gameRow, ratingSection,
            reviewTitleLabel, reviewTextView, charCountLabel, validationMessageLabel
        ])
        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.setCustomSpacing(8, after: reviewTitleLabel)
        contentStack.setCustomSpacing(4, after: reviewTextView)

        scrollView.addSubview(contentStack)

        submitAreaBottomConstraint = submitAreaView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: submitAreaView.topAnchor),

            submitAreaView.leadingAnchor.constraint(equalTo: leadingAnchor),
            submitAreaView.trailingAnchor.constraint(equalTo: trailingAnchor),
            submitAreaView.topAnchor.constraint(equalTo: scrollView.bottomAnchor),
            submitAreaBottomConstraint!,

            submitAreaSeparatorView.topAnchor.constraint(equalTo: submitAreaView.topAnchor),
            submitAreaSeparatorView.leadingAnchor.constraint(equalTo: submitAreaView.leadingAnchor),
            submitAreaSeparatorView.trailingAnchor.constraint(equalTo: submitAreaView.trailingAnchor),
            submitAreaSeparatorView.heightAnchor.constraint(equalToConstant: 1),

            gameThumbnailView.widthAnchor.constraint(equalToConstant: 56),
            gameThumbnailView.heightAnchor.constraint(equalToConstant: 56),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),

            reviewTextView.heightAnchor.constraint(equalToConstant: 140),

            reviewPlaceholderLabel.topAnchor.constraint(equalTo: reviewTextView.topAnchor, constant: 14),
            reviewPlaceholderLabel.leadingAnchor.constraint(equalTo: reviewTextView.leadingAnchor, constant: 19),
            reviewPlaceholderLabel.trailingAnchor.constraint(equalTo: reviewTextView.trailingAnchor, constant: -19),

            ctaStackView.topAnchor.constraint(equalTo: submitAreaView.topAnchor, constant: UIConstants.submitAreaVerticalInset),
            ctaStackView.leadingAnchor.constraint(equalTo: submitAreaView.leadingAnchor, constant: UIConstants.submitAreaHorizontalInset),
            ctaStackView.trailingAnchor.constraint(equalTo: submitAreaView.trailingAnchor, constant: -UIConstants.submitAreaHorizontalInset),
            ctaStackView.bottomAnchor.constraint(equalTo: submitAreaView.bottomAnchor, constant: -UIConstants.submitAreaVerticalInset),

            submitButton.heightAnchor.constraint(equalToConstant: UIConstants.submitButtonHeight),
            deleteButton.heightAnchor.constraint(equalToConstant: UIConstants.submitButtonHeight)
        ])

        applyDynamicLayerColors(isTextViewFocused: false)
    }

    // MARK: - State Rendering

    func render(_ state: ReviewState) {
        gameTitleLabel.text = state.gameName
        gameDeveloperLabel.text = state.gameSubtitle
        gameDeveloperLabel.isHidden = state.gameSubtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        gameThumbnailView.loadImage(url: URL(string: state.gameThumbnailURL))

        starRatingView.setRating(state.rating)
        ratingDisplayLabel.text = state.hasSelectedRating ? state.formattedRating : "별점을 선택해주세요"
        ratingDisplayLabel.textColor = state.hasSelectedRating ? .gpPrimary : .gpTextTertiary

        if reviewTextView.text != state.reviewText {
            reviewTextView.text = state.reviewText
        }
        reviewPlaceholderLabel.isHidden = !state.reviewText.isEmpty
        charCountLabel.text = state.formattedCharCount
        charCountLabel.textColor = state.charCount >= state.maxChars ? .systemOrange : .gpTextTertiary
        validationMessageLabel.text = state.validationMessage
        validationMessageLabel.isHidden = state.validationMessage == nil || state.isProcessing
        reviewTextView.isEditable = !state.isProcessing
        starRatingView.isUserInteractionEnabled = !state.isProcessing

        updateCTALayout(using: state)
        updateSubmitButton(using: state)
        updateDeleteButton(using: state)
    }

    func setReviewTextInputFocused(_ isFocused: Bool) {
        applyDynamicLayerColors(isTextViewFocused: isFocused)
    }

    func setSubmitAreaBottomInset(_ inset: CGFloat) {
        submitAreaBottomConstraint?.constant = -inset
    }

    private func updateSubmitButton(using state: ReviewState) {
        let allowsTap = !state.isProcessing
        if lastLoggedSubmitEnabledState != allowsTap {
            print("[ReviewSubmit] submitButtonStateChanged allowsTap=\(allowsTap) submitEnabled=\(state.submitEnabled) isProcessing=\(state.isProcessing) rating=\(state.rating) trimmedCount=\(state.trimmedReviewText.count) validationMessage=\(state.validationMessage ?? "nil")")
            lastLoggedSubmitEnabledState = allowsTap
        }
        var configuration = submitButton.configuration
        configuration?.title = state.isSubmitting ? state.submitLoadingTitle : state.submitButtonTitle
        configuration?.image = state.isSubmitting ? nil : UIImage(systemName: state.isEditing ? "square.and.arrow.down" : "square.and.pencil")
        configuration?.showsActivityIndicator = state.isSubmitting
        configuration?.baseBackgroundColor = state.submitEnabled ? .gpPrimary : .gpSurfaceElevated
        configuration?.baseForegroundColor = state.submitEnabled ? .gpOnPrimary : .gpTextTertiary
        submitButton.configuration = configuration
        submitButton.isEnabled = allowsTap
        submitButton.alpha = state.submitEnabled || state.isSubmitting ? 1 : 0.72
        submitButton.layer.shadowOpacity = state.submitEnabled ? 0.35 : 0
    }

    private func updateDeleteButton(using state: ReviewState) {
        var configuration = deleteButton.configuration
        configuration?.title = state.deleteButtonTitle
        configuration?.image = nil
        configuration?.showsActivityIndicator = state.isDeleting
        configuration?.baseBackgroundColor = .gpSurfaceElevated
        configuration?.baseForegroundColor = .gpCoral
        configuration?.background.strokeColor = UIColor.gpCoral.withAlphaComponent(state.isProcessing ? 0.18 : 0.35)
        configuration?.background.strokeWidth = 1
        deleteButton.configuration = configuration
        deleteButton.isEnabled = state.isEditing && !state.isProcessing
        deleteButton.alpha = state.isEditing ? (state.isProcessing ? 0.65 : 1) : 0
    }

    private func updateCTALayout(using state: ReviewState) {
        deleteButton.isHidden = !state.isEditing
        submitAreaSeparatorView.isHidden = false
        setNeedsLayout()
    }

    private func applyDynamicLayerColors(isTextViewFocused: Bool) {
        submitAreaView.layer.shadowColor = UIColor.gpShadow.resolvedCGColor(with: traitCollection)
        reviewTextView.layer.borderColor = (isTextViewFocused ? UIColor.gpPrimary : .gpBorder).resolvedCGColor(with: traitCollection)
        reviewTextView.layer.shadowColor = isTextViewFocused
            ? UIColor.gpPrimary.withAlphaComponent(0.24).resolvedCGColor(with: traitCollection)
            : UIColor.clear.cgColor
        reviewTextView.layer.shadowOpacity = isTextViewFocused ? 1 : 0
        reviewTextView.layer.shadowRadius = isTextViewFocused ? 10 : 0
        reviewTextView.layer.shadowOffset = .zero
        submitButton.layer.shadowColor = UIColor.gpPrimary.resolvedCGColor(with: traitCollection)
    }
}
