import UIKit

// MARK: - ReviewCardCell

final class ReviewCardCell: UITableViewCell {

    static let reuseId = "ReviewCardCell"

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
        label.numberOfLines = 3
        return label
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

        let main = UIStackView(arrangedSubviews: [header, bodyLabel])
        main.axis = .vertical
        main.spacing = 8
        main.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        cardView.addSubview(main)

        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: 28),
            avatarView.heightAnchor.constraint(equalToConstant: 28),

            avatarInitialLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarInitialLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            // Card fills cell width; 12pt gap below acts as inter-card spacing
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            main.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            main.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),
            main.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            main.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14)
        ])
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
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.cancelLoad()
        avatarView.image = nil
        avatarInitialLabel.text = nil
    }
}
