import UIKit

final class HomeHighlightSkeletonView: UIView {

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 22
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let badgePlaceholder = SkeletonPlaceholderView(cornerRadius: 8)
    private let titlePlaceholderTop = SkeletonPlaceholderView(cornerRadius: 8)
    private let titlePlaceholderBottom = SkeletonPlaceholderView(cornerRadius: 8)
    private let metaPlaceholder = SkeletonPlaceholderView(cornerRadius: 7)
    private let supportingPlaceholder = SkeletonPlaceholderView(cornerRadius: 7)
    private let heroImagePlaceholder = SkeletonPlaceholderView(cornerRadius: 18)
    private let dotOne = SkeletonPlaceholderView(cornerRadius: 4)
    private let dotTwo = SkeletonPlaceholderView(cornerRadius: 4)
    private let dotThree = SkeletonPlaceholderView(cornerRadius: 4)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .clear

        let dotStack = UIStackView(arrangedSubviews: [dotOne, dotTwo, dotThree])
        dotStack.axis = .horizontal
        dotStack.spacing = 6
        dotStack.alignment = .center
        dotStack.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [
            badgePlaceholder,
            titlePlaceholderTop,
            titlePlaceholderBottom,
            metaPlaceholder,
            supportingPlaceholder
        ])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 8
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(cardView)
        addSubview(dotStack)
        cardView.addSubview(heroImagePlaceholder)
        cardView.addSubview(textStack)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.heightAnchor.constraint(equalToConstant: 208),

            heroImagePlaceholder.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            heroImagePlaceholder.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            heroImagePlaceholder.widthAnchor.constraint(equalToConstant: 96),
            heroImagePlaceholder.heightAnchor.constraint(equalToConstant: 132),

            textStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: heroImagePlaceholder.leadingAnchor, constant: -16),
            textStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -18),

            badgePlaceholder.widthAnchor.constraint(equalToConstant: 76),
            badgePlaceholder.heightAnchor.constraint(equalToConstant: 24),
            titlePlaceholderTop.widthAnchor.constraint(equalToConstant: 156),
            titlePlaceholderTop.heightAnchor.constraint(equalToConstant: 24),
            titlePlaceholderBottom.widthAnchor.constraint(equalToConstant: 132),
            titlePlaceholderBottom.heightAnchor.constraint(equalToConstant: 24),
            metaPlaceholder.widthAnchor.constraint(equalToConstant: 118),
            metaPlaceholder.heightAnchor.constraint(equalToConstant: 14),
            supportingPlaceholder.widthAnchor.constraint(equalToConstant: 168),
            supportingPlaceholder.heightAnchor.constraint(equalToConstant: 14),

            dotOne.widthAnchor.constraint(equalToConstant: 8),
            dotOne.heightAnchor.constraint(equalToConstant: 8),
            dotTwo.widthAnchor.constraint(equalToConstant: 8),
            dotTwo.heightAnchor.constraint(equalToConstant: 8),
            dotThree.widthAnchor.constraint(equalToConstant: 8),
            dotThree.heightAnchor.constraint(equalToConstant: 8),

            dotStack.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 10),
            dotStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            dotStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
