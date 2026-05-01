import UIKit

final class LibraryCuratorModeChipCell: UICollectionViewCell {
    static let reuseId = "LibraryCuratorModeChipCell"

#if DEBUG
    private static var loggedConfigurationKeys = Set<String>()
#endif

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override var isSelected: Bool {
        didSet { applyStyle(animated: oldValue != isSelected) }
    }

    override var isHighlighted: Bool {
        didSet { applyStyle(animated: false) }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        isSelected = false
        isHighlighted = false
    }

    func configure(id: String, title: String, selected: Bool) {
        titleLabel.text = title
        isSelected = selected
        accessibilityLabel = title
        accessibilityIdentifier = id
        accessibilityTraits = selected ? [.button, .selected] : [.button]
        applyStyle(animated: false)
#if DEBUG
        let intrinsicWidth = titleLabel.intrinsicContentSize.width + 28
        let logKey = "\(id)|\(selected)|\(Int(intrinsicWidth.rounded()))"
        if Self.loggedConfigurationKeys.insert(logKey).inserted {
            print("[LibraryCuratorLayout] chipCellConfigured id=\(id) title=\(title) selected=\(selected) intrinsicWidth=\(Int(intrinsicWidth.rounded()))")
        }
#endif
    }

    private func setup() {
        contentView.setContentHuggingPriority(.required, for: .horizontal)
        contentView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        contentView.layer.cornerRadius = 17
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1
        contentView.layer.masksToBounds = false
        contentView.addSubview(titleLabel)

        let trailingConstraint = titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14)
        let bottomConstraint = titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        trailingConstraint.priority = .init(999)
        bottomConstraint.priority = .init(999)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            trailingConstraint,
            bottomConstraint
        ])
        applyStyle(animated: false)
    }

    private func applyStyle(animated: Bool) {
        let changes = {
            let selectedOrHighlighted = self.isSelected || self.isHighlighted
            self.contentView.backgroundColor = self.isSelected
                ? .gpPrimary
                : .gpSurface
            self.contentView.alpha = 1
            self.contentView.layer.borderColor = (selectedOrHighlighted ? UIColor.gpPrimary : UIColor.gpPrimary.withAlphaComponent(0.55)).cgColor
            self.contentView.layer.shadowColor = UIColor.gpPrimary.cgColor
            self.contentView.layer.shadowOpacity = self.isSelected ? 0.24 : 0
            self.contentView.layer.shadowRadius = self.isSelected ? 8 : 0
            self.contentView.layer.shadowOffset = CGSize(width: 0, height: 3)
            self.titleLabel.textColor = self.isSelected ? .gpOnPrimary : .gpTextPrimary
            self.titleLabel.alpha = self.isHighlighted && !self.isSelected ? 0.88 : 1
            self.titleLabel.font = .systemFont(ofSize: 13, weight: self.isSelected ? .semibold : .medium)
            self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
        }

        guard animated else {
            changes()
            return
        }

        UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            changes()
        }
    }
}
