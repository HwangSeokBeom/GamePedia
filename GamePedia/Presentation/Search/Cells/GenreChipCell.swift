import UIKit

// MARK: - GenreChipCell

final class GenreChipCell: UICollectionViewCell {

    static let reuseId = "GenreChipCell"

    private let label: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
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
        // Clip cell background to rounded shape
        layer.masksToBounds = true
        layer.borderWidth = 1

        // Transparent contentView — fill/border handled at cell layer only
        contentView.backgroundColor = .clear

        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14)
        ])
    }

    // Set cornerRadius here so it's based on the final rendered bounds, not the
    // zero-frame at init time. This guarantees a perfect capsule shape.
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    func configure(genre: String, isSelected: Bool) {
        label.text = genre
        if isSelected {
            backgroundColor = .gpPrimary
            layer.borderColor = UIColor.gpPrimary.cgColor
            label.textColor = .gpOnPrimary
            label.font = .systemFont(ofSize: 13, weight: .semibold)
        } else {
            backgroundColor = .gpSurface
            layer.borderColor = UIColor.gpSeparator.cgColor
            label.textColor = .gpTextSecondary
            label.font = .systemFont(ofSize: 13, weight: .medium)
        }
    }

    static func estimatedWidth(for genre: String) -> CGFloat {
        let textWidth = (genre as NSString).size(
            withAttributes: [.font: UIFont.systemFont(ofSize: 13, weight: .medium)]
        ).width
        return ceil(textWidth) + 28  // 14pt padding × 2 sides
    }
}
