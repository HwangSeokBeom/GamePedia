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
    private lazy var dotStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [dotOne, dotTwo, dotThree])
        stackView.axis = .horizontal
        stackView.spacing = 6
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    private var expandedConstraints: [NSLayoutConstraint] = []
    private var collapsedConstraints: [NSLayoutConstraint] = []
    private var isCollapsed = false

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

        let cardTopConstraint = cardView.topAnchor.constraint(equalTo: topAnchor)
        let cardLeadingConstraint = cardView.leadingAnchor.constraint(equalTo: leadingAnchor)
        let cardTrailingConstraint = cardView.trailingAnchor.constraint(equalTo: trailingAnchor)
        let cardExpandedHeightConstraint = cardView.heightAnchor.constraint(equalToConstant: 208)
        let cardCollapsedHeightConstraint = cardView.heightAnchor.constraint(equalToConstant: 0)
        let dotStackExpandedTopConstraint = dotStack.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 10)
        let dotStackCollapsedTopConstraint = dotStack.topAnchor.constraint(equalTo: cardView.bottomAnchor)
        let dotStackCenterConstraint = dotStack.centerXAnchor.constraint(equalTo: centerXAnchor)
        let dotStackExpandedBottomConstraint = dotStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        let dotStackCollapsedBottomConstraint = dotStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        let dotStackCollapsedHeightConstraint = dotStack.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            cardTopConstraint,
            cardLeadingConstraint,
            cardTrailingConstraint,
            dotStackCenterConstraint,

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
            dotThree.heightAnchor.constraint(equalToConstant: 8)
        ])

        expandedConstraints = [
            cardExpandedHeightConstraint,
            dotStackExpandedTopConstraint,
            dotStackExpandedBottomConstraint
        ]

        collapsedConstraints = [
            cardCollapsedHeightConstraint,
            dotStackCollapsedTopConstraint,
            dotStackCollapsedBottomConstraint,
            dotStackCollapsedHeightConstraint
        ]

        NSLayoutConstraint.activate(expandedConstraints)
    }

    func setCollapsed(_ collapsed: Bool) {
        guard isCollapsed != collapsed else { return }
        isCollapsed = collapsed
        cardView.isHidden = collapsed
        dotStack.isHidden = collapsed
        if collapsed {
            NSLayoutConstraint.deactivate(expandedConstraints)
            NSLayoutConstraint.activate(collapsedConstraints)
        } else {
            NSLayoutConstraint.deactivate(collapsedConstraints)
            NSLayoutConstraint.activate(expandedConstraints)
        }
    }
}
