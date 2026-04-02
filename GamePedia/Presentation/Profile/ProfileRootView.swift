import UIKit

// MARK: - ProfileRootView

final class ProfileRootView: UIView {

    // MARK: Subviews

    // User info
    let avatarView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 32
        iv.backgroundColor = .gpSurfaceElevated
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .gpTextPrimary
        return label
    }()

    let handleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        return label
    }()

    let badgeView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpPrimary
        view.layer.cornerRadius = 10
        view.isHidden = true
        return view
    }()

    let badgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .gpOnPrimary
        return label
    }()

    // Stats
    let statsContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    let accountActionContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let supportActionContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let logoutButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: "로그아웃",
            systemImageName: "rectangle.portrait.and.arrow.right",
            tintColor: .gpTextPrimary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }()

    let deleteAccountButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: "회원 탈퇴",
            systemImageName: "person.crop.circle.badge.minus",
            tintColor: .gpCoral
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }()

    private let accountActionDivider: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSeparator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let termsOfServiceButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: "이용약관",
            systemImageName: "doc.text",
            tintColor: .gpTextPrimary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }()

    let privacyPolicyButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: "개인정보처리방침",
            systemImageName: "lock.shield",
            tintColor: .gpTextPrimary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }()

    let communityGuidelinesButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: "커뮤니티 가이드라인",
            systemImageName: "person.2.wave.2",
            tintColor: .gpTextPrimary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }()

    let contactSupportButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: "문의하기",
            systemImageName: "envelope",
            tintColor: .gpPrimary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }()

    private let supportActionDividerTop: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSeparator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let supportActionDividerMiddle: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSeparator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let supportActionDividerBottom: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSeparator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let playedStatView   = ProfileStatView()
    let reviewStatView   = ProfileStatView()
    let wishlistStatView = ProfileStatView()

    // Recent play
    let sectionHeader = SectionHeaderView()

    let tableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.rowHeight = RecentPlayCell.height
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: Setup
    private func setup() {
        backgroundColor = .gpBackground
        tableView.register(RecentPlayCell.self, forCellReuseIdentifier: RecentPlayCell.reuseId)

        // Badge
        badgeView.addSubview(badgeLabel)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badgeLabel.topAnchor.constraint(equalTo: badgeView.topAnchor, constant: 3),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeView.bottomAnchor, constant: -3),
            badgeLabel.leadingAnchor.constraint(equalTo: badgeView.leadingAnchor, constant: 10),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeView.trailingAnchor, constant: -10)
        ])

        // User info card
        let nameStack = UIStackView(arrangedSubviews: [nameLabel, handleLabel, badgeView])
        nameStack.axis = .vertical
        nameStack.spacing = 4
        nameStack.alignment = .leading

        let userRow = UIStackView(arrangedSubviews: [avatarView, nameStack])
        userRow.axis = .horizontal
        userRow.spacing = 16
        userRow.alignment = .center
        userRow.backgroundColor = .gpCardBackground
        userRow.layer.cornerRadius = 20
        userRow.clipsToBounds = true
        userRow.isLayoutMarginsRelativeArrangement = true
        userRow.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        userRow.translatesAutoresizingMaskIntoConstraints = false

        // Stat cards — distinct accent colors per slot
        playedStatView.setValueColor(.gpTeal)
        reviewStatView.setValueColor(.gpPrimary)
        wishlistStatView.setValueColor(.gpRed)

        [playedStatView, reviewStatView, wishlistStatView].forEach {
            $0.backgroundColor = .gpCardBackground
            $0.layer.cornerRadius = 16
            $0.clipsToBounds = true
            $0.isUserInteractionEnabled = true
        }

        let statsStack = UIStackView(arrangedSubviews: [playedStatView, reviewStatView, wishlistStatView])
        statsStack.axis = .horizontal
        statsStack.distribution = .fillEqually
        statsStack.spacing = 12
        statsStack.translatesAutoresizingMaskIntoConstraints = false

        statsContainerView.addSubview(statsStack)
        statsContainerView.translatesAutoresizingMaskIntoConstraints = false

        // Section header
        sectionHeader.configure(title: "최근 플레이")
        sectionHeader.titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        sectionHeader.translatesAutoresizingMaskIntoConstraints = false

        accountActionContainerView.addSubview(logoutButton)
        accountActionContainerView.addSubview(accountActionDivider)
        accountActionContainerView.addSubview(deleteAccountButton)

        supportActionContainerView.addSubview(termsOfServiceButton)
        supportActionContainerView.addSubview(supportActionDividerTop)
        supportActionContainerView.addSubview(privacyPolicyButton)
        supportActionContainerView.addSubview(supportActionDividerMiddle)
        supportActionContainerView.addSubview(communityGuidelinesButton)
        supportActionContainerView.addSubview(supportActionDividerBottom)
        supportActionContainerView.addSubview(contactSupportButton)

        [userRow, statsContainerView, accountActionContainerView, supportActionContainerView, sectionHeader, tableView].forEach {
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: 64),
            avatarView.heightAnchor.constraint(equalToConstant: 64),

            userRow.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 20),
            userRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            userRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            statsStack.topAnchor.constraint(equalTo: statsContainerView.topAnchor),
            statsStack.bottomAnchor.constraint(equalTo: statsContainerView.bottomAnchor),
            statsStack.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor),
            statsStack.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor),

            statsContainerView.topAnchor.constraint(equalTo: userRow.bottomAnchor, constant: 24),
            statsContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            statsContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            accountActionContainerView.topAnchor.constraint(equalTo: statsContainerView.bottomAnchor, constant: 20),
            accountActionContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            accountActionContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            logoutButton.topAnchor.constraint(equalTo: accountActionContainerView.topAnchor),
            logoutButton.leadingAnchor.constraint(equalTo: accountActionContainerView.leadingAnchor),
            logoutButton.trailingAnchor.constraint(equalTo: accountActionContainerView.trailingAnchor),
            logoutButton.heightAnchor.constraint(equalToConstant: 52),

            accountActionDivider.topAnchor.constraint(equalTo: logoutButton.bottomAnchor),
            accountActionDivider.leadingAnchor.constraint(equalTo: accountActionContainerView.leadingAnchor, constant: 16),
            accountActionDivider.trailingAnchor.constraint(equalTo: accountActionContainerView.trailingAnchor, constant: -16),
            accountActionDivider.heightAnchor.constraint(equalToConstant: 1),

            deleteAccountButton.topAnchor.constraint(equalTo: accountActionDivider.bottomAnchor),
            deleteAccountButton.leadingAnchor.constraint(equalTo: accountActionContainerView.leadingAnchor),
            deleteAccountButton.trailingAnchor.constraint(equalTo: accountActionContainerView.trailingAnchor),
            deleteAccountButton.heightAnchor.constraint(equalToConstant: 52),
            deleteAccountButton.bottomAnchor.constraint(equalTo: accountActionContainerView.bottomAnchor),

            supportActionContainerView.topAnchor.constraint(equalTo: accountActionContainerView.bottomAnchor, constant: 20),
            supportActionContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            supportActionContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            termsOfServiceButton.topAnchor.constraint(equalTo: supportActionContainerView.topAnchor),
            termsOfServiceButton.leadingAnchor.constraint(equalTo: supportActionContainerView.leadingAnchor),
            termsOfServiceButton.trailingAnchor.constraint(equalTo: supportActionContainerView.trailingAnchor),
            termsOfServiceButton.heightAnchor.constraint(equalToConstant: 52),

            supportActionDividerTop.topAnchor.constraint(equalTo: termsOfServiceButton.bottomAnchor),
            supportActionDividerTop.leadingAnchor.constraint(equalTo: supportActionContainerView.leadingAnchor, constant: 16),
            supportActionDividerTop.trailingAnchor.constraint(equalTo: supportActionContainerView.trailingAnchor, constant: -16),
            supportActionDividerTop.heightAnchor.constraint(equalToConstant: 1),

            privacyPolicyButton.topAnchor.constraint(equalTo: supportActionDividerTop.bottomAnchor),
            privacyPolicyButton.leadingAnchor.constraint(equalTo: supportActionContainerView.leadingAnchor),
            privacyPolicyButton.trailingAnchor.constraint(equalTo: supportActionContainerView.trailingAnchor),
            privacyPolicyButton.heightAnchor.constraint(equalToConstant: 52),

            supportActionDividerMiddle.topAnchor.constraint(equalTo: privacyPolicyButton.bottomAnchor),
            supportActionDividerMiddle.leadingAnchor.constraint(equalTo: supportActionContainerView.leadingAnchor, constant: 16),
            supportActionDividerMiddle.trailingAnchor.constraint(equalTo: supportActionContainerView.trailingAnchor, constant: -16),
            supportActionDividerMiddle.heightAnchor.constraint(equalToConstant: 1),

            communityGuidelinesButton.topAnchor.constraint(equalTo: supportActionDividerMiddle.bottomAnchor),
            communityGuidelinesButton.leadingAnchor.constraint(equalTo: supportActionContainerView.leadingAnchor),
            communityGuidelinesButton.trailingAnchor.constraint(equalTo: supportActionContainerView.trailingAnchor),
            communityGuidelinesButton.heightAnchor.constraint(equalToConstant: 52),

            supportActionDividerBottom.topAnchor.constraint(equalTo: communityGuidelinesButton.bottomAnchor),
            supportActionDividerBottom.leadingAnchor.constraint(equalTo: supportActionContainerView.leadingAnchor, constant: 16),
            supportActionDividerBottom.trailingAnchor.constraint(equalTo: supportActionContainerView.trailingAnchor, constant: -16),
            supportActionDividerBottom.heightAnchor.constraint(equalToConstant: 1),

            contactSupportButton.topAnchor.constraint(equalTo: supportActionDividerBottom.bottomAnchor),
            contactSupportButton.leadingAnchor.constraint(equalTo: supportActionContainerView.leadingAnchor),
            contactSupportButton.trailingAnchor.constraint(equalTo: supportActionContainerView.trailingAnchor),
            contactSupportButton.heightAnchor.constraint(equalToConstant: 52),
            contactSupportButton.bottomAnchor.constraint(equalTo: supportActionContainerView.bottomAnchor),

            sectionHeader.topAnchor.constraint(equalTo: supportActionContainerView.bottomAnchor, constant: 24),
            sectionHeader.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            sectionHeader.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            sectionHeader.heightAnchor.constraint(equalToConstant: 44),

            tableView.topAnchor.constraint(equalTo: sectionHeader.bottomAnchor, constant: 14),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - State Rendering

    func render(_ state: ProfileState) {
        let placeholderImage = UIImage(systemName: "person.fill")
        avatarView.tintColor = .gpTextTertiary
        avatarView.contentMode = state.profileImageURL == nil ? .center : .scaleAspectFill
        avatarView.loadImage(url: state.profileImageURL, placeholder: placeholderImage)
        nameLabel.text = state.displayName ?? "GamePedia"
        handleLabel.text = state.displayEmail ?? ""

        if let badge = state.badgeTitle {
            badgeLabel.text = badge
            badgeView.isHidden = false
        } else {
            badgeView.isHidden = true
        }

        playedStatView.configure(value: "\(state.playedGameCount)", label: "플레이한 게임")
        reviewStatView.configure(value: "\(state.writtenReviewCount)", label: "작성한 리뷰")
        wishlistStatView.configure(value: "\(state.wishlistCount)", label: "찜한 게임")

        updateAccountActionButtons(with: state)
    }

    private func updateAccountActionButtons(with state: ProfileState) {
        logoutButton.isEnabled = !state.isAccountActionInProgress
        deleteAccountButton.isEnabled = !state.isAccountActionInProgress
        logoutButton.alpha = logoutButton.isEnabled ? 1.0 : 0.7
        deleteAccountButton.alpha = deleteAccountButton.isEnabled ? 1.0 : 0.7

        var logoutConfiguration = logoutButton.configuration
        logoutConfiguration?.showsActivityIndicator = state.isLoggingOut
        logoutConfiguration?.image = state.isLoggingOut ? nil : UIImage(systemName: "rectangle.portrait.and.arrow.right")
        logoutButton.configuration = logoutConfiguration

        var deleteConfiguration = deleteAccountButton.configuration
        deleteConfiguration?.showsActivityIndicator = state.isDeletingAccount
        deleteConfiguration?.image = state.isDeletingAccount ? nil : UIImage(systemName: "person.crop.circle.badge.minus")
        deleteAccountButton.configuration = deleteConfiguration
    }

    private static func makeAccountActionConfiguration(
        title: String,
        systemImageName: String,
        tintColor: UIColor
    ) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = UIImage(systemName: systemImageName)
        configuration.imagePadding = 10
        configuration.baseForegroundColor = tintColor
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        return configuration
    }
}

// MARK: - ProfileStatView

final class ProfileStatView: UIView {

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.textColor = .gpPrimary
        return label
    }()

    private let captionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .gpTextSecondary
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 8, bottom: 16, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    func configure(value: String, label: String) {
        valueLabel.text = value
        captionLabel.text = label
    }

    func setValueColor(_ color: UIColor) {
        valueLabel.textColor = color
    }
}
