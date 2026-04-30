import UIKit

final class AIRecommendationResultCell: UITableViewCell {
    static let reuseId = "AIRecommendationResultCell"

    private enum Layout {
        static let tagHeight: CGFloat = 28
        static let tagSpacing: CGFloat = 8
        static let tagMaximumWidth: CGFloat = 132
        static let tagMinimumWidth: CGFloat = 44
    }

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 14
        view.clipsToBounds = true
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

    private let metadataLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let reasonLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 3
        label.lineBreakMode = .byWordWrapping
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

    private let favoriteButton: UIButton = {
        let button = UIButton(type: .system)
        button.tintColor = .gpPrimary
        button.backgroundColor = .gpSurface
        button.layer.cornerRadius = 16
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let tagsContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let badgeStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 6
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let tagStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = Layout.tagSpacing
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    var onFavoriteButtonTapped: (() -> Void)?

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
        favoriteButton.isEnabled = true
        ratingLabel.isHidden = false
        tagStackView.arrangedSubviews.forEach {
            tagStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        badgeStackView.arrangedSubviews.forEach {
            badgeStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        onFavoriteButtonTapped = nil
    }

    func configure(with item: AIRecommendationItemViewState) {
        coverImageView.loadImage(url: item.coverURL, placeholder: .gpGameCoverPlaceholder)
        titleLabel.text = item.title
        metadataLabel.text = item.metadataText
        reasonLabel.text = item.reason
        ratingLabel.text = item.ratingText == "—" ? L10n.Common.Label.noRating : "★ \(item.ratingText)"
        ratingLabel.textColor = item.ratingText == "—" ? .gpTextTertiary : .gpStar
        favoriteButton.setImage(
            UIImage(systemName: item.isFavorite ? "bookmark.fill" : "bookmark"),
            for: .normal
        )
        favoriteButton.isEnabled = !item.isFavoriteUpdating
        favoriteButton.alpha = item.isFavoriteUpdating ? 0.55 : 1.0
        configureBadges(for: item)
        configureTags(item.displayTags)
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

        let metadataRow = UIStackView(arrangedSubviews: [metadataLabel, ratingLabel])
        metadataRow.axis = .horizontal
        metadataRow.spacing = 8
        metadataRow.alignment = .center
        metadataRow.translatesAutoresizingMaskIntoConstraints = false

        tagsContainerView.addSubview(tagStackView)

        let infoStackView = UIStackView(arrangedSubviews: [titleRow, metadataRow, reasonLabel, badgeStackView, tagsContainerView])
        infoStackView.axis = .vertical
        infoStackView.spacing = 7
        infoStackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        cardView.addSubview(coverImageView)
        cardView.addSubview(infoStackView)

        favoriteButton.addTarget(self, action: #selector(didTapFavoriteButton), for: .touchUpInside)

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
            favoriteButton.heightAnchor.constraint(equalToConstant: 32),

            tagsContainerView.heightAnchor.constraint(equalToConstant: Layout.tagHeight),
            tagStackView.topAnchor.constraint(equalTo: tagsContainerView.topAnchor),
            tagStackView.leadingAnchor.constraint(equalTo: tagsContainerView.leadingAnchor),
            tagStackView.bottomAnchor.constraint(equalTo: tagsContainerView.bottomAnchor),
            tagStackView.trailingAnchor.constraint(lessThanOrEqualTo: tagsContainerView.trailingAnchor),
            tagStackView.widthAnchor.constraint(lessThanOrEqualTo: tagsContainerView.widthAnchor)
        ])
    }

    private func configureBadges(for item: AIRecommendationItemViewState) {
        badgeStackView.arrangedSubviews.forEach {
            badgeStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        if item.isPersonalized {
            badgeStackView.addArrangedSubview(
                makeBadgeLabel(
                    title: L10n.tr("Localizable", "ai_recommendation_personalized_badge"),
                    foregroundColor: .gpPrimary,
                    backgroundColor: .gpPrimaryLight.withAlphaComponent(0.22)
                )
            )
        }

        if item.isFallback {
            badgeStackView.addArrangedSubview(
                makeBadgeLabel(
                    title: L10n.tr("Localizable", "ai_recommendation_fallback_badge"),
                    foregroundColor: .gpTextSecondary,
                    backgroundColor: .gpSurface
                )
            )
        }

        badgeStackView.isHidden = badgeStackView.arrangedSubviews.isEmpty
    }

    private func makeBadgeLabel(title: String, foregroundColor: UIColor, backgroundColor: UIColor) -> UILabel {
        let label = PaddingLabel(insets: UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        label.text = title
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = foregroundColor
        label.backgroundColor = backgroundColor
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    private func configureTags(_ tags: [String]) {
        tagStackView.arrangedSubviews.forEach {
            tagStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        Array(tags.prefix(3)).enumerated().forEach { index, tag in
            let pillView = AIRecommendationTagPillView(title: tag)
            pillView.translatesAutoresizingMaskIntoConstraints = false

            let compressionPriority = UILayoutPriority(752 - Float(index))
            pillView.setContentCompressionResistancePriority(compressionPriority, for: .horizontal)
            pillView.setContentHuggingPriority(.defaultHigh, for: .horizontal)

            let minimumWidthConstraint = pillView.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.tagMinimumWidth)
            minimumWidthConstraint.priority = .defaultHigh

            NSLayoutConstraint.activate([
                pillView.heightAnchor.constraint(equalToConstant: Layout.tagHeight),
                pillView.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.tagMaximumWidth),
                minimumWidthConstraint
            ])

            tagStackView.addArrangedSubview(pillView)
        }

        tagsContainerView.accessibilityElementsHidden = tags.isEmpty
    }

    @objc
    private func didTapFavoriteButton() {
        onFavoriteButtonTapped?()
    }
}

private final class AIRecommendationTagPillView: UIView {
    private enum Layout {
        static let height: CGFloat = 28
        static let horizontalPadding: CGFloat = 12
        static let minimumWidth: CGFloat = 44
        static let maximumWidth: CGFloat = 132
    }

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .gpPrimary
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override var intrinsicContentSize: CGSize {
        let labelWidth = titleLabel.intrinsicContentSize.width
        let preferredWidth = labelWidth + (Layout.horizontalPadding * 2)
        let clampedWidth = min(Layout.maximumWidth, max(Layout.minimumWidth, preferredWidth))
        return CGSize(width: clampedWidth, height: Layout.height)
    }

    init(title: String) {
        super.init(frame: .zero)
        setup()
        configure(title: title)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .gpPrimaryLight.withAlphaComponent(0.2)
        layer.cornerRadius = Layout.height / 2
        clipsToBounds = true

        addSubview(titleLabel)

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalPadding),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalPadding),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func configure(title: String) {
        titleLabel.text = title
        accessibilityLabel = title
        invalidateIntrinsicContentSize()
    }
}

private final class PaddingLabel: UILabel {
    private let insets: UIEdgeInsets

    init(insets: UIEdgeInsets) {
        self.insets = insets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        self.insets = .zero
        super.init(coder: coder)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}
