import UIKit

final class FriendActivityCell: UITableViewCell {
    static let reuseID = "FriendActivityCell"

    var onActorTapped: (() -> Void)?

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 20
        imageView.backgroundColor = .gpSurface
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let actorButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let actorNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 1
        return label
    }()

    private let headlineLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        return label
    }()

    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .gpTextTertiary
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let presenceBadgeView = FriendPresenceBadgeView()

    private let gameCoverView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = .gpSurface
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let gameTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        return label
    }()

    private let subheadlineLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpPrimaryLight
        label.numberOfLines = 1
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.cancelLoad()
        gameCoverView.cancelLoad()
        avatarView.image = nil
        gameCoverView.image = nil
        onActorTapped = nil
    }

    func configure(with viewState: FriendActivityFeedItemViewState) {
        avatarView.loadImage(url: viewState.actorAvatarURL, placeholder: UIImage(systemName: "person.fill"))
        gameCoverView.loadImage(url: viewState.gameCoverURL, placeholder: .gpGameCoverPlaceholder)
        actorNameLabel.text = viewState.actorNameText
        headlineLabel.text = viewState.headlineText
        subheadlineLabel.text = viewState.subheadlineText
        subheadlineLabel.isHidden = viewState.subheadlineText == nil
        gameTitleLabel.text = viewState.gameTitleText
        timestampLabel.text = viewState.timestampText
        presenceBadgeView.configure(with: viewState.presenceDisplayModel)
    }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        let actorTextStack = UIStackView(arrangedSubviews: [actorNameLabel, headlineLabel, presenceBadgeView])
        actorTextStack.axis = .vertical
        actorTextStack.alignment = .leading
        actorTextStack.spacing = 4
        actorTextStack.translatesAutoresizingMaskIntoConstraints = false

        let gameTextStack = UIStackView(arrangedSubviews: [subheadlineLabel, gameTitleLabel])
        gameTextStack.axis = .vertical
        gameTextStack.alignment = .leading
        gameTextStack.spacing = 4
        gameTextStack.translatesAutoresizingMaskIntoConstraints = false

        let gameRow = UIStackView(arrangedSubviews: [gameCoverView, gameTextStack])
        gameRow.axis = .horizontal
        gameRow.alignment = .center
        gameRow.spacing = 12
        gameRow.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        [avatarView, actorTextStack, timestampLabel, gameRow, actorButton].forEach { cardView.addSubview($0) }

        actorButton.addTarget(self, action: #selector(didTapActorButton), for: .touchUpInside)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            avatarView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            avatarView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            avatarView.widthAnchor.constraint(equalToConstant: 40),
            avatarView.heightAnchor.constraint(equalToConstant: 40),

            timestampLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            timestampLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            timestampLabel.leadingAnchor.constraint(greaterThanOrEqualTo: avatarView.trailingAnchor, constant: 12),

            actorTextStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            actorTextStack.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            actorTextStack.trailingAnchor.constraint(equalTo: timestampLabel.leadingAnchor, constant: -12),

            actorButton.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            actorButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            actorButton.trailingAnchor.constraint(equalTo: timestampLabel.leadingAnchor, constant: -8),
            actorButton.bottomAnchor.constraint(equalTo: actorTextStack.bottomAnchor, constant: 4),

            gameRow.topAnchor.constraint(equalTo: actorTextStack.bottomAnchor, constant: 14),
            gameRow.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            gameRow.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            gameRow.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),

            gameCoverView.widthAnchor.constraint(equalToConstant: 56),
            gameCoverView.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    @objc
    private func didTapActorButton() {
        onActorTapped?()
    }
}
