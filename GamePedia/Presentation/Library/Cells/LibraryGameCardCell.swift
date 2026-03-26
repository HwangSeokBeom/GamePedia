import UIKit

struct LibraryGameCardItem: Hashable {
    let id: Int
    let title: String
    let playHours: Int
    let ratingValue: Double
    let symbolName: String
    let startColorHex: String
    let endColorHex: String
}

final class LibraryGameCardCell: UICollectionViewCell {

    static let reuseId = "LibraryGameCardCell"

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
            systemName: "heart",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        )
        configuration.baseForegroundColor = .gpRed
        configuration.contentInsets = .zero
        button.configuration = configuration
        button.isUserInteractionEnabled = false
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
    }

    func configure(with item: LibraryGameCardItem) {
        artworkView.configure(
            title: item.title,
            symbolName: item.symbolName,
            startColorHex: item.startColorHex,
            endColorHex: item.endColorHex
        )
        titleLabel.text = item.title
        ratingLabel.text = String(format: "%.1f", item.ratingValue)
        playtimeLabel.text = "\(item.playHours)시간"
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .gpSurface
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true

        contentView.addSubview(artworkView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(starImageView)
        contentView.addSubview(ratingLabel)
        contentView.addSubview(favoriteButton)
        contentView.addSubview(playtimeLabel)

        NSLayoutConstraint.activate([
            artworkView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            artworkView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            artworkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            artworkView.heightAnchor.constraint(equalTo: artworkView.widthAnchor, multiplier: 0.88),

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
}

private final class LibraryArtworkView: UIView {

    private let gradientLayer = CAGradientLayer()

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

    func configure(title: String, symbolName: String, startColorHex: String, endColorHex: String) {
        gradientLayer.colors = [
            UIColor(hex: startColorHex).cgColor,
            UIColor(hex: endColorHex).cgColor
        ]
        symbolImageView.image = UIImage(
            systemName: symbolName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 42, weight: .medium)
        )
        monogramLabel.text = String(title.prefix(1))
    }

    func prepareForReuse() {
        symbolImageView.image = nil
        monogramLabel.text = nil
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 12
        layer.masksToBounds = true

        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)

        addSubview(symbolImageView)
        addSubview(monogramLabel)

        NSLayoutConstraint.activate([
            symbolImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            symbolImageView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            symbolImageView.widthAnchor.constraint(equalToConstant: 50),
            symbolImageView.heightAnchor.constraint(equalToConstant: 50),

            monogramLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            monogramLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }
}
