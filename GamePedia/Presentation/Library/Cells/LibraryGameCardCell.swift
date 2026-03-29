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
        onActionButtonTapped = nil
    }

    func configure(with viewState: LibraryRecentGameCardViewState) {
        artworkView.configure(title: viewState.title, imageURL: viewState.coverImageURL)
        badgeLabel.text = viewState.badgeText
        titleLabel.text = viewState.title
        metadataLabel.text = viewState.metadataText
        if let ratingText = viewState.ratingText {
            ratingLabel.text = "★ \(ratingText)"
            ratingLabel.isHidden = false
        } else {
            ratingLabel.isHidden = true
        }

        var configuration = actionButton.configuration
        configuration?.title = viewState.actionTitle
        actionButton.configuration = configuration
        actionButton.isHidden = viewState.actionTitle == nil
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .gpCardBackground
        contentView.layer.cornerRadius = 18
        contentView.layer.masksToBounds = true

        [artworkView, badgeLabel, titleLabel, metadataLabel, ratingLabel, actionButton].forEach {
            contentView.addSubview($0)
        }

        actionButton.addTarget(self, action: #selector(didTapActionButton), for: .touchUpInside)

        NSLayoutConstraint.activate([
            artworkView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            artworkView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            artworkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            artworkView.heightAnchor.constraint(equalTo: artworkView.widthAnchor),

            badgeLabel.topAnchor.constraint(equalTo: artworkView.topAnchor, constant: 10),
            badgeLabel.leadingAnchor.constraint(equalTo: artworkView.leadingAnchor, constant: 10),

            titleLabel.topAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            metadataLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            metadataLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            metadataLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            ratingLabel.topAnchor.constraint(equalTo: metadataLabel.bottomAnchor, constant: 8),
            ratingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            ratingLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12),

            actionButton.topAnchor.constraint(equalTo: ratingLabel.bottomAnchor, constant: 10),
            actionButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            actionButton.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12),
            actionButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            actionButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    @objc
    private func didTapActionButton() {
        onActionButtonTapped?()
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

    func configure(title: String, imageURL: URL?) {
        gradientLayer.colors = [
            UIColor(hex: "#164B8C").cgColor,
            UIColor(hex: "#0B0B0E").cgColor
        ]
        monogramLabel.text = String(title.prefix(1))
        imageView.loadImage(url: imageURL)
        imageView.isHidden = imageURL == nil
        symbolImageView.isHidden = imageURL != nil
        monogramLabel.isHidden = imageURL != nil
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
