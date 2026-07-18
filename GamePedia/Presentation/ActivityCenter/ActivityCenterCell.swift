import UIKit

final class ActivityCenterCell: UITableViewCell {
    static let reuseID = "ActivityCenterCell"

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

    func configure(with item: ActivityCenterItem) {
        titleLabel.text = item.title
        messageLabel.text = item.message
        dateLabel.text = item.relativeOccurredAtText
        unreadDotView.isHidden = item.isRead
        configureIcon(for: item)
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

    private func configureIcon(for item: ActivityCenterItem) {
        let iconName: String
        let tintColor: UIColor

        switch item.kindCode {
        case "friend_request_received":
            iconName = "person.crop.circle.badge.plus"
            tintColor = .gpPrimary
        case "friend_request_accepted":
            iconName = "person.2.fill"
            tintColor = .gpTeal
        case "friend_review_reaction":
            iconName = "bubble.left.and.text.bubble.right.fill"
            tintColor = .gpCoral
        case "friend_review_created":
            iconName = "square.and.pencil"
            tintColor = .gpPrimary
        case "friend_review_updated":
            iconName = "pencil.line"
            tintColor = .gpPrimaryLight
        case "review_comment_reply":
            iconName = "arrowshape.turn.up.left.fill"
            tintColor = .gpPrimary
        case "review_comment_like":
            iconName = "hand.thumbsup.fill"
            tintColor = .gpTeal
        case "review_comment_dislike":
            iconName = "hand.thumbsdown.fill"
            tintColor = .gpCoral
        case "friend_liked_game_added":
            iconName = "heart.fill"
            tintColor = .gpRed
        case "friend_liked_game_removed":
            iconName = "heart.slash.fill"
            tintColor = .gpTextSecondary
        case "friend_rating_changed":
            iconName = "star.fill"
            tintColor = .gpStar
        case "friend_play_status_changed":
            iconName = "arrow.triangle.2.circlepath.circle.fill"
            tintColor = .gpPrimaryLight
        case "friend_started_playing":
            iconName = "play.circle.fill"
            tintColor = .gpPrimaryLight
        case "friend_recently_played":
            iconName = "clock.fill"
            tintColor = .gpTeal
        case "recommendation":
            iconName = "sparkles"
            tintColor = .gpStar
        default:
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
