import UIKit

final class AIRecommendationResultCell: UITableViewCell {
    static let reuseId = "AIRecommendationResultCell"

    private enum Layout {
        static let maximumVisibleChipCount = 4
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

    private let chipFlowView = AIRecommendationChipFlowView()

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
        chipFlowView.configure(chips: [])
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
        configureChips(for: item)
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

        let infoStackView = UIStackView(arrangedSubviews: [titleRow, metadataRow, reasonLabel, chipFlowView])
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
            favoriteButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func configureChips(for item: AIRecommendationItemViewState) {
        var chips: [AIRecommendationChip] = []
        var seenKeys = Set<String>()

        if item.isPersonalized {
            appendChip(
                title: L10n.tr("Localizable", "ai_recommendation_personalized_badge"),
                style: .badge(foregroundColor: .gpPrimary, backgroundColor: .gpPrimaryLight.withAlphaComponent(0.22)),
                to: &chips,
                seenKeys: &seenKeys
            )
        }

        if item.isFallback {
            appendChip(
                title: L10n.tr("Localizable", "ai_recommendation_fallback_badge"),
                style: .badge(foregroundColor: .gpTextSecondary, backgroundColor: .gpSurface),
                to: &chips,
                seenKeys: &seenKeys
            )
        }

        item.displayTags.forEach { tag in
            appendChip(
                title: tag,
                style: .tag,
                to: &chips,
                seenKeys: &seenKeys
            )
        }

        chipFlowView.configure(chips: Array(chips.prefix(Layout.maximumVisibleChipCount)))
    }

    private func appendChip(
        title: String,
        style: AIRecommendationChipStyle,
        to chips: inout [AIRecommendationChip],
        seenKeys: inout Set<String>
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedTitle.isEllipsisOnly else { return }

        let normalizedKey = RecommendationTagLocalizer.normalizedKey(for: trimmedTitle)
        let deduplicationKey = normalizedKey.isEmpty ? trimmedTitle.lowercased() : normalizedKey
        guard seenKeys.insert(deduplicationKey).inserted else { return }

        chips.append(AIRecommendationChip(title: trimmedTitle, style: style))
    }

    @objc
    private func didTapFavoriteButton() {
        onFavoriteButtonTapped?()
    }
}

private struct AIRecommendationChip {
    let title: String
    let style: AIRecommendationChipStyle
}

private struct AIRecommendationChipStyle {
    let foregroundColor: UIColor
    let backgroundColor: UIColor
    let font: UIFont

    static let tag = AIRecommendationChipStyle(
        foregroundColor: .gpPrimary,
        backgroundColor: .gpPrimaryLight.withAlphaComponent(0.2),
        font: .systemFont(ofSize: 11, weight: .medium)
    )

    static func badge(foregroundColor: UIColor, backgroundColor: UIColor) -> AIRecommendationChipStyle {
        AIRecommendationChipStyle(
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor,
            font: .systemFont(ofSize: 11, weight: .semibold)
        )
    }
}

private final class AIRecommendationChipFlowView: UIView {
    private enum Layout {
        static let horizontalSpacing: CGFloat = 8
        static let verticalSpacing: CGFloat = 8
        static let maximumRows = 2
    }

    private var chipViews: [AIRecommendationTagPillView] = []
    private var lastMeasuredWidth: CGFloat = 0

    func configure(chips: [AIRecommendationChip]) {
        chipViews.forEach { $0.removeFromSuperview() }
        chipViews = chips.map { chip in
            let view = AIRecommendationTagPillView(chip: chip)
            addSubview(view)
            return view
        }

        isHidden = chipViews.isEmpty
        accessibilityElementsHidden = chipViews.isEmpty
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if abs(bounds.width - lastMeasuredWidth) > 0.5 {
            lastMeasuredWidth = bounds.width
            invalidateIntrinsicContentSize()
        }

        _ = layoutChips(width: bounds.width, shouldApplyFrames: true)
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: layoutChips(width: resolvedLayoutWidth, shouldApplyFrames: false)
        )
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(
            width: size.width,
            height: layoutChips(width: size.width, shouldApplyFrames: false)
        )
    }

    private var resolvedLayoutWidth: CGFloat {
        bounds.width > 0 ? bounds.width : max(1, UIScreen.main.bounds.width - 128)
    }

    private func layoutChips(width: CGFloat, shouldApplyFrames: Bool) -> CGFloat {
        let availableWidth = max(width, 1)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var rowCount = 1
        var didPlaceChip = false

        for chipView in chipViews {
            let fittingSize = chipView.intrinsicContentSize
            let chipWidth = min(fittingSize.width, availableWidth)
            let chipHeight = fittingSize.height

            if x > 0, x + chipWidth > availableWidth {
                guard rowCount < Layout.maximumRows else {
                    if shouldApplyFrames {
                        chipView.isHidden = true
                    }
                    continue
                }

                x = 0
                y += rowHeight + Layout.verticalSpacing
                rowHeight = 0
                rowCount += 1
            }

            if shouldApplyFrames {
                chipView.isHidden = false
                chipView.frame = CGRect(x: x, y: y, width: chipWidth, height: chipHeight)
            }

            x += chipWidth + Layout.horizontalSpacing
            rowHeight = max(rowHeight, chipHeight)
            didPlaceChip = true
        }

        return didPlaceChip ? y + rowHeight : 0
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

    init(chip: AIRecommendationChip) {
        super.init(frame: .zero)
        setup()
        configure(chip: chip)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
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

    private func configure(chip: AIRecommendationChip) {
        backgroundColor = chip.style.backgroundColor
        titleLabel.font = chip.style.font
        titleLabel.textColor = chip.style.foregroundColor
        titleLabel.text = chip.title
        accessibilityLabel = chip.title
        invalidateIntrinsicContentSize()
    }
}

private extension String {
    var isEllipsisOnly: Bool {
        let reduced = filter { character in
            character != "." && character != "…" && !character.isWhitespace
        }
        return reduced.isEmpty
    }
}
