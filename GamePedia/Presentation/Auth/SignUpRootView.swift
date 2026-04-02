import UIKit

final class SignUpRootView: UIView {

    let backButton = UIButton(type: .system)
    let emailFieldView = AuthInputFieldView(
        title: L10n.tr("Localizable", "auth.field.email.title"),
        placeholder: L10n.tr("Localizable", "auth.field.email.placeholder"),
        systemImageName: "envelope"
    )
    let nicknameFieldView = AuthInputFieldView(
        title: L10n.tr("Localizable", "auth.field.nickname.title"),
        placeholder: L10n.tr("Localizable", "auth.field.nickname.placeholder"),
        systemImageName: "person"
    )
    let passwordFieldView = AuthInputFieldView(
        title: L10n.tr("Localizable", "auth.field.password.title"),
        placeholder: L10n.tr("Localizable", "auth.field.password.placeholder"),
        systemImageName: "lock",
        isSecureTextEntry: true
    )
    let confirmPasswordFieldView = AuthInputFieldView(
        title: L10n.tr("Localizable", "auth.field.passwordConfirm.title"),
        placeholder: L10n.tr("Localizable", "auth.field.passwordConfirm.placeholder"),
        systemImageName: "lock.shield",
        isSecureTextEntry: true
    )
    let signUpButton = UIButton(type: .system)
    let loginButton = UIButton(type: .system)

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

    private let rightSpacerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let headerTitleLabel: UILabel = {
        let label = UILabel()
        let baseDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
        let descriptor = baseDescriptor.withDesign(.serif) ?? baseDescriptor
        label.font = UIFont(descriptor: descriptor, size: 20)
        label.text = L10n.tr("Localizable", "auth.signup.title")
        label.textColor = .gpTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let brandIconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "logoIcon")?.withRenderingMode(.alwaysOriginal))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let brandLabel: UILabel = {
        let label = UILabel()
        let baseDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .title2)
        let descriptor = baseDescriptor.withDesign(.serif) ?? baseDescriptor
        label.font = UIFont(descriptor: descriptor, size: 28)
        label.text = "GamePedia"
        label.textColor = .gpTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("Localizable", "auth.signup.subtitle")
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextSecondary
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

    private lazy var headerStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [backButton, headerTitleLabel, rightSpacerView])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var brandRowStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [brandIconView, brandLabel])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private var headerTopConstraint: NSLayoutConstraint!
    private var headerHeightConstraint: NSLayoutConstraint!
    private var brandRowTopToHeaderConstraint: NSLayoutConstraint!
    private var brandRowTopToContentConstraint: NSLayoutConstraint!

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

    func setUsesSystemNavigationBar(_ usesSystemNavigationBar: Bool) {
        headerStackView.isHidden = usesSystemNavigationBar
        headerTopConstraint.isActive = !usesSystemNavigationBar
        headerHeightConstraint.isActive = !usesSystemNavigationBar
        brandRowTopToHeaderConstraint.isActive = !usesSystemNavigationBar
        brandRowTopToContentConstraint.isActive = usesSystemNavigationBar
    }

    private func setupView() {
        backgroundColor = .gpBackground

        addSubview(scrollView)
        scrollView.addSubview(contentView)

        emailFieldView.textField.keyboardType = .emailAddress
        emailFieldView.textField.textContentType = .emailAddress
        nicknameFieldView.textField.textContentType = .nickname
        passwordFieldView.textField.textContentType = .newPassword
        confirmPasswordFieldView.textField.textContentType = .newPassword

        contentView.addSubview(headerStackView)
        contentView.addSubview(brandRowStackView)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(formCardView)

        let formStack = UIStackView(arrangedSubviews: [
            emailFieldView,
            nicknameFieldView,
            passwordFieldView,
            confirmPasswordFieldView,
            signUpButton
        ])
        formStack.axis = .vertical
        formStack.spacing = 16
        formStack.translatesAutoresizingMaskIntoConstraints = false
        formStack.setCustomSpacing(20, after: confirmPasswordFieldView)
        formCardView.addSubview(formStack)

        let footerLabel = UILabel()
        footerLabel.text = L10n.tr("Localizable", "auth.signup.footer")
        footerLabel.font = .systemFont(ofSize: 12, weight: .medium)
        footerLabel.textColor = .gpTextSecondary

        let footerStack = UIStackView(arrangedSubviews: [footerLabel, loginButton])
        footerStack.axis = .horizontal
        footerStack.spacing = 6
        footerStack.alignment = .center
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(footerStack)

        headerTopConstraint = headerStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10)
        headerHeightConstraint = headerStackView.heightAnchor.constraint(equalToConstant: 44)
        brandRowTopToHeaderConstraint = brandRowStackView.topAnchor.constraint(equalTo: headerStackView.bottomAnchor, constant: 18)
        brandRowTopToContentConstraint = brandRowStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18)

        NSLayoutConstraint.activate([
            rightSpacerView.widthAnchor.constraint(equalTo: backButton.widthAnchor),

            formStack.topAnchor.constraint(equalTo: formCardView.topAnchor, constant: 20),
            formStack.leadingAnchor.constraint(equalTo: formCardView.leadingAnchor, constant: 20),
            formStack.trailingAnchor.constraint(equalTo: formCardView.trailingAnchor, constant: -20),
            formStack.bottomAnchor.constraint(equalTo: formCardView.bottomAnchor, constant: -20),
            signUpButton.heightAnchor.constraint(equalToConstant: 52),

            headerTopConstraint,
            headerStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            headerHeightConstraint,

            brandRowTopToHeaderConstraint,
            brandRowStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: brandRowStackView.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            formCardView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 26),
            formCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            formCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

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

            brandIconView.widthAnchor.constraint(equalToConstant: 18),
            brandIconView.heightAnchor.constraint(equalToConstant: 13)
        ])
    }

    private func configureControls() {
        var backConfiguration = UIButton.Configuration.plain()
        backConfiguration.title = L10n.tr("Localizable", "common.button.back")
        backConfiguration.image = UIImage(
            systemName: "chevron.backward",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        )
        backConfiguration.imagePadding = 6
        backConfiguration.baseForegroundColor = .gpTextPrimary
        backConfiguration.contentInsets = .zero
        backConfiguration.attributedTitle = AttributedString(
            L10n.tr("Localizable", "common.button.back"),
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 14, weight: .medium)
            ])
        )
        backButton.configuration = backConfiguration

        var signUpConfiguration = UIButton.Configuration.filled()
        signUpConfiguration.title = L10n.tr("Localizable", "auth.signup.button")
        signUpConfiguration.image = UIImage(
            systemName: "person.badge.plus",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        )
        signUpConfiguration.imagePadding = 6
        signUpConfiguration.baseBackgroundColor = .gpPrimary
        signUpConfiguration.baseForegroundColor = .gpOnPrimary
        signUpConfiguration.cornerStyle = .capsule
        signUpConfiguration.attributedTitle = AttributedString(
            L10n.tr("Localizable", "auth.signup.button"),
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ])
        )
        signUpButton.configuration = signUpConfiguration

        var loginConfiguration = UIButton.Configuration.plain()
        loginConfiguration.title = L10n.tr("Localizable", "auth.signup.login")
        loginConfiguration.baseForegroundColor = .gpPrimary
        loginConfiguration.contentInsets = .zero
        loginConfiguration.attributedTitle = AttributedString(
            L10n.tr("Localizable", "auth.signup.login"),
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
            ])
        )
        loginButton.configuration = loginConfiguration
    }

    private func applyDynamicLayerColors() {
        formCardView.layer.borderColor = UIColor.gpBorder.resolvedCGColor(with: traitCollection)
    }
}
