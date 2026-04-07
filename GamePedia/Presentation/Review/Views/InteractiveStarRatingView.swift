import UIKit

// MARK: - InteractiveStarRatingView

final class InteractiveStarRatingView: UIView {

    // MARK: Callback
    var onRatingChanged: ((Float) -> Void)?

    // MARK: Properties
    private(set) var rating: Float = 0
    private let starCount = 5
    private var starButtons: [UIButton] = []
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: Setup
    private func setup() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        for index in 0..<starCount {
            let button = UIButton()
            button.setImage(UIImage(systemName: "star", withConfiguration: symbolConfig), for: .normal)
            button.tintColor = .gpTextTertiary
            button.widthAnchor.constraint(equalToConstant: 36).isActive = true
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
            button.tag = index
            button.accessibilityLabel = L10n.tr("Localizable", "review.accessibility.starLabel", index + 1)
            button.accessibilityHint = L10n.tr("Localizable", "review.accessibility.starHint")
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(starTapped(_:)))
            button.addGestureRecognizer(tapGesture)
            starButtons.append(button)
            stack.addArrangedSubview(button)
        }
    }

    // MARK: - Actions

    @objc private func starTapped(_ recognizer: UITapGestureRecognizer) {
        guard let button = recognizer.view as? UIButton else { return }
        let tapLocation = recognizer.location(in: button)
        let tappedIndex = button.tag
        let isLeadingHalf = tapLocation.x < button.bounds.midX
        let newRating = Float(tappedIndex) + (isLeadingHalf ? 0.5 : 1.0)
        guard rating != newRating else { return }
        rating = newRating
        print("[ReviewSubmit] starTapped newRating=\(rating)")
        updateStarAppearance()
        feedbackGenerator.impactOccurred()
        onRatingChanged?(rating)
    }

    // MARK: - Public

    func setRating(_ value: Float) {
        rating = value
        updateStarAppearance()
    }

    // MARK: - Private

    private func updateStarAppearance() {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        for (index, button) in starButtons.enumerated() {
            let threshold = Float(index + 1)
            let name: String
            if rating >= threshold {
                name = "star.fill"
            } else if rating >= threshold - 0.5 {
                name = "star.leadinghalf.filled"
            } else {
                name = "star"
            }
            button.setImage(UIImage(systemName: name, withConfiguration: symbolConfig), for: .normal)
            button.tintColor = name == "star" ? .gpTextTertiary : .gpStar
            button.accessibilityValue = L10n.tr("Localizable", "review.accessibility.selected", rating)
        }
    }
}
