import UIKit

struct LibraryGameCardItem: Hashable {
    let id: Int
    let title: String
    let metadataText: String
    let ratingValue: Double?
    let coverImageURL: URL?
    let symbolName: String
    let startColorHex: String
    let endColorHex: String
    let isFavorite: Bool
    let showsFavoriteButton: Bool
}

final class LibraryGameCardCell: UICollectionViewCell {

    static let reuseId = "LibraryGameCardCell"
    var onFavoriteButtonTapped: (() -> Void)?

    private let artworkView = LibraryArtworkView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let starImageView: UIImageView = {
        let imageView = UIImageView(
            image: UIImage(
                systemName: "star.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            )
        )
        imageView.tintColor = .gpStar
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpStar
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let playtimeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .gpTextTertiary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let favoriteButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: "heart.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        )
        configuration.baseForegroundColor = .gpRed
        configuration.contentInsets = .zero
        button.configuration = configuration
        button.isUserInteractionEnabled = true
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
        onFavoriteButtonTapped = nil
    }

    func configure(with item: LibraryGameCardItem) {
        artworkView.configure(
            title: item.title,
            symbolName: item.symbolName,
            startColorHex: item.startColorHex,
            endColorHex: item.endColorHex,
            imageURL: item.coverImageURL
        )
        titleLabel.text = item.title
        if let ratingValue = item.ratingValue {
            ratingLabel.text = String(format: "%.1f", ratingValue)
            ratingLabel.isHidden = false
            starImageView.isHidden = false
        } else {
            ratingLabel.isHidden = true
            starImageView.isHidden = true
        }
        playtimeLabel.text = item.metadataText

        var configuration = favoriteButton.configuration
        configuration?.image = UIImage(
            systemName: item.isFavorite ? "heart.fill" : "heart",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        )
        favoriteButton.configuration = configuration
        favoriteButton.isHidden = !item.showsFavoriteButton
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .gpCardBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true

        contentView.addSubview(artworkView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(starImageView)
        contentView.addSubview(ratingLabel)
        contentView.addSubview(favoriteButton)
        contentView.addSubview(playtimeLabel)
        favoriteButton.addTarget(self, action: #selector(didTapFavoriteButton), for: .touchUpInside)

        NSLayoutConstraint.activate([
            artworkView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            artworkView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            artworkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            artworkView.heightAnchor.constraint(equalTo: artworkView.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),

            starImageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            starImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            starImageView.widthAnchor.constraint(equalToConstant: 10),
            starImageView.heightAnchor.constraint(equalToConstant: 10),

            ratingLabel.centerYAnchor.constraint(equalTo: starImageView.centerYAnchor),
            ratingLabel.leadingAnchor.constraint(equalTo: starImageView.trailingAnchor, constant: 4),

            favoriteButton.centerYAnchor.constraint(equalTo: starImageView.centerYAnchor),
            favoriteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            favoriteButton.widthAnchor.constraint(equalToConstant: 20),
            favoriteButton.heightAnchor.constraint(equalToConstant: 20),

            playtimeLabel.topAnchor.constraint(equalTo: starImageView.bottomAnchor, constant: 4),
            playtimeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            playtimeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            playtimeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    @objc
    private func didTapFavoriteButton() {
        onFavoriteButtonTapped?()
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
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = UIColor.white.withAlphaComponent(0.18)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let symbolImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = UIColor.white.withAlphaComponent(0.20)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
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

    func configure(title: String, symbolName: String, startColorHex: String, endColorHex: String, imageURL: URL?) {
        gradientLayer.colors = [
            UIColor(hex: startColorHex).cgColor,
            UIColor(hex: endColorHex).cgColor
        ]
        symbolImageView.image = UIImage(
            systemName: symbolName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 42, weight: .medium)
        )
        monogramLabel.text = String(title.prefix(1))
        imageView.loadImage(url: imageURL)
        imageView.isHidden = imageURL == nil
        symbolImageView.isHidden = imageURL != nil
        monogramLabel.isHidden = imageURL != nil
    }

    func prepareForReuse() {
        imageView.cancelLoad()
        imageView.image = nil
        symbolImageView.image = nil
        monogramLabel.text = nil
        imageView.isHidden = true
        symbolImageView.isHidden = false
        monogramLabel.isHidden = false
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 12
        layer.masksToBounds = true

        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)

        addSubview(imageView)
        addSubview(symbolImageView)
        addSubview(monogramLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            symbolImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            symbolImageView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            symbolImageView.widthAnchor.constraint(equalToConstant: 50),
            symbolImageView.heightAnchor.constraint(equalToConstant: 50),

            monogramLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            monogramLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }
}
