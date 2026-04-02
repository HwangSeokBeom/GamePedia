import UIKit

final class ResetPasswordRootView: UIView {

    let tokenFieldView = AuthInputFieldView(
        title: L10n.tr("Localizable", "auth.field.resetToken.title"),
        placeholder: L10n.tr("Localizable", "auth.field.resetToken.placeholder"),
        systemImageName: "key"
    )
    let passwordFieldView = AuthInputFieldView(
        title: L10n.tr("Localizable", "auth.field.newPassword.title"),
        placeholder: L10n.tr("Localizable", "auth.field.newPassword.placeholder"),
        systemImageName: "lock",
        isSecureTextEntry: true
    )
    let confirmPasswordFieldView = AuthInputFieldView(
        title: L10n.tr("Localizable", "auth.field.newPasswordConfirm.title"),
        placeholder: L10n.tr("Localizable", "auth.field.newPasswordConfirm.placeholder"),
        systemImageName: "lock.shield",
        isSecureTextEntry: true
    )
    let resetButton = UIButton(type: .system)

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        let baseDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .title2)
        let descriptor = baseDescriptor.withDesign(.serif) ?? baseDescriptor
        label.font = UIFont(descriptor: descriptor, size: 26)
        label.text = L10n.tr("Localizable", "auth.resetPassword.title")
        label.textColor = .gpTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("Localizable", "auth.resetPassword.subtitle")
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let formCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 20
        view.layer.borderWidth = 1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupLayout()
        configureControls()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupLayout()
        configureControls()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        applyDynamicLayerColors()
    }

    private func setupView() {
        backgroundColor = .gpBackground

        addSubview(scrollView)
        scrollView.addSubview(contentView)

        passwordFieldView.textField.textContentType = .newPassword
        confirmPasswordFieldView.textField.textContentType = .newPassword

        [titleLabel, subtitleLabel, formCardView].forEach { contentView.addSubview($0) }

        let formStack = UIStackView(
            arrangedSubviews: [
                tokenFieldView,
                passwordFieldView,
                confirmPasswordFieldView,
                resetButton
            ]
        )
        formStack.axis = .vertical
        formStack.spacing = 16
        formStack.translatesAutoresizingMaskIntoConstraints = false
        formStack.setCustomSpacing(20, after: confirmPasswordFieldView)
        formCardView.addSubview(formStack)

        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: formCardView.topAnchor, constant: 20),
            formStack.leadingAnchor.constraint(equalTo: formCardView.leadingAnchor, constant: 20),
            formStack.trailingAnchor.constraint(equalTo: formCardView.trailingAnchor, constant: -20),
            formStack.bottomAnchor.constraint(equalTo: formCardView.bottomAnchor, constant: -20),
            resetButton.heightAnchor.constraint(equalToConstant: 52)
        ])

        applyDynamicLayerColors()
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            formCardView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            formCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            formCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            formCardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
    }

    private func configureControls() {
        var configuration = UIButton.Configuration.filled()
        configuration.title = L10n.tr("Localizable", "auth.resetPassword.button")
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .gpOnPrimary
        configuration.cornerStyle = .capsule
        configuration.attributedTitle = AttributedString(
            L10n.tr("Localizable", "auth.resetPassword.button"),
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ])
        )
        resetButton.configuration = configuration
    }

    private func applyDynamicLayerColors() {
        formCardView.layer.borderColor = UIColor.gpBorder.resolvedCGColor(with: traitCollection)
    }
}
