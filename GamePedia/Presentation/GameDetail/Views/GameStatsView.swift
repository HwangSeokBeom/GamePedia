import UIKit

// MARK: - GameStatsView
// Shows rating / playtime / review count in a horizontal row

final class GameStatsView: UIView {

    // MARK: Subviews
    private let ratingStack  = StatItemView()
    private let playtimeStack = StatItemView()
    private let reviewStack  = StatItemView()

    private let divider1 = DividerView()
    private let divider2 = DividerView()

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let stack = UIStackView(arrangedSubviews: [
            ratingStack, divider1, playtimeStack, divider2, reviewStack
        ])
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider1.widthAnchor.constraint(equalToConstant: 1),
            divider1.heightAnchor.constraint(equalToConstant: 40),
            divider2.widthAnchor.constraint(equalToConstant: 1),
            divider2.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    // MARK: Configure
    func configure(game: GameDetail) {
        ratingStack.configure(value: game.formattedRating, label: L10n.Detail.Label.rating)
        playtimeStack.configure(value: game.formattedPlaytime, label: L10n.Detail.Stats.playtime)
        reviewStack.configure(value: game.formattedReviewCount, label: L10n.Detail.Stats.reviews)
    }
}

// MARK: - StatItemView

private final class StatItemView: UIView {

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .gpTextPrimary
        label.textAlignment = .center
        return label
    }()

    private let captionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextSecondary
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    func configure(value: String, label: String) {
        valueLabel.text = value
        captionLabel.text = label
    }
}

// MARK: - DividerView

private final class DividerView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .gpSeparator
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }
}
