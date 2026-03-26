import UIKit

// MARK: - GameHorizontalCell
// Used in horizontal scroll sections on Home screen

final class GameHorizontalCell: UICollectionViewCell {

    static let reuseId = "GameHorizontalCell"
    static let width: CGFloat = 140
    static let height: CGFloat = 240

    // MARK: Subviews
    private let thumbnailView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = .gpSurfaceElevated
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let starRatingView: StarRatingView = {
        let view = StarRatingView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpStar
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let genreLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = .gpTextSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

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
        backgroundColor = .clear

        let ratingStack = UIStackView(arrangedSubviews: [starRatingView, ratingLabel])
        ratingStack.axis = .horizontal
        ratingStack.spacing = 4
        ratingStack.alignment = .center
        ratingStack.translatesAutoresizingMaskIntoConstraints = false

        [thumbnailView, titleLabel, ratingStack, genreLabel].forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            thumbnailView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailView.heightAnchor.constraint(equalToConstant: 180),

            titleLabel.topAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            ratingStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            ratingStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),

            genreLabel.topAnchor.constraint(equalTo: ratingStack.bottomAnchor, constant: 3),
            genreLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            genreLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    // MARK: Configure
    func configure(with game: Game, resolvedTitle: String) {
        thumbnailView.loadImage(url: game.coverImageURL)
        titleLabel.text = resolvedTitle
        genreLabel.text = game.genre
        starRatingView.configure(rating: game.rating)
        ratingLabel.text = game.formattedRating
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailView.cancelLoad()
        thumbnailView.image = nil
    }
}
