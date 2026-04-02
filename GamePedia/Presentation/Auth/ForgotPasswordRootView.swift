import UIKit

final class ForgotPasswordRootView: UIView {

    let emailFieldView = AuthInputFieldView(
        title: L10n.tr("Localizable", "auth.field.email.title"),
        placeholder: L10n.tr("Localizable", "auth.field.emailRegistered.placeholder"),
        systemImageName: "envelope"
    )
    let sendButton = UIButton(type: .system)
    let resetPasswordButton = UIButton(type: .system)

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
        label.text = L10n.tr("Localizable", "auth.forgotPassword.title")
        label.textColor = .gpTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("Localizable", "auth.forgotPassword.subtitle")
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

        emailFieldView.textField.keyboardType = .emailAddress
        emailFieldView.textField.textContentType = .emailAddress

        [titleLabel, subtitleLabel, formCardView].forEach { contentView.addSubview($0) }

        let footerLabel = UILabel()
        footerLabel.text = L10n.tr("Localizable", "auth.forgotPassword.footer")
        footerLabel.font = .systemFont(ofSize: 12, weight: .medium)
        footerLabel.textColor = .gpTextSecondary

        let footerStack = UIStackView(arrangedSubviews: [footerLabel, resetPasswordButton])
        footerStack.axis = .horizontal
        footerStack.spacing = 6
        footerStack.alignment = .center
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(footerStack)

        let formStack = UIStackView(arrangedSubviews: [emailFieldView, sendButton])
        formStack.axis = .vertical
        formStack.spacing = 20
        formStack.translatesAutoresizingMaskIntoConstraints = false
        formCardView.addSubview(formStack)

        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: formCardView.topAnchor, constant: 20),
            formStack.leadingAnchor.constraint(equalTo: formCardView.leadingAnchor, constant: 20),
            formStack.trailingAnchor.constraint(equalTo: formCardView.trailingAnchor, constant: -20),
            formStack.bottomAnchor.constraint(equalTo: formCardView.bottomAnchor, constant: -20),
            sendButton.heightAnchor.constraint(equalToConstant: 52),

            footerStack.topAnchor.constraint(equalTo: formCardView.bottomAnchor, constant: 18),
            footerStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            footerStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
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
            formCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    private func configureControls() {
        sendButton.configuration = makePrimaryButton(title: L10n.tr("Localizable", "auth.forgotPassword.send"))
        resetPasswordButton.configuration = makeFooterButton(title: L10n.tr("Localizable", "auth.forgotPassword.manualReset"))
    }

    private func makePrimaryButton(title: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .gpOnPrimary
        configuration.cornerStyle = .capsule
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ])
        )
        return configuration
    }

    private func makeFooterButton(title: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.baseForegroundColor = .gpPrimary
        configuration.contentInsets = .zero
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
            ])
        )
        return configuration
    }

    private func applyDynamicLayerColors() {
        formCardView.layer.borderColor = UIColor.gpBorder.resolvedCGColor(with: traitCollection)
    }
}
