import UIKit

final class FriendTasteSummaryCell: UITableViewCell {
    static let reuseID = "FriendTasteSummaryCell"

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 1
        return label
    }()

    private let summaryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        return label
    }()

    private let primaryChipRow = UIStackView()
    private let secondaryChipRow = UIStackView()
    private lazy var chipRowsStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [primaryChipRow, secondaryChipRow])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, summary: String, chips: [String]) {
        titleLabel.text = title
        summaryLabel.text = summary
        configureChipRows(with: chips)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        [primaryChipRow, secondaryChipRow].forEach { row in
            row.arrangedSubviews.forEach { subview in
                row.removeArrangedSubview(subview)
                subview.removeFromSuperview()
            }
        }
    }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        [primaryChipRow, secondaryChipRow].forEach {
            $0.axis = .horizontal
            $0.alignment = .leading
            $0.spacing = 8
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        let textStack = UIStackView(arrangedSubviews: [titleLabel, summaryLabel, chipRowsStack])
        textStack.axis = .vertical
        textStack.spacing = 10
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        cardView.addSubview(textStack)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            textStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            textStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -16),
            textStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    private func configureChipRows(with chips: [String]) {
        let visibleChips = Array(chips.prefix(4))
        let firstRow = Array(visibleChips.prefix(2))
        let secondRow = Array(visibleChips.dropFirst(2).prefix(2))

        primaryChipRow.isHidden = firstRow.isEmpty
        secondaryChipRow.isHidden = secondRow.isEmpty

        firstRow.forEach { primaryChipRow.addArrangedSubview(makeChipLabel(text: $0)) }
        secondRow.forEach { secondaryChipRow.addArrangedSubview(makeChipLabel(text: $0)) }
    }

    private func makeChipLabel(text: String) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.14)
        containerView.layer.cornerRadius = 12
        containerView.layer.cornerCurve = .continuous

        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpPrimaryLight
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10)
        ])
        return containerView
    }
}
