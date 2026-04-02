import UIKit

final class ProfileSettingsViewController: UIViewController {

    var onShowSocialPrivacySettings: (() -> Void)?
    var onLogoutConfirmed: (() -> Void)?
    var onDeleteAccountConfirmed: (() -> Void)?
    var onShowTermsOfService: (() -> Void)?
    var onShowPrivacyPolicy: (() -> Void)?
    var onShowCommunityGuidelines: (() -> Void)?
    var onContactSupport: (() -> Void)?
    var onShowNotificationSettings: (() -> Void)?

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 28
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let accountHeaderView = SectionHeaderView()
    private let serviceHeaderView = SectionHeaderView()
    private let supportHeaderView = SectionHeaderView()

    private let accountContainerView = ProfileSettingsViewController.makeSectionContainerView()
    private let serviceContainerView = ProfileSettingsViewController.makeSectionContainerView()
    private let supportContainerView = ProfileSettingsViewController.makeSectionContainerView()

    private let privacySettingsButton = ProfileSettingsViewController.makeActionButton(
        title: "공개 설정",
        systemImageName: "switch.2",
        tintColor: .gpTextPrimary
    )
    private let notificationSettingsButton = ProfileSettingsViewController.makeActionButton(
        title: "알림 설정",
        systemImageName: "bell.badge",
        tintColor: .gpTextPrimary
    )
    private let logoutButton = ProfileSettingsViewController.makeActionButton(
        title: "로그아웃",
        systemImageName: "rectangle.portrait.and.arrow.right",
        tintColor: .gpTextPrimary
    )
    private let deleteAccountButton = ProfileSettingsViewController.makeActionButton(
        title: "회원 탈퇴",
        systemImageName: "person.crop.circle.badge.minus",
        tintColor: .gpCoral
    )
    private let termsButton = ProfileSettingsViewController.makeActionButton(
        title: "이용약관",
        systemImageName: "doc.text",
        tintColor: .gpTextPrimary
    )
    private let privacyPolicyButton = ProfileSettingsViewController.makeActionButton(
        title: "개인정보처리방침",
        systemImageName: "lock.shield",
        tintColor: .gpTextPrimary
    )
    private let communityGuidelinesButton = ProfileSettingsViewController.makeActionButton(
        title: "커뮤니티 가이드라인",
        systemImageName: "person.2.wave.2",
        tintColor: .gpTextPrimary
    )
    private let contactSupportButton = ProfileSettingsViewController.makeActionButton(
        title: "문의하기",
        systemImageName: "envelope",
        tintColor: .gpPrimary
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupLayout()
        setupActions()
    }

    private func setupView() {
        view.backgroundColor = .gpBackground
        navigationItem.title = "설정"
        navigationItem.largeTitleDisplayMode = .never

        [accountHeaderView, serviceHeaderView, supportHeaderView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        accountHeaderView.configure(title: "계정", showSeeMore: false)
        serviceHeaderView.configure(title: "서비스", showSeeMore: false)
        supportHeaderView.configure(title: "지원", showSeeMore: false)

        [scrollView].forEach { view.addSubview($0) }
        [contentView].forEach { scrollView.addSubview($0) }
        [contentStackView].forEach { contentView.addSubview($0) }

        [accountHeaderView, accountContainerView, serviceHeaderView, serviceContainerView, supportHeaderView, supportContainerView].forEach {
            contentStackView.addArrangedSubview($0)
        }

        configureSection(
            containerView: accountContainerView,
            buttons: [privacySettingsButton, notificationSettingsButton, logoutButton, deleteAccountButton]
        )
        configureSection(
            containerView: serviceContainerView,
            buttons: [termsButton, privacyPolicyButton, communityGuidelinesButton]
        )
        configureSection(
            containerView: supportContainerView,
            buttons: [contactSupportButton]
        )
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
    }

    private func setupActions() {
        privacySettingsButton.addTarget(self, action: #selector(didTapPrivacySettings), for: .touchUpInside)
        notificationSettingsButton.addTarget(self, action: #selector(didTapNotificationSettings), for: .touchUpInside)
        logoutButton.addTarget(self, action: #selector(didTapLogout), for: .touchUpInside)
        deleteAccountButton.addTarget(self, action: #selector(didTapDeleteAccount), for: .touchUpInside)
        termsButton.addTarget(self, action: #selector(didTapTermsOfService), for: .touchUpInside)
        privacyPolicyButton.addTarget(self, action: #selector(didTapPrivacyPolicy), for: .touchUpInside)
        communityGuidelinesButton.addTarget(self, action: #selector(didTapCommunityGuidelines), for: .touchUpInside)
        contactSupportButton.addTarget(self, action: #selector(didTapContactSupport), for: .touchUpInside)
    }

    private func configureSection(containerView: UIView, buttons: [UIButton]) {
        var previousButton: UIButton?

        buttons.enumerated().forEach { index, button in
            containerView.addSubview(button)

            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                button.heightAnchor.constraint(equalToConstant: 54)
            ])

            if let previousButton {
                let divider = ProfileSettingsViewController.makeDividerView()
                containerView.addSubview(divider)

                NSLayoutConstraint.activate([
                    divider.topAnchor.constraint(equalTo: previousButton.bottomAnchor),
                    divider.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                    divider.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                    divider.heightAnchor.constraint(equalToConstant: 1),

                    button.topAnchor.constraint(equalTo: divider.bottomAnchor)
                ])
            } else {
                button.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
            }

            if index == buttons.count - 1 {
                button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
            }

            previousButton = button
        }
    }

    @objc
    private func didTapPrivacySettings() {
        onShowSocialPrivacySettings?()
    }

    @objc
    private func didTapNotificationSettings() {
        onShowNotificationSettings?()
    }

    @objc
    private func didTapLogout() {
        let alertController = UIAlertController(
            title: "로그아웃",
            message: "현재 기기에서 로그인 상태가 해제됩니다.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        alertController.addAction(
            UIAlertAction(title: "로그아웃", style: .destructive) { [weak self] _ in
                self?.onLogoutConfirmed?()
            }
        )
        present(alertController, animated: true)
    }

    @objc
    private func didTapDeleteAccount() {
        let alertController = UIAlertController(
            title: "회원 탈퇴",
            message: "회원 탈퇴 시 계정과 프로필 정보가 삭제되며 복구할 수 없습니다. 법령상 보관이 필요한 정보는 관련 법령에 따라 별도 보관될 수 있습니다.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        alertController.addAction(
            UIAlertAction(title: "회원 탈퇴", style: .destructive) { [weak self] _ in
                self?.onDeleteAccountConfirmed?()
            }
        )
        present(alertController, animated: true)
    }

    @objc
    private func didTapTermsOfService() {
        onShowTermsOfService?()
    }

    @objc
    private func didTapPrivacyPolicy() {
        onShowPrivacyPolicy?()
    }

    @objc
    private func didTapCommunityGuidelines() {
        onShowCommunityGuidelines?()
    }

    @objc
    private func didTapContactSupport() {
        onContactSupport?()
    }

    private static func makeSectionContainerView() -> UIView {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    private static func makeDividerView() -> UIView {
        let view = UIView()
        view.backgroundColor = .gpSeparator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    private static func makeActionButton(
        title: String,
        systemImageName: String,
        tintColor: UIColor
    ) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = UIImage(systemName: systemImageName)
        configuration.imagePadding = 10
        configuration.baseForegroundColor = tintColor
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
}
