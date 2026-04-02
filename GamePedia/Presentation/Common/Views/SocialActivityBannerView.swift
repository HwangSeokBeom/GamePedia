import UIKit

final class SocialActivityBannerView: UIControl {
    private let blurView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 18
        imageView.backgroundColor = .gpSurface
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 1
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.82)
        label.numberOfLines = 2
        return label
    }()

    private let gameCoverView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = .gpSurface
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with payload: SocialActivityBannerPayload) {
        titleLabel.text = payload.title
        messageLabel.text = payload.message
        avatarView.loadImage(url: payload.actorAvatarURL, placeholder: UIImage(systemName: "person.fill"))
        gameCoverView.loadImage(url: payload.gameCoverURL, placeholder: .gpGameCoverPlaceholder)
        gameCoverView.isHidden = payload.gameCoverURL == nil
    }

    private func setup() {
        backgroundColor = .clear
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.22
        layer.shadowRadius = 18
        layer.shadowOffset = CGSize(width: 0, height: 12)
        translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(blurView)
        [avatarView, textStack, gameCoverView].forEach { blurView.contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            avatarView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 14),
            avatarView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 36),
            avatarView.heightAnchor.constraint(equalToConstant: 36),

            gameCoverView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -14),
            gameCoverView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            gameCoverView.widthAnchor.constraint(equalToConstant: 44),
            gameCoverView.heightAnchor.constraint(equalToConstant: 44),

            textStack.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 12),
            textStack.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: gameCoverView.leadingAnchor, constant: -12),
            textStack.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -12)
        ])
    }
}
