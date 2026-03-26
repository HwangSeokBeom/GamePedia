import UIKit
import Kingfisher

// MARK: - FeaturedBannerCell

final class FeaturedBannerCell: UICollectionViewCell {

    static let reuseId = "FeaturedBannerCell"

    private enum Metrics {
        static let cornerRadius: CGFloat = 22
        static let horizontalInset: CGFloat = 18
        static let bottomInset: CGFloat = 18
        static let contentMaxWidthRatio: CGFloat = 0.68
    }

    private var representedGameID: Int?

    private let heroImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .gpSurfaceElevated
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.black.withAlphaComponent(0.06).cgColor,
            UIColor.black.withAlphaComponent(0.18).cgColor,
            UIColor.black.withAlphaComponent(0.82).cgColor
        ]
        layer.locations = [0.0, 0.45, 1.0]
        return layer
    }()

    private let fallbackOverlayView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.gpSurfaceElevated.withAlphaComponent(0.98)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let fallbackIconView: UIImageView = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        let imageView = UIImageView(image: UIImage(systemName: "photo.on.rectangle.angled", withConfiguration: configuration))
        imageView.tintColor = .gpTextTertiary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let fallbackLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextSecondary
        label.textAlignment = .center
        label.numberOfLines = 2
        label.text = "이미지를 불러오는 중이에요"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let badgeView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.94)
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.84)
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let supportingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.74)
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var textStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [badgeView, titleLabel, metaLabel, supportingLabel])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
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
        gradientLayer.frame = heroImageView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        representedGameID = nil
        heroImageView.cancelLoad()
        heroImageView.image = nil
        fallbackLabel.text = "이미지를 불러오는 중이에요"
        fallbackOverlayView.isHidden = false
    }

    func configure(with highlight: HomeHighlightItem) {
        representedGameID = highlight.game.id
        badgeLabel.text = highlight.badgeText
        titleLabel.text = highlight.titleText
        metaLabel.text = highlight.metaText
        metaLabel.isHidden = highlight.metaText.isEmpty
        supportingLabel.text = highlight.supportingText
        supportingLabel.isHidden = highlight.supportingText.isEmpty
        fallbackLabel.text = "이미지를 불러오는 중이에요"
        fallbackOverlayView.isHidden = false

        let representedGameID = highlight.game.id
        heroImageView.kf.indicatorType = .activity
        heroImageView.kf.setImage(
            with: highlight.game.coverImageURL,
            placeholder: nil,
            options: [
                .transition(.fade(0.2)),
                .cacheOriginalImage
            ]
        ) { [weak self] result in
            guard let self, self.representedGameID == representedGameID else { return }
            switch result {
            case .success:
                self.fallbackOverlayView.isHidden = true
            case .failure:
                self.fallbackLabel.text = "대표 이미지를 불러올 수 없어요"
                self.fallbackOverlayView.isHidden = false
            }
        }
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .gpSurfaceElevated
        contentView.layer.cornerRadius = Metrics.cornerRadius
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true

        contentView.addSubview(heroImageView)
        contentView.addSubview(fallbackOverlayView)
        contentView.addSubview(textStack)
        heroImageView.layer.addSublayer(gradientLayer)

        fallbackOverlayView.addSubview(fallbackIconView)
        fallbackOverlayView.addSubview(fallbackLabel)
        badgeView.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            heroImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            heroImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            heroImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            heroImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            fallbackOverlayView.topAnchor.constraint(equalTo: contentView.topAnchor),
            fallbackOverlayView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            fallbackOverlayView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            fallbackOverlayView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            fallbackIconView.centerXAnchor.constraint(equalTo: fallbackOverlayView.centerXAnchor),
            fallbackIconView.centerYAnchor.constraint(equalTo: fallbackOverlayView.centerYAnchor, constant: -10),

            fallbackLabel.topAnchor.constraint(equalTo: fallbackIconView.bottomAnchor, constant: 10),
            fallbackLabel.centerXAnchor.constraint(equalTo: fallbackOverlayView.centerXAnchor),
            fallbackLabel.leadingAnchor.constraint(greaterThanOrEqualTo: fallbackOverlayView.leadingAnchor, constant: 24),
            fallbackLabel.trailingAnchor.constraint(lessThanOrEqualTo: fallbackOverlayView.trailingAnchor, constant: -24),

            badgeLabel.topAnchor.constraint(equalTo: badgeView.topAnchor, constant: 6),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeView.bottomAnchor, constant: -6),
            badgeLabel.leadingAnchor.constraint(equalTo: badgeView.leadingAnchor, constant: 10),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeView.trailingAnchor, constant: -10),

            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Metrics.horizontalInset),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -Metrics.horizontalInset),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Metrics.bottomInset),
            textStack.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: Metrics.contentMaxWidthRatio)
        ])
    }
}
