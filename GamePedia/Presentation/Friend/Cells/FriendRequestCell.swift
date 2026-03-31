import UIKit

final class FriendRequestCell: UITableViewCell {
    static let reuseID = "FriendRequestCell"

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 16
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

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        return label
    }()

    private let primaryButton = FriendRequestCell.makeButton(backgroundColor: .gpPrimary, foregroundColor: .gpOnPrimary)
    private let secondaryButton = FriendRequestCell.makeButton(backgroundColor: .gpSurfaceElevated, foregroundColor: .gpTextPrimary)

    var onPrimaryActionTapped: (() -> Void)?
    var onSecondaryActionTapped: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        request: FriendRequest,
        primaryTitle: String,
        secondaryTitle: String? = nil
    ) {
        avatarView.loadImage(url: request.user.profileImageURL, placeholder: UIImage(systemName: "person.fill"))
        nameLabel.text = request.user.nickname
        let createdAtText = request.createdAt.map {
            RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date())
        }
        subtitleLabel.text = createdAtText ?? request.user.bio ?? "친구 요청"
        primaryButton.setTitle(primaryTitle, for: .normal)
        primaryButton.isHidden = false
        secondaryButton.setTitle(secondaryTitle, for: .normal)
        secondaryButton.isHidden = secondaryTitle == nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.cancelLoad()
        avatarView.image = nil
        onPrimaryActionTapped = nil
        onSecondaryActionTapped = nil
    }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        let buttonStack = UIStackView(arrangedSubviews: [secondaryButton, primaryButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        cardView.addSubview(avatarView)
        cardView.addSubview(textStack)
        cardView.addSubview(buttonStack)

        primaryButton.addTarget(self, action: #selector(didTapPrimary), for: .touchUpInside)
        secondaryButton.addTarget(self, action: #selector(didTapSecondary), for: .touchUpInside)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            avatarView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            avatarView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            avatarView.widthAnchor.constraint(equalToConstant: 40),
            avatarView.heightAnchor.constraint(equalToConstant: 40),

            textStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            textStack.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            buttonStack.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 12),
            buttonStack.leadingAnchor.constraint(equalTo: textStack.leadingAnchor),
            buttonStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    private static func makeButton(backgroundColor: UIColor, foregroundColor: UIColor) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = backgroundColor
        configuration.baseForegroundColor = foregroundColor
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        return button
    }

    @objc
    private func didTapPrimary() {
        onPrimaryActionTapped?()
    }

    @objc
    private func didTapSecondary() {
        onSecondaryActionTapped?()
    }
}
