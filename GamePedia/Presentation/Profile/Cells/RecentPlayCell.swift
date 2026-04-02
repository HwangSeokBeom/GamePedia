import UIKit

// MARK: - RecentPlayCell

final class RecentPlayCell: UITableViewCell {

    static let reuseId = "RecentPlayCell"
    static let height: CGFloat = 88

    // MARK: Subviews
    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .gpCardBackground
        v.layer.cornerRadius = 18
        v.layer.cornerCurve = .continuous
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.gpSeparator.withAlphaComponent(0.24).cgColor
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
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
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        return label
    }()

    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
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
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            thumbnailView.widthAnchor.constraint(equalToConstant: 52),
            thumbnailView.heightAnchor.constraint(equalToConstant: 52),

            mainStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            mainStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            mainStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            mainStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14)
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
