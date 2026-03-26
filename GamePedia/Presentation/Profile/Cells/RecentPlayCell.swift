import UIKit

// MARK: - RecentPlayCell

final class RecentPlayCell: UITableViewCell {

    static let reuseId = "RecentPlayCell"
    // Card height 72 (48 thumb + 12×2 padding) + 10 inter-card gap
    static let height: CGFloat = 82

    // MARK: Subviews
    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .gpSurfaceElevated
        v.layer.cornerRadius = 14
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

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
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .gpTextPrimary
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = .gpTextSecondary
        return label
    }()

    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textColor = .gpStar
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

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        let infoStack = UIStackView(arrangedSubviews: [titleLabel, timeLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 2

        let mainStack = UIStackView(arrangedSubviews: [thumbnailView, infoStack, UIView(), ratingLabel])
        mainStack.axis = .horizontal
        mainStack.spacing = 12
        mainStack.alignment = .center
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        cardView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            thumbnailView.widthAnchor.constraint(equalToConstant: 48),
            thumbnailView.heightAnchor.constraint(equalToConstant: 48),

            mainStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            mainStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            mainStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12)
        ])
    }

    // MARK: Configure
    func configure(with game: RecentGame, resolvedTitle: String) {
        thumbnailView.loadImage(url: game.coverImageURL)
        titleLabel.text = resolvedTitle
        timeLabel.text = game.formattedLastPlayed
        if let rating = game.formattedRating {
            ratingLabel.text = "★ \(rating)"
            ratingLabel.isHidden = false
        } else {
            ratingLabel.isHidden = true
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailView.cancelLoad()
        thumbnailView.image = nil
    }
}
