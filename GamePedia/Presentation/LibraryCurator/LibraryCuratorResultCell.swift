import UIKit

final class LibraryCuratorResultCell: UITableViewCell {
    static let reuseId = "LibraryCuratorResultCell"

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 14
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10
        imageView.backgroundColor = .gpSurface
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textColor = .gpStar
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let reasonLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 3
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let favoriteButton: UIButton = {
        let button = UIButton(type: .system)
        button.tintColor = .gpPrimary
        button.backgroundColor = .gpSurface
        button.layer.cornerRadius = 16
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let chipFlowView: TagFlowView = {
        let view = TagFlowView()
        view.maximumRows = 2
        view.maximumChipWidth = 132
        return view
    }()

    var onFavoriteButtonTapped: (() -> Void)?
    var onTagTapped: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        coverImageView.cancelLoad()
        coverImageView.image = .gpGameCoverPlaceholder
        chipFlowView.configure(items: [])
        onFavoriteButtonTapped = nil
        onTagTapped = nil
    }

    func configure(with item: LibraryCuratorItemViewState, selectedGenreTagIDs: Set<String> = []) {
        coverImageView.loadImage(url: item.coverUrl, placeholder: .gpGameCoverPlaceholder)
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
        ratingLabel.text = item.ratingText == "—" ? L10n.Common.Label.noRating : "★ \(item.ratingText)"
        ratingLabel.textColor = item.ratingText == "—" ? .gpTextTertiary : .gpStar
        reasonLabel.text = item.reason
        statsLabel.text = [item.playtimeText, item.userRatingText, item.confidenceText]
            .compactMap { $0 }
            .joined(separator: " · ")
        statsLabel.isHidden = statsLabel.text?.isEmpty ?? true
        favoriteButton.setImage(UIImage(systemName: item.isFavorite ? "bookmark.fill" : "bookmark"), for: .normal)
        favoriteButton.isEnabled = !item.isFavoriteUpdating
        favoriteButton.alpha = item.isFavoriteUpdating ? 0.55 : 1.0
        chipFlowView.configure(items: item.displayTags.map {
            let id = LibraryCuratorViewModel.tagID(for: $0, section: "genre")
            return TagFlowItem(
                id: id,
                title: $0,
                isSelected: selectedGenreTagIDs.contains(id)
            )
        })
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, favoriteButton])
        titleRow.axis = .horizontal
        titleRow.spacing = 8
        titleRow.alignment = .top
        titleRow.translatesAutoresizingMaskIntoConstraints = false

        let metadataRow = UIStackView(arrangedSubviews: [subtitleLabel, ratingLabel])
        metadataRow.axis = .horizontal
        metadataRow.spacing = 8
        metadataRow.alignment = .center
        metadataRow.translatesAutoresizingMaskIntoConstraints = false

        let infoStackView = UIStackView(arrangedSubviews: [
            titleRow,
            metadataRow,
            reasonLabel,
            statsLabel,
            chipFlowView
        ])
        infoStackView.axis = .vertical
        infoStackView.spacing = 7
        infoStackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        cardView.addSubview(coverImageView)
        cardView.addSubview(infoStackView)
        favoriteButton.addTarget(self, action: #selector(didTapFavoriteButton), for: .touchUpInside)
        chipFlowView.onItemTapped = { [weak self] item in
            self?.onTagTapped?(item.id)
        }

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            coverImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            coverImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            coverImageView.widthAnchor.constraint(equalToConstant: 72),
            coverImageView.heightAnchor.constraint(equalToConstant: 96),
            coverImageView.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -14),

            infoStackView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            infoStackView.leadingAnchor.constraint(equalTo: coverImageView.trailingAnchor, constant: 14),
            infoStackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            infoStackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),

            favoriteButton.widthAnchor.constraint(equalToConstant: 32),
            favoriteButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    @objc
    private func didTapFavoriteButton() {
        onFavoriteButtonTapped?()
    }
}
