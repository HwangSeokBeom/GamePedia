import UIKit

final class LoginRootView: UIView {

    let emailFieldView = AuthInputFieldView(
        title: "이메일",
        placeholder: "이메일 입력",
        systemImageName: "envelope"
    )

    let passwordFieldView = AuthInputFieldView(
        title: "비밀번호",
        placeholder: "비밀번호 입력",
        systemImageName: "lock",
        isSecureTextEntry: true,
        trailingSystemImageName: "eye.slash"
    )

    let loginButton = UIButton(type: .system)
    let appleButton = UIButton(type: .system)
    let googleButton = UIButton(type: .system)
    let signUpButton = UIButton(type: .system)
    let forgotPasswordButton = UIButton(type: .system)

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

    private let logoSectionView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let glowView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.14)
        view.layer.cornerRadius = 56
        view.layer.shadowColor = UIColor.gpPrimary.cgColor
        view.layer.shadowOpacity = 0.35
        view.layer.shadowRadius = 28
        view.layer.shadowOffset = .zero
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let logoCardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#16161A")
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.gpSeparator.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let logoImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "logoIcon")?.withRenderingMode(.alwaysOriginal))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        let baseDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .title2)
        let descriptor = baseDescriptor.withDesign(.serif) ?? baseDescriptor
        label.font = UIFont(descriptor: descriptor, size: 28)
        label.text = "로그인"
        label.textColor = .gpTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "게임 취향을 기록하고 추천을 받아보세요"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor(hex: "#6B6B70")
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let formCardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#16161A")
        view.layer.cornerRadius = 20
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.gpSeparator.cgColor
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

    private func setupView() {
        backgroundColor = UIColor(hex: "#0B0B0E")

        addSubview(scrollView)
        scrollView.addSubview(contentView)

        [logoSectionView, titleLabel, subtitleLabel, formCardView].forEach { contentView.addSubview($0) }
        logoSectionView.addSubview(glowView)
        logoSectionView.addSubview(logoCardView)
        logoCardView.addSubview(logoImageView)

        emailFieldView.textField.keyboardType = .emailAddress
        emailFieldView.textField.textContentType = .emailAddress
        passwordFieldView.textField.textContentType = .password

        let dividerLabel = makeDividerLabel()
        let dividerRow = UIStackView(arrangedSubviews: [makeDividerLine(), dividerLabel, makeDividerLine()])
        dividerRow.axis = .horizontal
        dividerRow.alignment = .center
        dividerRow.spacing = 12

        let socialStack = UIStackView(arrangedSubviews: [appleButton, googleButton])
        socialStack.axis = .horizontal
        socialStack.spacing = 10
        socialStack.distribution = .fillEqually

        let formStack = UIStackView(arrangedSubviews: [
            emailFieldView,
            passwordFieldView,
            loginButton,
            dividerRow,
            socialStack
        ])
        formStack.axis = .vertical
        formStack.spacing = 16
        formStack.translatesAutoresizingMaskIntoConstraints = false
        formStack.setCustomSpacing(20, after: passwordFieldView)
        formStack.setCustomSpacing(18, after: loginButton)
        formCardView.addSubview(formStack)

        let separatorLabel = UILabel()
        separatorLabel.text = "|"
        separatorLabel.font = .systemFont(ofSize: 12, weight: .medium)
        separatorLabel.textColor = .gpTextTertiary

        let footerStack = UIStackView(arrangedSubviews: [signUpButton, separatorLabel, forgotPasswordButton])
        footerStack.axis = .horizontal
        footerStack.spacing = 14
        footerStack.alignment = .center
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(footerStack)

        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: formCardView.topAnchor, constant: 20),
            formStack.leadingAnchor.constraint(equalTo: formCardView.leadingAnchor, constant: 20),
            formStack.trailingAnchor.constraint(equalTo: formCardView.trailingAnchor, constant: -20),
            formStack.bottomAnchor.constraint(equalTo: formCardView.bottomAnchor, constant: -16),

            loginButton.heightAnchor.constraint(equalToConstant: 52),
            appleButton.heightAnchor.constraint(equalToConstant: 44),
            googleButton.heightAnchor.constraint(equalToConstant: 44),

            footerStack.topAnchor.constraint(equalTo: formCardView.bottomAnchor, constant: 18),
            footerStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            footerStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -28)
        ])
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

            logoSectionView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 44),
            logoSectionView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoSectionView.widthAnchor.constraint(equalToConstant: 120),
            logoSectionView.heightAnchor.constraint(equalToConstant: 96),

            glowView.centerXAnchor.constraint(equalTo: logoCardView.centerXAnchor),
            glowView.centerYAnchor.constraint(equalTo: logoCardView.centerYAnchor),
            glowView.widthAnchor.constraint(equalToConstant: 112),
            glowView.heightAnchor.constraint(equalToConstant: 112),

            logoCardView.centerXAnchor.constraint(equalTo: logoSectionView.centerXAnchor),
            logoCardView.topAnchor.constraint(equalTo: logoSectionView.topAnchor, constant: 12),
            logoCardView.widthAnchor.constraint(equalToConstant: 72),
            logoCardView.heightAnchor.constraint(equalToConstant: 72),

            logoImageView.centerXAnchor.constraint(equalTo: logoCardView.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: logoCardView.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 30),
            logoImageView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.topAnchor.constraint(equalTo: logoSectionView.bottomAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            formCardView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            formCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            formCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    private func configureControls() {
        loginButton.configuration = makePrimaryButton(title: "로그인")
        appleButton.configuration = makeSecondaryButton(title: "Apple", systemImageName: "apple.logo")
        googleButton.configuration = makeSecondaryButton(title: "Google", systemImageName: "globe")

        signUpButton.configuration = makeFooterButton(title: "회원가입", tintColor: .gpPrimary)
        forgotPasswordButton.configuration = makeFooterButton(title: "비밀번호 찾기", tintColor: .gpTextSecondary)
    }

    private func makePrimaryButton(title: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .capsule
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ])
        )
        return configuration
    }

    private func makeSecondaryButton(title: String, systemImageName: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = UIImage(
            systemName: systemImageName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        )
        configuration.imagePadding = 8
        configuration.baseForegroundColor = .gpTextPrimary
        configuration.background.backgroundColor = .clear
        configuration.background.strokeColor = .gpSeparator
        configuration.background.strokeWidth = 1
        configuration.background.cornerRadius = 12
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 14, weight: .medium)
            ])
        )
        return configuration
    }

    private func makeFooterButton(title: String, tintColor: UIColor) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.baseForegroundColor = tintColor
        configuration.contentInsets = .zero
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 12, weight: .medium)
            ])
        )
        return configuration
    }

    private func makeDividerLine() -> UIView {
        let view = UIView()
        view.backgroundColor = .gpSeparator
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 1)
        ])
        return view
    }

    private func makeDividerLabel() -> UILabel {
        let label = UILabel()
        label.text = "또는"
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .gpTextTertiary
        return label
    }
}
