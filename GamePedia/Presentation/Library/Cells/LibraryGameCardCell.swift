import UIKit

final class LibraryGameCardCell: UICollectionViewCell {

    static let reuseId = "LibraryGameCardCell"
    var onActionButtonTapped: (() -> Void)?

    private let artworkView = LibraryArtworkView()

    private let badgeLabel: PaddingLabel = {
        let label = PaddingLabel(insets: UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .gpOnPrimary
        label.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.92)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let metadataLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .gpStar
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let favoriteIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(
            systemName: "heart",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        )
        imageView.tintColor = .systemRed
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let favoriteContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 11
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let bottomInfoRow: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let actionButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .gpOnPrimary
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var actionButtonHeightConstraint: NSLayoutConstraint?
    private var actionButtonTopConstraint: NSLayoutConstraint?
    private var actionButtonBottomConstraint: NSLayoutConstraint?
    private var ratingBottomConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        artworkView.prepareForReuse()
        badgeLabel.text = nil
        titleLabel.text = nil
        metadataLabel.text = nil
        ratingLabel.text = nil
        actionButton.isHidden = true
        actionButton.isEnabled = true
        actionButton.alpha = 1
        badgeLabel.isHidden = false
        favoriteIconView.isHidden = false
        ratingLabel.textColor = .gpStar
        applyActionVisibility(false)
        onActionButtonTapped = nil
    }

    func configure(with viewState: LibraryRecentGameCardViewState) {
        artworkView.configure(
            title: viewState.title,
            identifier: viewState.identifier,
            imageURL: viewState.coverImageURL,
            fallbackImageURLs: viewState.fallbackCoverImageURLs
        )
        badgeLabel.text = viewState.badgeText
        badgeLabel.isHidden = viewState.badgeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        titleLabel.text = viewState.title
        metadataLabel.text = viewState.metadataText
        if let ratingText = viewState.ratingText {
            ratingLabel.text = "★ \(ratingText)"
            ratingLabel.isHidden = false
            ratingLabel.textColor = .gpStar
        } else {
            ratingLabel.text = "평가 없음"
            ratingLabel.isHidden = false
            ratingLabel.textColor = .gpTextTertiary
        }

        var configuration = actionButton.configuration
        configuration?.title = viewState.actionTitle
        actionButton.configuration = configuration
        actionButton.isHidden = viewState.actionTitle == nil
        actionButton.isEnabled = viewState.isActionEnabled
        actionButton.alpha = viewState.isActionEnabled ? 1 : 0.6
        applyActionVisibility(viewState.actionTitle != nil)
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .gpCardBackground
        contentView.layer.cornerRadius = 20
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.gpSeparator.withAlphaComponent(0.28).cgColor
        contentView.layer.masksToBounds = true

        favoriteContainerView.addSubview(favoriteIconView)
        [ratingLabel, UIView(), favoriteContainerView].forEach { bottomInfoRow.addArrangedSubview($0) }

        [artworkView, badgeLabel, titleLabel, metadataLabel, bottomInfoRow, actionButton].forEach {
            contentView.addSubview($0)
        }

        actionButton.addTarget(self, action: #selector(didTapActionButton), for: .touchUpInside)

        NSLayoutConstraint.activate([
            artworkView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            artworkView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            artworkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            artworkView.heightAnchor.constraint(equalTo: artworkView.widthAnchor, multiplier: 1.1),

            badgeLabel.topAnchor.constraint(equalTo: artworkView.topAnchor, constant: 10),
            badgeLabel.leadingAnchor.constraint(equalTo: artworkView.leadingAnchor, constant: 10),

            titleLabel.topAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            metadataLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            metadataLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            metadataLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            bottomInfoRow.topAnchor.constraint(equalTo: metadataLabel.bottomAnchor, constant: 6),
            bottomInfoRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            bottomInfoRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            favoriteContainerView.widthAnchor.constraint(equalToConstant: 22),
            favoriteContainerView.heightAnchor.constraint(equalToConstant: 22),
            favoriteIconView.centerXAnchor.constraint(equalTo: favoriteContainerView.centerXAnchor),
            favoriteIconView.centerYAnchor.constraint(equalTo: favoriteContainerView.centerYAnchor)
        ])

        let actionButtonTopConstraint = actionButton.topAnchor.constraint(equalTo: bottomInfoRow.bottomAnchor, constant: 8)
        let actionButtonBottomConstraint = actionButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        let actionButtonHeightConstraint = actionButton.heightAnchor.constraint(equalToConstant: 32)
        let ratingBottomConstraint = bottomInfoRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)

        self.actionButtonTopConstraint = actionButtonTopConstraint
        self.actionButtonBottomConstraint = actionButtonBottomConstraint
        self.actionButtonHeightConstraint = actionButtonHeightConstraint
        self.ratingBottomConstraint = ratingBottomConstraint

        NSLayoutConstraint.activate([
            actionButtonTopConstraint,
            actionButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            actionButton.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12),
            actionButtonBottomConstraint,
            actionButtonHeightConstraint
        ])

        applyActionVisibility(false)
    }

    @objc
    private func didTapActionButton() {
        onActionButtonTapped?()
    }

    private func applyActionVisibility(_ isVisible: Bool) {
        actionButtonHeightConstraint?.constant = isVisible ? 32 : 0
        actionButtonTopConstraint?.isActive = isVisible
        actionButtonBottomConstraint?.isActive = isVisible
        ratingBottomConstraint?.isActive = !isVisible
        favoriteIconView.isHidden = isVisible
    }
}

private final class LibraryArtworkView: UIView {

    private let gradientLayer = CAGradientLayer()

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let monogramLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 30, weight: .bold)
        label.textColor = UIColor.white.withAlphaComponent(0.2)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let symbolImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = UIColor.white.withAlphaComponent(0.18)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(
            systemName: "gamecontroller.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        )
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    func configure(
        title: String,
        identifier: LibraryGameIdentifier,
        imageURL: URL?,
        fallbackImageURLs: [URL]
    ) {
        gradientLayer.colors = [
            UIColor(hex: "#164B8C").cgColor,
            UIColor(hex: "#0B0B0E").cgColor
        ]
        monogramLabel.text = String(title.prefix(1))
        let hasRemoteImage = imageURL != nil || fallbackImageURLs.isEmpty == false
        if hasRemoteImage {
            imageView.loadImage(
                url: imageURL,
                fallbackURLs: fallbackImageURLs,
                placeholder: .gpGameCoverPlaceholder,
                logContext: "Library.recentlyPlayed.\(identifier.uniqueKey)"
            )
        } else {
            imageView.image = nil
        }
        imageView.isHidden = hasRemoteImage == false
        symbolImageView.isHidden = hasRemoteImage
        monogramLabel.isHidden = hasRemoteImage
    }

    func prepareForReuse() {
        imageView.cancelLoad()
        imageView.image = nil
        monogramLabel.text = nil
        imageView.isHidden = true
        symbolImageView.isHidden = false
        monogramLabel.isHidden = false
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 14
        layer.masksToBounds = true

        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)

        addSubview(imageView)
        addSubview(monogramLabel)
        addSubview(symbolImageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            monogramLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            monogramLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            symbolImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            symbolImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolImageView.widthAnchor.constraint(equalToConstant: 44),
            symbolImageView.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
}

private final class PaddingLabel: UILabel {
    private let insets: UIEdgeInsets

    init(insets: UIEdgeInsets) {
        self.insets = insets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}
