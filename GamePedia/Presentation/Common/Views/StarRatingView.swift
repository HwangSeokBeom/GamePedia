import UIKit

// MARK: - StarRatingView (read-only)

final class StarRatingView: UIView {

    // MARK: Properties
    private let stackView = UIStackView()
    private var starImageViews: [UIImageView] = []
    private let starCount = 5
    private let starSize: CGFloat = 12
    private let starSpacing: CGFloat = 2

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupStars()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupStars()
    }

    // MARK: Setup
    private func setupStars() {
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = starSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])

        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        stackView.setContentHuggingPriority(.required, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)

        for _ in 0..<starCount {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFit
            iv.tintColor = .gpStar
            iv.widthAnchor.constraint(equalToConstant: starSize).isActive = true
            iv.heightAnchor.constraint(equalToConstant: starSize).isActive = true
            starImageViews.append(iv)
            stackView.addArrangedSubview(iv)
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: CGFloat(starCount) * starSize + CGFloat(starCount - 1) * starSpacing,
            height: starSize
        )
    }

    // MARK: - Configure

    /// rating: 0.0 – 5.0
    func configure(rating: Double) {
        for (index, iv) in starImageViews.enumerated() {
            let threshold = Double(index) + 1
            if rating >= threshold {
                iv.image = UIImage(systemName: "star.fill")
            } else if rating >= threshold - 0.5 {
                iv.image = UIImage(systemName: "star.leadinghalf.filled")
            } else {
                iv.image = UIImage(systemName: "star")
            }
        }
    }
}
