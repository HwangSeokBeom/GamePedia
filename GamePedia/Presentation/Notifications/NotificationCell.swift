import UIKit

final class NotificationCell: UITableViewCell {
    static let reuseID = "NotificationCell"

    private let iconContainerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 18
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let unreadDotView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpPrimary
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .gpTextTertiary
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with notification: AppNotification) {
        titleLabel.text = notification.title
        messageLabel.text = notification.message
        dateLabel.text = notification.relativeCreatedAtText
        unreadDotView.isHidden = notification.isRead
        configureIcon(for: notification.kind)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        unreadDotView.isHidden = true
    }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        let cardView = UIView()
        cardView.backgroundColor = .gpCardBackground
        cardView.layer.cornerRadius = 16
        cardView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView(arrangedSubviews: [titleLabel, messageLabel, dateLabel])
        stackView.axis = .vertical
        stackView.spacing = 6
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        cardView.addSubview(iconContainerView)
        iconContainerView.addSubview(iconImageView)
        cardView.addSubview(unreadDotView)
        cardView.addSubview(stackView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            iconContainerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            iconContainerView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconContainerView.widthAnchor.constraint(equalToConstant: 36),
            iconContainerView.heightAnchor.constraint(equalToConstant: 36),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),

            unreadDotView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            unreadDotView.leadingAnchor.constraint(equalTo: iconContainerView.trailingAnchor, constant: 12),
            unreadDotView.widthAnchor.constraint(equalToConstant: 8),
            unreadDotView.heightAnchor.constraint(equalToConstant: 8),

            stackView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            stackView.leadingAnchor.constraint(equalTo: unreadDotView.trailingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14)
        ])
    }

    private func configureIcon(for kind: AppNotification.Kind) {
        let iconName: String
        let tintColor: UIColor

        switch kind {
        case .friendRequestReceived:
            iconName = "person.crop.circle.badge.plus"
            tintColor = .gpPrimary
        case .friendRequestAccepted:
            iconName = "person.2.fill"
            tintColor = .gpTeal
        case .friendReviewReaction:
            iconName = "bubble.left.and.text.bubble.right.fill"
            tintColor = .gpCoral
        case .friendStartedPlaying:
            iconName = "play.circle.fill"
            tintColor = .gpPrimaryLight
        case .friendWroteReview:
            iconName = "square.and.pencil"
            tintColor = .gpPrimary
        case .friendWishlistedGame:
            iconName = "heart.fill"
            tintColor = .gpRed
        case .friendRatedHigh:
            iconName = "star.fill"
            tintColor = .gpPrimary
        case .generic:
            iconName = "bell.fill"
            tintColor = .gpTextSecondary
        }

        iconContainerView.backgroundColor = tintColor.withAlphaComponent(0.16)
        iconImageView.tintColor = tintColor
        iconImageView.image = UIImage(
            systemName: iconName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        )
    }
}
