import UIKit

final class AISearchAssistChipView: UIButton {
    private enum Layout {
        static let height: CGFloat = 30
    }

    init(title: String, style: Style = .plain) {
        super.init(frame: .zero)
        setup(title: title, style: style)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup(title: "", style: .plain)
    }

    private func setup(title: String, style: Style) {
        setTitle(title, for: .normal)
        titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel?.numberOfLines = 1
        titleLabel?.lineBreakMode = .byTruncatingTail
        layer.cornerRadius = Layout.height / 2
        clipsToBounds = true
        contentEdgeInsets = UIEdgeInsets(top: 7, left: 12, bottom: 7, right: 12)
        translatesAutoresizingMaskIntoConstraints = false

        switch style {
        case .plain:
            backgroundColor = .gpSurface
            setTitleColor(.gpTextSecondary, for: .normal)
        case .suggested:
            backgroundColor = .gpPrimary.withAlphaComponent(0.16)
            setTitleColor(.gpPrimaryLight, for: .normal)
        }

        heightAnchor.constraint(equalToConstant: Layout.height).isActive = true
        widthAnchor.constraint(lessThanOrEqualToConstant: 180).isActive = true
        accessibilityLabel = title
    }
}

extension AISearchAssistChipView {
    enum Style {
        case plain
        case suggested
    }
}
