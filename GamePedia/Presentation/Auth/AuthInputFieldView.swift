import UIKit

final class AuthInputFieldView: UIView {

    enum ValidationState {
        case hidden
        case error(String)
    }

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let textField: UITextField = {
        let textField = UITextField()
        textField.font = .systemFont(ofSize: 15)
        textField.textColor = .gpTextPrimary
        textField.tintColor = .gpPrimary
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.keyboardAppearance = .default
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .gpRed
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpInputBackground
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .gpTextTertiary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let trailingImageView: UIImageView?
    private var validationState: ValidationState = .hidden

    init(
        title: String,
        placeholder: String,
        systemImageName: String,
        isSecureTextEntry: Bool = false,
        trailingSystemImageName: String? = nil
    ) {
        self.trailingImageView = trailingSystemImageName.map {
            let imageView = UIImageView(
                image: UIImage(
                    systemName: $0,
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
                )
            )
            imageView.tintColor = .gpTextTertiary
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            return imageView
        }

        super.init(frame: .zero)

        titleLabel.text = title
        iconImageView.image = UIImage(
            systemName: systemImageName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        )
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor.gpTextTertiary
            ]
        )
        textField.isSecureTextEntry = isSecureTextEntry

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValidationState(_ validationState: ValidationState) {
        self.validationState = validationState
        applyDynamicLayerColors()

        switch validationState {
        case .hidden:
            statusLabel.text = nil
            statusLabel.isHidden = true
        case .error(let message):
            statusLabel.text = message
            statusLabel.isHidden = false
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        applyDynamicLayerColors()
    }

    private func setupLayout() {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, containerView, statusLabel])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(textField)

        if let trailingImageView {
            containerView.addSubview(trailingImageView)
        }

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),

            containerView.heightAnchor.constraint(equalToConstant: 48),

            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),

            textField.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10),
            textField.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 22)
        ])

        if let trailingImageView {
            NSLayoutConstraint.activate([
                trailingImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),
                trailingImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                trailingImageView.widthAnchor.constraint(equalToConstant: 18),
                trailingImageView.heightAnchor.constraint(equalToConstant: 18),
                textField.trailingAnchor.constraint(equalTo: trailingImageView.leadingAnchor, constant: -10)
            ])
        } else {
            NSLayoutConstraint.activate([
                textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14)
            ])
        }

        applyDynamicLayerColors()
    }

    private func applyDynamicLayerColors() {
        switch validationState {
        case .hidden:
            containerView.layer.borderColor = UIColor.gpBorder.resolvedCGColor(with: traitCollection)
        case .error:
            containerView.layer.borderColor = UIColor.gpRed.resolvedCGColor(with: traitCollection)
        }
    }
}
