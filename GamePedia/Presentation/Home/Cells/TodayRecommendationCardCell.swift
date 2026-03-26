import UIKit

final class TodayRecommendationCardCell: UICollectionViewCell {

    static let reuseId = "TodayRecommendationCardCell"
    static let height: CGFloat = 164

    private let thumbnailView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 14
        imageView.backgroundColor = .gpSurface
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let reasonContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.16)
        view.layer.cornerRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let reasonLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .gpPrimaryLight
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        contentView.backgroundColor = .gpSurfaceElevated
        contentView.layer.cornerRadius = 20
        contentView.clipsToBounds = true

        reasonContainerView.addSubview(reasonLabel)
        NSLayoutConstraint.activate([
            reasonLabel.topAnchor.constraint(equalTo: reasonContainerView.topAnchor, constant: 6),
            reasonLabel.bottomAnchor.constraint(equalTo: reasonContainerView.bottomAnchor, constant: -6),
            reasonLabel.leadingAnchor.constraint(equalTo: reasonContainerView.leadingAnchor, constant: 10),
            reasonLabel.trailingAnchor.constraint(equalTo: reasonContainerView.trailingAnchor, constant: -10)
        ])

        let textStack = UIStackView(arrangedSubviews: [reasonContainerView, titleLabel, subtitleLabel, metaLabel])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 8
        textStack.translatesAutoresizingMaskIntoConstraints = false

        [textStack, thumbnailView].forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            thumbnailView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            thumbnailView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 96),
            thumbnailView.heightAnchor.constraint(equalToConstant: 132),

            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16),
            textStack.trailingAnchor.constraint(equalTo: thumbnailView.leadingAnchor, constant: -14)
        ])
    }

    func configure(with recommendation: TodayRecommendation, resolvedTitle: String) {
        let game = recommendation.game
        thumbnailView.loadImage(url: game.coverImageURL)
        reasonLabel.text = recommendation.primaryReason.message
        titleLabel.text = resolvedTitle
        subtitleLabel.text = "\(game.genre) · \(game.developer)"
        metaLabel.text = "평점 \(game.formattedRating) · \(releaseText(for: game))"
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailView.cancelLoad()
        thumbnailView.image = nil
    }

    private func releaseText(for game: Game) -> String {
        if game.releaseYear > 0 { return "\(game.releaseYear)" }
        return "출시일 미정"
    }
}
