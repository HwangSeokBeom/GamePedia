import UIKit

// MARK: - EmptyStateView

final class EmptyStateView: UIView {

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = .gpTextTertiary
        iv.contentMode = .scaleAspectFit
        iv.widthAnchor.constraint(equalToConstant: 48).isActive = true
        iv.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return iv
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .gpTextSecondary
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let stack = UIStackView(arrangedSubviews: [iconImageView, messageLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(icon: String, message: String) {
        configure(icon: icon, message: Optional(message))
    }

    func configure(icon: String, message: String?) {
        let normalizedMessage = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        iconImageView.image = UIImage(systemName: icon)
        messageLabel.text = normalizedMessage
        isHidden = normalizedMessage?.isEmpty != false
    }
}
