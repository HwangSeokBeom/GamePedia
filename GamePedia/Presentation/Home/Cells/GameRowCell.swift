import UIKit

// MARK: - GameRowCell
// Full-width horizontal row card used in the Recommended section

final class GameRowCell: UICollectionViewCell {

    static let reuseId = "GameRowCell"
    static let height: CGFloat = 88
    private enum Metrics {
        static let buttonWidth: CGFloat = 84
        static let buttonHeight: CGFloat = 32
        static let buttonIconPointSize: CGFloat = 16
        static let buttonTitleFontSize: CGFloat = 12
        static let buttonImagePadding: CGFloat = 4
    }

    // MARK: Subviews
    private let thumbnailView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 10
        iv.backgroundColor = .gpSurface
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let wishlistButton: UIButton = {
        let button = UIButton(configuration: .filled())
        button.layer.cornerRadius = Metrics.buttonHeight / 2
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isUserInteractionEnabled = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }()

    var onFavoriteButtonTapped: (() -> Void)?

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: Setup
    private func setup() {
        contentView.backgroundColor = .gpCardBackground
        contentView.layer.cornerRadius = 14
        contentView.clipsToBounds = true

        let infoStack = UIStackView(arrangedSubviews: [titleLabel, descLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 3
        infoStack.translatesAutoresizingMaskIntoConstraints = false

        [thumbnailView, infoStack, wishlistButton].forEach { contentView.addSubview($0) }

        wishlistButton.addTarget(self, action: #selector(didTapWishlistButton), for: .touchUpInside)

        NSLayoutConstraint.activate([
            thumbnailView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            thumbnailView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 56),
            thumbnailView.heightAnchor.constraint(equalToConstant: 56),

            wishlistButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            wishlistButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            wishlistButton.widthAnchor.constraint(equalToConstant: Metrics.buttonWidth),
            wishlistButton.heightAnchor.constraint(equalToConstant: Metrics.buttonHeight),

            infoStack.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 12),
            infoStack.trailingAnchor.constraint(equalTo: wishlistButton.leadingAnchor, constant: -12),
            infoStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    // MARK: Configure
    func configure(with game: Game, resolvedTitle: String, isWishlisted: Bool = false) {
        thumbnailView.loadImage(url: game.coverImageURL)
        titleLabel.text = resolvedTitle
        descLabel.text = "\(game.genre) · \(releaseText(for: game)) · ★ \(game.formattedRating)"
        wishlistButton.configuration = makeWishlistConfiguration(isWishlisted: isWishlisted)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailView.cancelLoad()
        thumbnailView.image = nil
        wishlistButton.configuration = makeWishlistConfiguration(isWishlisted: false)
        onFavoriteButtonTapped = nil
    }

    @objc
    private func didTapWishlistButton() {
        onFavoriteButtonTapped?()
    }

    private func releaseText(for game: Game) -> String {
        if game.releaseYear > 0 { return "\(game.releaseYear)" }
        return "출시 예정"
    }

    private func makeWishlistConfiguration(isWishlisted: Bool) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        let symbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: Metrics.buttonIconPointSize,
            weight: .semibold
        )
        configuration.title = isWishlisted ? "찜됨" : "찜하기"
        configuration.image = UIImage(
            systemName: isWishlisted ? "bookmark.fill" : "bookmark",
            withConfiguration: symbolConfiguration
        )
        configuration.imagePadding = Metrics.buttonImagePadding
        configuration.baseForegroundColor = .gpOnPrimary
        configuration.baseBackgroundColor = isWishlisted ? .gpPrimaryLight : .gpPrimary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        configuration.cornerStyle = .capsule
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: Metrics.buttonTitleFontSize, weight: .semibold)
            return outgoing
        }
        return configuration
    }
}
