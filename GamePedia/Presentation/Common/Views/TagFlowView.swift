import UIKit

struct TagFlowItem: Hashable {
    let id: String
    let title: String
    let foregroundColor: UIColor
    let backgroundColor: UIColor
    let selectedForegroundColor: UIColor
    let selectedBackgroundColor: UIColor
    let font: UIFont
    let isSelected: Bool

    init(
        id: String? = nil,
        title: String,
        foregroundColor: UIColor = .gpPrimary,
        backgroundColor: UIColor = UIColor.gpPrimaryLight.withAlphaComponent(0.18),
        selectedForegroundColor: UIColor = .gpOnPrimary,
        selectedBackgroundColor: UIColor = .gpPrimary,
        font: UIFont = .systemFont(ofSize: 11, weight: .medium),
        isSelected: Bool = false
    ) {
        self.id = id ?? RecommendationTagLocalizer.normalizedKey(for: title)
        self.title = title
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.selectedForegroundColor = selectedForegroundColor
        self.selectedBackgroundColor = selectedBackgroundColor
        self.font = font
        self.isSelected = isSelected
    }
}

final class TagFlowView: UIView {
    private enum Layout {
        static let horizontalSpacing: CGFloat = 8
        static let verticalSpacing: CGFloat = 8
        static let defaultMaximumRows = 2
    }

    var maximumRows: Int = Layout.defaultMaximumRows {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var maximumChipWidth: CGFloat = 132 {
        didSet {
            chipViews.forEach { $0.maximumWidth = maximumChipWidth }
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var minimumChipWidth: CGFloat = 44 {
        didSet {
            chipViews.forEach { $0.minimumWidth = minimumChipWidth }
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var onItemTapped: ((TagFlowItem) -> Void)?

    private var chipViews: [TagPillView] = []
    private var lastMeasuredWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(items: [TagFlowItem]) {
        chipViews.forEach { $0.removeFromSuperview() }
        chipViews = deduplicatedItems(items).map { item in
            let view = TagPillView(item: item)
            view.maximumWidth = maximumChipWidth
            view.minimumWidth = minimumChipWidth
            view.onTap = { [weak self] tappedItem in
                self?.onItemTapped?(tappedItem)
            }
            addSubview(view)
            return view
        }

        isHidden = chipViews.isEmpty
        accessibilityElementsHidden = chipViews.isEmpty
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
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
        let allowedRows = max(1, maximumRows)
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
                guard rowCount < allowedRows else {
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

    private func deduplicatedItems(_ items: [TagFlowItem]) -> [TagFlowItem] {
        var seenKeys = Set<String>()
        return items.compactMap { item in
            let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty, !trimmedTitle.isEllipsisOnly else { return nil }
            let normalizedKey = RecommendationTagLocalizer.normalizedKey(for: trimmedTitle)
            let deduplicationKey = normalizedKey.isEmpty ? trimmedTitle.lowercased() : normalizedKey
            guard seenKeys.insert(deduplicationKey).inserted else { return nil }

            return TagFlowItem(
                id: item.id,
                title: trimmedTitle,
                foregroundColor: item.foregroundColor,
                backgroundColor: item.backgroundColor,
                selectedForegroundColor: item.selectedForegroundColor,
                selectedBackgroundColor: item.selectedBackgroundColor,
                font: item.font,
                isSelected: item.isSelected
            )
        }
    }
}

private final class TagPillView: UIView {
    private enum Layout {
        static let verticalPadding: CGFloat = 7
        static let horizontalPadding: CGFloat = 12
    }

    var minimumWidth: CGFloat = 44 {
        didSet { invalidateIntrinsicContentSize() }
    }

    var maximumWidth: CGFloat = 132 {
        didSet { invalidateIntrinsicContentSize() }
    }

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var item: TagFlowItem?
    var onTap: ((TagFlowItem) -> Void)?

    override var intrinsicContentSize: CGSize {
        let preferredWidth = titleLabel.intrinsicContentSize.width + (Layout.horizontalPadding * 2)
        let clampedWidth = min(maximumWidth, max(minimumWidth, preferredWidth))
        let preferredHeight = titleLabel.intrinsicContentSize.height + (Layout.verticalPadding * 2)
        return CGSize(width: clampedWidth, height: ceil(preferredHeight))
    }

    init(item: TagFlowItem) {
        super.init(frame: .zero)
        setup()
        configure(item: item)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        clipsToBounds = true
        addSubview(titleLabel)

        let trailingConstraint = titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalPadding)
        let bottomConstraint = titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.verticalPadding)
        trailingConstraint.priority = .init(999)
        bottomConstraint.priority = .init(999)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalPadding),
            trailingConstraint,
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: Layout.verticalPadding),
            bottomConstraint
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap)))
    }

    private func configure(item: TagFlowItem) {
        self.item = item
        backgroundColor = item.isSelected ? item.selectedBackgroundColor : item.backgroundColor
        titleLabel.font = item.font
        titleLabel.textColor = item.isSelected ? item.selectedForegroundColor : item.foregroundColor
        titleLabel.text = item.title
        layer.borderWidth = 1
        layer.borderColor = (item.isSelected ? UIColor.gpPrimary : UIColor.gpPrimary.withAlphaComponent(0.25)).cgColor
        accessibilityLabel = item.title
        accessibilityTraits = item.isSelected ? [.button, .selected] : [.button]
        invalidateIntrinsicContentSize()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    @objc
    private func didTap() {
        guard let item else { return }
        onTap?(item)
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
