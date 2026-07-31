import UIKit

// MARK: - TodayItemCell
//
// One Today row: server content on top, the app's own explanation beneath.
//
// Every label is Dynamic Type driven and unbounded in line count, so a long
// Korean, Japanese or Simplified Chinese string grows the cell rather than
// truncating. The whole cell is one accessibility element carrying the label
// the display model already composed, so VoiceOver hears the same information
// the eye reads instead of four disconnected fragments.

final class TodayItemCell: UICollectionViewCell {

    static let reuseId = "TodayItemCell"

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let detailStack = UIStackView()
    private let container = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    private func setup() {
        contentView.backgroundColor = .gpCardBackground
        contentView.layer.cornerRadius = 14
        contentView.layer.masksToBounds = true

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .gpTextPrimary
        titleLabel.numberOfLines = 0

        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .gpTextSecondary
        subtitleLabel.numberOfLines = 0

        detailStack.axis = .vertical
        detailStack.spacing = 2

        container.axis = .vertical
        container.spacing = 6
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(subtitleLabel)
        container.addArrangedSubview(detailStack)
        contentView.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        detailStack.arrangedSubviews.forEach {
            detailStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    func configure(with item: TodayDisplayModel.Item) {
        // Server content — a game title or an article headline — is shown
        // exactly as received.
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
        subtitleLabel.isHidden = (item.subtitle ?? "").isEmpty

        for detail in item.details {
            let label = UILabel()
            label.font = .preferredFont(forTextStyle: .footnote)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .gpTextSecondary
            label.numberOfLines = 0
            label.text = detail
            detailStack.addArrangedSubview(label)
        }
        detailStack.isHidden = item.details.isEmpty

        accessibilityLabel = item.accessibilityLabel
        accessibilityTraits = item.action == nil ? .staticText : .button
    }
}

// MARK: - TodayStatusCell
//
// What a section shows when it has no items: an explanation, and a retry only
// when retrying can actually help.
//
// A `disabled` section never gets a button. A kill switch cannot be retried,
// and a button that always fails is worse than no button at all.

final class TodayStatusCell: UICollectionViewCell {

    static let reuseId = "TodayStatusCell"

    /// Minimum 44pt tall and full width, per the touch-target rule.
    private static let minimumTouchTarget: CGFloat = 44

    private let messageLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private var onRetry: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    private func setup() {
        contentView.backgroundColor = .gpSurface
        contentView.layer.cornerRadius = 14
        contentView.layer.masksToBounds = true

        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .gpTextSecondary
        messageLabel.numberOfLines = 0

        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        retryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        retryButton.setTitleColor(.gpPrimary, for: .normal)
        retryButton.contentHorizontalAlignment = .leading
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [messageLabel, retryButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.minimumTouchTarget)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onRetry = nil
    }

    /// - Parameter retryTitle: nil for a disabled section, which must not be
    ///   offered a retry.
    func configure(message: String, retryTitle: String?, onRetry: (() -> Void)?) {
        messageLabel.text = message
        self.onRetry = onRetry

        if let retryTitle, onRetry != nil {
            retryButton.setTitle(retryTitle, for: .normal)
            retryButton.isHidden = false
            retryButton.accessibilityLabel = retryTitle
        } else {
            retryButton.isHidden = true
        }

        messageLabel.accessibilityLabel = message
    }

    @objc private func retryTapped() {
        onRetry?()
    }
}

// MARK: - TodayNoticeCell
//
// A quiet strip above the feed for "this is from a moment ago" and "some
// sections didn't load". Neither is an error, and neither is styled as one.

final class TodayNoticeCell: UICollectionViewCell {

    static let reuseId = "TodayNoticeCell"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    private func setup() {
        contentView.backgroundColor = .gpSecondaryBackground
        contentView.layer.cornerRadius = 10
        contentView.layer.masksToBounds = true

        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])

        isAccessibilityElement = true
    }

    func configure(message: String) {
        label.text = message
        accessibilityLabel = message
    }
}
