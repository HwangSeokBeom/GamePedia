import UIKit

// MARK: - StarRatingView (read-only)

final class StarRatingView: UIView {

    // MARK: Properties
    private var starImageViews: [UIImageView] = []
    private let starCount = 5

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
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        for _ in 0..<starCount {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFit
            iv.tintColor = .gpStar
            iv.widthAnchor.constraint(equalToConstant: 12).isActive = true
            iv.heightAnchor.constraint(equalToConstant: 12).isActive = true
            starImageViews.append(iv)
            stack.addArrangedSubview(iv)
        }
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
