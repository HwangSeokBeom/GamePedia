import UIKit

// MARK: - SearchResultCell

final class SearchResultCell: UITableViewCell {

    static let reuseId = "SearchResultCell"
    static let height: CGFloat = 112  // 100pt card + 12pt gap between cards

    // MARK: Subviews
    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSurfaceElevated
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let thumbnailView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = .gpSurface
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 1
        return label
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextSecondary
        return label
    }()

    private let starView: StarRatingView = {
        let v = StarRatingView()
        return v
    }()

    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textColor = .gpStar
        return label
    }()

    private let reviewCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextTertiary
        return label
    }()

    private let summaryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    // MARK: Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: Setup
    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        // Rating row: single star label + bold score + review count (no full 5-star view)
        let ratingStack = UIStackView(arrangedSubviews: [ratingLabel, reviewCountLabel])
        ratingStack.axis = .horizontal
        ratingStack.spacing = 4
        ratingStack.alignment = .center

        let infoStack = UIStackView(arrangedSubviews: [titleLabel, summaryLabel, metaLabel, ratingStack])
        infoStack.axis = .vertical
        infoStack.spacing = 4
        infoStack.alignment = .leading

        let mainStack = UIStackView(arrangedSubviews: [thumbnailView, infoStack])
        mainStack.axis = .horizontal
        mainStack.spacing = 14
        mainStack.alignment = .center
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        cardView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            // Card sits in the top portion; bottom 12pt is transparent (inter-card gap)
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            thumbnailView.widthAnchor.constraint(equalToConstant: 72),
            thumbnailView.heightAnchor.constraint(equalToConstant: 72),

            mainStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            mainStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),
            mainStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            mainStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14)
        ])
    }

    // MARK: Configure

    /// - Parameters:
    ///   - game: game entity carrying both raw and translated text from the API response
    ///   - resolvedSummary: resolved summary if available, or nil to fall back to the model value
    func configure(with game: Game, resolvedTitle: String, resolvedSummary: String? = nil) {
        thumbnailView.loadImage(url: game.coverImageURL)
        titleLabel.text = resolvedTitle
        let summary = resolvedSummary ?? game.resolvedSummary
        summaryLabel.text = summary
        summaryLabel.isHidden = summary == nil || summary?.isEmpty == true
        metaLabel.text = "\(game.genre) · \(game.developer) · \(game.releaseYear)"
        starView.configure(rating: game.rating)
        ratingLabel.text = "★ \(game.formattedRating)"
        reviewCountLabel.text = "(\(game.formattedReviewCount))"
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailView.cancelLoad()
        thumbnailView.image = nil
    }
}
