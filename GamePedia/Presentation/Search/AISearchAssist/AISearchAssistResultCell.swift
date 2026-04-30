import UIKit

final class AISearchAssistResultCell: UIControl {
    private enum Layout {
        static let tagHeight: CGFloat = 26
        static let coverSize: CGFloat = 72
        static let minimumCellHeight: CGFloat = 140
        static let trailingColumnWidth: CGFloat = 74
        static let tagMinimumWidth: CGFloat = 58
        static let tagMaximumWidth: CGFloat = 88
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 12
        static let mainSpacing: CGFloat = 10
    }

    private let coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .gpSurface
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }()

    private let metadataLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }()

    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .gpStar
        label.textAlignment = .right
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.85
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    private let fitBadgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .gpOnPrimary
        label.backgroundColor = .gpSuccess.withAlphaComponent(0.85)
        label.textAlignment = .center
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let reasonLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let tagsContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let tagStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 6
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.72 : 1
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(with item: AISearchAssistItemViewState) {
        coverImageView.loadImage(url: item.coverURL, placeholder: .gpGameCoverPlaceholder)
        titleLabel.text = item.title
        metadataLabel.text = item.metadataText
        ratingLabel.text = item.ratingText == "—" ? "평점 없음" : "★ \(item.ratingText)"
        ratingLabel.textColor = item.ratingText == "—" ? .gpTextTertiary : .gpStar
        reasonLabel.text = item.matchReason
        fitBadgeLabel.text = item.fitBadgeText
        fitBadgeLabel.isHidden = item.fitBadgeText == nil
        configureTags(item.visibleMatchTags)
        accessibilityLabel = "\(item.title), \(item.matchReason)"
    }

    func prepareForReuse() {
        coverImageView.cancelLoad()
        coverImageView.image = .gpGameCoverPlaceholder
        tagStackView.arrangedSubviews.forEach {
            tagStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func setup() {
        backgroundColor = .gpCardBackground
        layer.cornerRadius = 12
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityTraits = .button
        translatesAutoresizingMaskIntoConstraints = false

        tagsContainerView.addSubview(tagStackView)

        let textStackView = UIStackView(arrangedSubviews: [titleLabel, metadataLabel, reasonLabel, tagsContainerView])
        textStackView.axis = .vertical
        textStackView.spacing = 6
        textStackView.alignment = .fill
        textStackView.translatesAutoresizingMaskIntoConstraints = false
        textStackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textStackView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let trailingStackView = UIStackView(arrangedSubviews: [fitBadgeLabel, ratingLabel])
        trailingStackView.axis = .vertical
        trailingStackView.spacing = 6
        trailingStackView.alignment = .fill
        trailingStackView.translatesAutoresizingMaskIntoConstraints = false
        trailingStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        trailingStackView.setContentHuggingPriority(.required, for: .horizontal)

        let mainStackView = UIStackView(arrangedSubviews: [coverImageView, textStackView, trailingStackView])
        mainStackView.axis = .horizontal
        mainStackView.spacing = Layout.mainSpacing
        mainStackView.alignment = .top
        mainStackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(mainStackView)
        disableSubviewInteractions()

        let fitBadgeHeightConstraint = fitBadgeLabel.heightAnchor.constraint(equalToConstant: 20)
        fitBadgeHeightConstraint.priority = UILayoutPriority(999)
        let tagsHeightConstraint = tagsContainerView.heightAnchor.constraint(equalToConstant: Layout.tagHeight)
        tagsHeightConstraint.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.minimumCellHeight),
            coverImageView.widthAnchor.constraint(equalToConstant: Layout.coverSize),
            coverImageView.heightAnchor.constraint(equalToConstant: Layout.coverSize),

            mainStackView.topAnchor.constraint(equalTo: topAnchor, constant: Layout.verticalPadding),
            mainStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalPadding),
            mainStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalPadding),
            mainStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.verticalPadding),

            fitBadgeHeightConstraint,
            fitBadgeLabel.widthAnchor.constraint(equalToConstant: Layout.trailingColumnWidth),
            trailingStackView.widthAnchor.constraint(equalToConstant: Layout.trailingColumnWidth),
            ratingLabel.widthAnchor.constraint(equalToConstant: Layout.trailingColumnWidth),
            tagsHeightConstraint,
            tagStackView.topAnchor.constraint(equalTo: tagsContainerView.topAnchor),
            tagStackView.leadingAnchor.constraint(equalTo: tagsContainerView.leadingAnchor),
            tagStackView.bottomAnchor.constraint(equalTo: tagsContainerView.bottomAnchor),
            tagStackView.trailingAnchor.constraint(lessThanOrEqualTo: tagsContainerView.trailingAnchor),
            tagStackView.widthAnchor.constraint(lessThanOrEqualTo: tagsContainerView.widthAnchor)
        ])
    }

    private func configureTags(_ tags: [String]) {
        tagStackView.arrangedSubviews.forEach {
            tagStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let visibleTags = sanitizedTags(tags)
        let maximumVisibleTagCount = maximumVisibleTagCount()
        Array(visibleTags.prefix(maximumVisibleTagCount)).enumerated().forEach { index, tag in
            let pillView = AISearchAssistTagPillView(title: tag)
            let compressionPriority = UILayoutPriority(752 - Float(index))
            pillView.setContentCompressionResistancePriority(compressionPriority, for: .horizontal)
            pillView.setContentHuggingPriority(.defaultHigh, for: .horizontal)

            let minimumWidthConstraint = pillView.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.tagMinimumWidth)
            minimumWidthConstraint.priority = .defaultHigh
            let maximumWidthConstraint = pillView.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.tagMaximumWidth)
            maximumWidthConstraint.priority = .required

            NSLayoutConstraint.activate([
                pillView.heightAnchor.constraint(equalToConstant: Layout.tagHeight),
                minimumWidthConstraint,
                maximumWidthConstraint
            ])
            tagStackView.addArrangedSubview(pillView)
        }

        tagsContainerView.isHidden = tagStackView.arrangedSubviews.isEmpty
    }

    private func sanitizedTags(_ tags: [String]) -> [String] {
        var seenTags = Set<String>()
        return tags.compactMap { tag in
            let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTag.isEmpty else { return nil }
            guard !trimmedTag.isEllipsisOnly else { return nil }

            let normalizedTag = trimmedTag.lowercased()
            guard seenTags.insert(normalizedTag).inserted else { return nil }
            return trimmedTag
        }
    }

    private func maximumVisibleTagCount() -> Int {
        let estimatedTextWidth = UIScreen.main.bounds.width
            - 40
            - 32
            - (Layout.horizontalPadding * 2)
            - Layout.coverSize
            - Layout.trailingColumnWidth
            - (Layout.mainSpacing * 2)

        switch estimatedTextWidth {
        case 180...:
            return 3
        case 68..<180:
            return 2
        default:
            return 1
        }
    }

    private func disableSubviewInteractions() {
        subviews.forEach { disableUserInteraction(in: $0) }
    }

    private func disableUserInteraction(in view: UIView) {
        view.isUserInteractionEnabled = false
        view.subviews.forEach { disableUserInteraction(in: $0) }
    }
}

private final class AISearchAssistTagPillView: UIView {
    private enum Layout {
        static let height: CGFloat = 26
        static let horizontalPadding: CGFloat = 10
        static let minimumWidth: CGFloat = 36
    }

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .gpPrimary
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.82
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override var intrinsicContentSize: CGSize {
        let preferredWidth = titleLabel.intrinsicContentSize.width + (Layout.horizontalPadding * 2)
        return CGSize(width: max(Layout.minimumWidth, preferredWidth), height: Layout.height)
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
        backgroundColor = .gpPrimaryLight.withAlphaComponent(0.18)
        layer.cornerRadius = Layout.height / 2
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)

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

private extension String {
    var isEllipsisOnly: Bool {
        let reduced = filter { character in
            character != "." && character != "…" && !character.isWhitespace
        }
        return reduced.isEmpty
    }
}
