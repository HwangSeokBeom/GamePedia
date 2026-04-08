import UIKit

// MARK: - ReviewCardCell

final class ReviewCardCell: UITableViewCell {

    static let reuseId = "ReviewCardCell"
    var onLikeTapped: (() -> Void)?

    // MARK: Subviews
    private let avatarView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 14
        iv.backgroundColor = .gpSurfaceElevated
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // Initial letter shown when no avatar image is loaded
    private let avatarInitialLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .gpAvatarInitialText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let authorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .gpTextPrimary
        return label
    }()

    private let starView: StarRatingView = {
        let v = StarRatingView()
        return v
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
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let commentIconView: UIImageView = {
        let imageView = UIImageView(
            image: UIImage(systemName: "message", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
        )
        imageView.tintColor = .gpTextTertiary
        return imageView
    }()

    private let commentLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextSecondary
        return label
    }()

    private let disclosureView: UIImageView = {
        let imageView = UIImageView(
            image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
        )
        imageView.tintColor = .gpTextTertiary
        return imageView
    }()

    private let likeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = .gpTextTertiary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        configuration.imagePadding = 4
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = .systemFont(ofSize: 12, weight: .medium)
            return updated
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        let cardView = UIView()
        cardView.backgroundColor = .gpCardBackground
        cardView.layer.cornerRadius = 14
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.gpSeparator.cgColor
        cardView.clipsToBounds = true
        cardView.translatesAutoresizingMaskIntoConstraints = false

        // Avatar with initial label overlay
        avatarView.addSubview(avatarInitialLabel)

        let authorInfoStack = UIStackView(arrangedSubviews: [authorLabel, dateLabel])
        authorInfoStack.axis = .vertical
        authorInfoStack.spacing = 2

        // Left: avatar + author info
        let userStack = UIStackView(arrangedSubviews: [avatarView, authorInfoStack])
        userStack.axis = .horizontal
        userStack.spacing = 8
        userStack.alignment = .center

        let header = UIStackView(arrangedSubviews: [userStack, UIView(), starView])
        header.axis = .horizontal
        header.alignment = .center

        let footer = UIStackView(arrangedSubviews: [commentIconView, commentLabel, disclosureView, UIView(), likeButton])
        footer.axis = .horizontal
        footer.alignment = .center
        footer.spacing = 6

        let main = UIStackView(arrangedSubviews: [header, bodyLabel, footer])
        main.axis = .vertical
        main.spacing = 8
        main.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        cardView.addSubview(main)
        likeButton.addTarget(self, action: #selector(didTapLikeButton), for: .touchUpInside)

        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: 28),
            avatarView.heightAnchor.constraint(equalToConstant: 28),
            likeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),

            avatarInitialLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarInitialLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            // Card fills cell width; 12pt gap below acts as inter-card spacing
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            main.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            main.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),
            main.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            main.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14)
        ])

        likeButton.setContentHuggingPriority(.required, for: .horizontal)
        likeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        bodyLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        authorLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        dateLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    // MARK: Configure
    func configure(with review: Review) {
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
        starView.configure(rating: review.rating)
        dateLabel.text = review.formattedDate
        bodyLabel.text = review.body
        if review.body.count > 40,
           review.body.rangeOfCharacter(from: .whitespacesAndNewlines) == nil {
            print("[TextLayout] view=ReviewCardCell reviewId=\(review.id) length=\(review.body.count) unbroken=true")
        }
        commentLabel.text = review.commentCount > 0
            ? L10n.tr("Localizable", "review.card.commentCta", review.commentCount)
            : L10n.tr("Localizable", "review.card.commentEmptyCta")
        commentLabel.textColor = review.commentCount > 0 ? .gpTextSecondary : .gpPrimary

        var likeConfiguration = likeButton.configuration
        likeConfiguration?.title = String(review.likeCount)
        likeConfiguration?.image = UIImage(
            systemName: review.isLikedByCurrentUser ? "heart.fill" : "heart",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        )
        likeConfiguration?.baseForegroundColor = review.isLikedByCurrentUser ? .gpCoral : .gpTextTertiary
        likeButton.configuration = likeConfiguration
        likeButton.alpha = review.likeCount == 0 && !review.isLikedByCurrentUser ? 0.72 : 1
        likeButton.accessibilityLabel = L10n.tr(
            "Localizable",
            "review.card.accessibility.like",
            String(review.likeCount)
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.cancelLoad()
        avatarView.image = nil
        avatarInitialLabel.text = nil
        authorLabel.text = nil
        dateLabel.text = nil
        bodyLabel.text = nil
        commentLabel.text = nil
        var likeConfiguration = likeButton.configuration
        likeConfiguration?.title = nil
        likeConfiguration?.image = UIImage(
            systemName: "heart",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        )
        likeConfiguration?.baseForegroundColor = .gpTextTertiary
        likeButton.configuration = likeConfiguration
        likeButton.alpha = 1
        likeButton.accessibilityLabel = nil
        onLikeTapped = nil
    }

    @objc private func didTapLikeButton() {
        onLikeTapped?()
    }
}
