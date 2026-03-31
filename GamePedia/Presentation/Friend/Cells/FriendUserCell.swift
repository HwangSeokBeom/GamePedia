import UIKit

final class FriendUserCell: UITableViewCell {
    static let reuseID = "FriendUserCell"

    struct ActionConfiguration {
        enum Style {
            case primary
            case secondary
        }

        let title: String
        let style: Style
        let isEnabled: Bool
    }

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 0.5
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.22
        view.layer.shadowRadius = 16
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSurfaceElevated
        view.layer.cornerRadius = 26
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 22
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        return label
    }()

    private let primaryActionButton = FriendUserCell.makeActionButton()
    private let secondaryActionButton = FriendUserCell.makeActionButton()

    private lazy var actionStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [secondaryActionButton, primaryActionButton])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var textStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel])
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

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
        user: FriendUserSummary,
        subtitle: String?,
        primaryAction: ActionConfiguration?,
        secondaryAction: ActionConfiguration? = nil
    ) {
        avatarView.loadImage(url: user.profileImageURL, placeholder: Self.defaultAvatarPlaceholderImage())
        avatarView.tintColor = .gpTextSecondary.withAlphaComponent(0.8)
        nameLabel.text = user.nickname
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle == nil
        applyActionConfiguration(primaryAction, to: primaryActionButton)
        applyActionConfiguration(secondaryAction, to: secondaryActionButton)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.cancelLoad()
        avatarView.image = nil
        cardView.backgroundColor = .gpCardBackground
        cardView.transform = .identity
        onPrimaryActionTapped = nil
        onSecondaryActionTapped = nil
        primaryActionButton.isHidden = true
        secondaryActionButton.isHidden = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        cardView.layer.shadowPath = UIBezierPath(
            roundedRect: cardView.bounds,
            cornerRadius: cardView.layer.cornerRadius
        ).cgPath
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        let changes = {
            self.cardView.backgroundColor = highlighted
                ? UIColor.gpSurfaceElevated.withAlphaComponent(0.96)
                : .gpCardBackground
            self.cardView.transform = highlighted ? CGAffineTransform(scaleX: 0.99, y: 0.99) : .identity
        }

        if animated {
            UIView.animate(
                withDuration: 0.18,
                delay: 0,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: changes
            )
        } else {
            changes()
        }
    }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(cardView)
        cardView.addSubview(avatarContainerView)
        avatarContainerView.addSubview(avatarView)
        cardView.addSubview(textStackView)
        cardView.addSubview(actionStackView)

        primaryActionButton.addTarget(self, action: #selector(didTapPrimaryActionButton), for: .touchUpInside)
        secondaryActionButton.addTarget(self, action: #selector(didTapSecondaryActionButton), for: .touchUpInside)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            avatarContainerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            avatarContainerView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            avatarContainerView.widthAnchor.constraint(equalToConstant: 52),
            avatarContainerView.heightAnchor.constraint(equalToConstant: 52),

            avatarView.centerXAnchor.constraint(equalTo: avatarContainerView.centerXAnchor),
            avatarView.centerYAnchor.constraint(equalTo: avatarContainerView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 44),
            avatarView.heightAnchor.constraint(equalToConstant: 44),

            actionStackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            actionStackView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),

            textStackView.leadingAnchor.constraint(equalTo: avatarContainerView.trailingAnchor, constant: 12),
            textStackView.trailingAnchor.constraint(lessThanOrEqualTo: actionStackView.leadingAnchor, constant: -12),
            textStackView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            textStackView.topAnchor.constraint(greaterThanOrEqualTo: cardView.topAnchor, constant: 14),
            textStackView.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -14)
        ])
    }

    private func applyActionConfiguration(_ configuration: ActionConfiguration?, to button: UIButton) {
        guard let configuration else {
            button.isHidden = true
            button.isEnabled = false
            return
        }

        button.isHidden = false
        button.isEnabled = configuration.isEnabled
        button.alpha = configuration.isEnabled ? 1 : 0.72

        var buttonConfiguration: UIButton.Configuration
        switch configuration.style {
        case .primary:
            buttonConfiguration = .filled()
            buttonConfiguration.baseBackgroundColor = configuration.isEnabled
                ? .gpPrimary
                : UIColor.gpSurfaceElevated.withAlphaComponent(0.95)
            buttonConfiguration.baseForegroundColor = configuration.isEnabled ? .gpOnPrimary : .gpTextSecondary
        case .secondary:
            buttonConfiguration = .plain()
            buttonConfiguration.baseForegroundColor = configuration.isEnabled ? .gpTextPrimary : .gpTextSecondary
            buttonConfiguration.background.backgroundColor = configuration.isEnabled
                ? UIColor.gpSurfaceElevated.withAlphaComponent(0.16)
                : UIColor.gpSurfaceElevated.withAlphaComponent(0.08)
            buttonConfiguration.background.strokeColor = UIColor.white.withAlphaComponent(configuration.isEnabled ? 0.16 : 0.08)
            buttonConfiguration.background.strokeWidth = 1
        }

        buttonConfiguration.title = configuration.title
        buttonConfiguration.cornerStyle = .capsule
        buttonConfiguration.background.cornerRadius = 16
        buttonConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        button.configuration = buttonConfiguration
    }

    private static func makeActionButton() -> UIButton {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    private static func defaultAvatarPlaceholderImage() -> UIImage? {
        UIImage(
            systemName: "person.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        )?.withTintColor(.gpTextSecondary.withAlphaComponent(0.8), renderingMode: .alwaysOriginal)
    }

    @objc
    private func didTapPrimaryActionButton() {
        onPrimaryActionTapped?()
    }

    @objc
    private func didTapSecondaryActionButton() {
        onSecondaryActionTapped?()
    }
}
