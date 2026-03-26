import UIKit

// MARK: - ReviewRootView

final class ReviewRootView: UIView {

    // MARK: Subviews
    let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.keyboardDismissMode = .interactive
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
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
        label.text = "0.0 / 5.0"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .gpTextSecondary
        label.textAlignment = .center
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
        tv.layer.borderColor = UIColor.gpSeparator.cgColor
        tv.textContainerInset = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    let charCountLabel: UILabel = {
        let label = UILabel()
        label.text = "0 / 500자"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextTertiary
        label.textAlignment = .natural
        return label
    }()

    // Spoiler toggle
    let spoilerLabel: UILabel = {
        let label = UILabel()
        label.text = "스포일러 포함"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .gpTextPrimary
        return label
    }()

    let spoilerSwitch: UISwitch = {
        let s = UISwitch()
        s.onTintColor = UIColor(hex: "#4ECDC4")
        return s
    }()

    // Submit
    let submitButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "리뷰 등록하기"
        config.image = UIImage(systemName: "paperplane")
        config.imagePadding = 8
        config.baseBackgroundColor = .gpPrimary
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        // Purple glow shadow matching wireframe
        button.layer.shadowColor = UIColor.gpPrimary.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 8)
        button.layer.shadowRadius = 12
        button.layer.shadowOpacity = 0.35
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

    // MARK: Setup
    private func setup() {
        backgroundColor = .gpBackground
        addSubview(scrollView)
        addSubview(submitButton)

        // Game info card
        let gameInfoStack = UIStackView(arrangedSubviews: [gameTitleLabel, gameDeveloperLabel])
        gameInfoStack.axis = .vertical
        gameInfoStack.spacing = 3

        let gameRow = UIStackView(arrangedSubviews: [gameThumbnailView, gameInfoStack])
        gameRow.axis = .horizontal
        gameRow.spacing = 14
        gameRow.alignment = .center
        gameRow.backgroundColor = .gpSurfaceElevated
        gameRow.layer.cornerRadius = 14
        gameRow.clipsToBounds = true
        gameRow.isLayoutMarginsRelativeArrangement = true
        gameRow.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)

        // Rating section
        let ratingSection = UIStackView(arrangedSubviews: [ratingPromptLabel, starRatingView, ratingDisplayLabel])
        ratingSection.axis = .vertical
        ratingSection.spacing = 12
        ratingSection.alignment = .center

        // Spoiler card row
        let spoilerRow = UIStackView(arrangedSubviews: [spoilerLabel, UIView(), spoilerSwitch])
        spoilerRow.axis = .horizontal
        spoilerRow.alignment = .center
        spoilerRow.backgroundColor = .gpSurfaceElevated
        spoilerRow.layer.cornerRadius = 12
        spoilerRow.clipsToBounds = true
        spoilerRow.isLayoutMarginsRelativeArrangement = true
        spoilerRow.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)

        // Content stack — no divider between game card and rating
        let contentStack = UIStackView(arrangedSubviews: [
            gameRow, ratingSection,
            reviewTitleLabel, reviewTextView, charCountLabel,
            spoilerRow
        ])
        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.setCustomSpacing(8, after: reviewTitleLabel)
        contentStack.setCustomSpacing(4, after: reviewTextView)

        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: submitButton.topAnchor, constant: -16),

            gameThumbnailView.widthAnchor.constraint(equalToConstant: 56),
            gameThumbnailView.heightAnchor.constraint(equalToConstant: 56),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),

            reviewTextView.heightAnchor.constraint(equalToConstant: 140),

            submitButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            submitButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            submitButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            submitButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    // MARK: - State Rendering

    func render(_ state: ReviewState) {
        gameTitleLabel.text = state.gameName
        gameDeveloperLabel.text = state.gameSubtitle
        gameThumbnailView.loadImage(url: URL(string: state.gameThumbnailURL))

        starRatingView.setRating(state.rating)
        ratingDisplayLabel.text = state.formattedRating
        charCountLabel.text = state.formattedCharCount
        spoilerSwitch.isOn = state.isSpoiler

        submitButton.isEnabled = state.submitEnabled
        submitButton.alpha = state.submitEnabled ? 1 : 0.5

        if state.isSubmitting {
            submitButton.configuration?.showsActivityIndicator = true
        } else {
            submitButton.configuration?.showsActivityIndicator = false
        }
    }
}
