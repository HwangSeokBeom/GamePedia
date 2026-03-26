import UIKit

final class GameReviewCell: UITableViewCell {

    static let reuseIdentifier = "GameReviewCell"

    var onMoreButtonTapped: (() -> Void)?

    private let avatarView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        imageView.backgroundColor = .gpSurface
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let avatarInitialLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let authorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .gpTextPrimary
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .gpTextTertiary
        return label
    }()

    private let starView = StarRatingView()

    private let contentLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        return label
    }()

    private let moreButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: "ellipsis",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        )
        configuration.baseForegroundColor = .gpTextTertiary
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

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
        cardView.backgroundColor = .gpSurfaceElevated
        cardView.layer.cornerRadius = 16
        cardView.translatesAutoresizingMaskIntoConstraints = false

        avatarView.addSubview(avatarInitialLabel)

        let authorInfoStack = UIStackView(arrangedSubviews: [authorLabel, dateLabel])
        authorInfoStack.axis = .vertical
        authorInfoStack.spacing = 2

        let userStack = UIStackView(arrangedSubviews: [avatarView, authorInfoStack])
        userStack.axis = .horizontal
        userStack.alignment = .center
        userStack.spacing = 10

        let topRow = UIStackView(arrangedSubviews: [userStack, UIView(), starView, moreButton])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 8

        let contentStack = UIStackView(arrangedSubviews: [topRow, contentLabel])
        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        cardView.addSubview(contentStack)

        moreButton.addTarget(self, action: #selector(didTapMoreButton), for: .touchUpInside)

        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: 32),
            avatarView.heightAnchor.constraint(equalToConstant: 32),

            avatarInitialLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarInitialLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            moreButton.widthAnchor.constraint(equalToConstant: 28),
            moreButton.heightAnchor.constraint(equalToConstant: 28),

            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

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
        dateLabel.text = review.formattedDate
        starView.configure(rating: review.rating)
        contentLabel.text = review.content
        moreButton.isHidden = false
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.cancelLoad()
        avatarView.image = nil
        avatarInitialLabel.text = nil
        onMoreButtonTapped = nil
    }

    @objc private func didTapMoreButton() {
        onMoreButtonTapped?()
    }
}
