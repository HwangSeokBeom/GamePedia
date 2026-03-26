import UIKit

// MARK: - InteractiveStarRatingView
// Supports half-star taps: tap left half → 0.5 steps

final class InteractiveStarRatingView: UIView {

    // MARK: Callback
    var onRatingChanged: ((Float) -> Void)?

    // MARK: Properties
    private(set) var rating: Float = 0
    private let starCount = 5
    private var starButtons: [UIButton] = []

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
            stack.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
        for index in 0..<starCount {
            let button = UIButton()
            button.setImage(UIImage(systemName: "star", withConfiguration: symbolConfig), for: .normal)
            button.tintColor = .gpStar
            button.widthAnchor.constraint(equalToConstant: 40).isActive = true
            button.heightAnchor.constraint(equalToConstant: 40).isActive = true
            button.tag = index
            button.addTarget(self, action: #selector(starTapped(_:)), for: .touchUpInside)
            starButtons.append(button)
            stack.addArrangedSubview(button)
        }
    }

    // MARK: - Actions

    @objc private func starTapped(_ sender: UIButton) {
        let tappedIndex = sender.tag
        let newRating = Float(tappedIndex + 1)
        rating = newRating
        updateStarAppearance()
        onRatingChanged?(rating)
    }

    // MARK: - Public

    func setRating(_ value: Float) {
        rating = value
        updateStarAppearance()
    }

    // MARK: - Private

    private func updateStarAppearance() {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
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
        }
    }
}
