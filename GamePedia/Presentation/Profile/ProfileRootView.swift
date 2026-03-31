import UIKit

// MARK: - ProfileRootView

final class ProfileRootView: UIView {

    // MARK: Subviews

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
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    let headerCardView: ProfileHeaderCardView = {
        let view = ProfileHeaderCardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // Stats
    let statsContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    let connectedAccountsSectionStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.isHidden = true
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    let connectedAccountsHeaderView: SectionHeaderView = {
        let view = SectionHeaderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let connectedAccountsContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let steamAccountIconContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.14)
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let steamAccountIconImageView: UIImageView = {
        let imageView = UIImageView(
            image: UIImage(
                systemName: "gamecontroller.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            )
        )
        imageView.tintColor = .gpPrimary
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let steamAccountTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.text = "Steam"
        return label
    }()

    private let steamAccountSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        return label
    }()

    private let steamConnectedBadgeView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.18)
        view.layer.cornerRadius = 10
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let steamConnectedBadgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .gpPrimaryLight
        label.text = "연결됨"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let steamUnlinkButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = "연동 해제"
        configuration.baseForegroundColor = .gpCoral
        configuration.contentInsets = .zero
        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let accountActionContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let friendSectionHeaderView: SectionHeaderView = {
        let view = SectionHeaderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let friendActionContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let friendsListButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: "친구 목록",
            systemImageName: "person.2",
            tintColor: .gpTextPrimary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }()

    let steamFriendsButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: "Steam 친구",
            systemImageName: "person.3",
            tintColor: .gpTextPrimary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }()

    let friendRequestsButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: "친구 요청",
            systemImageName: "person.crop.circle.badge.plus",
            tintColor: .gpTextPrimary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }()

    let friendSearchButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: "친구 찾기",
            systemImageName: "magnifyingglass",
            tintColor: .gpPrimary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }()

    let friendActivityButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: "친구 활동",
            systemImageName: "waveform.path.ecg",
            tintColor: .gpTextPrimary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }()

    private let friendActionDividerTop: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSeparator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let friendActionDividerBottom: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSeparator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let friendActionDividerThird: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSeparator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let friendActionDividerFourth: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSeparator
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

    let socialPrivacySettingsButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: "공개 설정",
            systemImageName: "switch.2",
            tintColor: .gpTextPrimary
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

    private let supportActionDividerFourth: UIView = {
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

    private let recentPlaySectionStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    let tableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.rowHeight = RecentPlayCell.height
        tv.isScrollEnabled = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private var recentPlayTableHeightConstraint: NSLayoutConstraint?

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
        statsContainerView.backgroundColor = .gpCardBackground
        statsContainerView.layer.cornerRadius = 20
        statsContainerView.layer.cornerCurve = .continuous
        statsContainerView.translatesAutoresizingMaskIntoConstraints = false

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

        // Section header
        sectionHeader.configure(title: "최근 플레이")
        sectionHeader.titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        sectionHeader.translatesAutoresizingMaskIntoConstraints = false

        connectedAccountsHeaderView.configure(title: "연결된 계정", showSeeMore: false)
        connectedAccountsHeaderView.titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        friendSectionHeaderView.configure(title: "친구", showSeeMore: false)
        friendSectionHeaderView.titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        accountActionContainerView.addSubview(logoutButton)
        accountActionContainerView.addSubview(accountActionDivider)
        accountActionContainerView.addSubview(deleteAccountButton)

        friendActionContainerView.addSubview(friendsListButton)
        friendActionContainerView.addSubview(friendActionDividerTop)
        friendActionContainerView.addSubview(steamFriendsButton)
        friendActionContainerView.addSubview(friendActionDividerFourth)
        friendActionContainerView.addSubview(friendRequestsButton)
        friendActionContainerView.addSubview(friendActionDividerBottom)
        friendActionContainerView.addSubview(friendSearchButton)
        friendActionContainerView.addSubview(friendActionDividerThird)
        friendActionContainerView.addSubview(friendActivityButton)

        supportActionContainerView.addSubview(termsOfServiceButton)
        supportActionContainerView.addSubview(supportActionDividerTop)
        supportActionContainerView.addSubview(socialPrivacySettingsButton)
        supportActionContainerView.addSubview(supportActionDividerFourth)
        supportActionContainerView.addSubview(privacyPolicyButton)
        supportActionContainerView.addSubview(supportActionDividerMiddle)
        supportActionContainerView.addSubview(communityGuidelinesButton)
        supportActionContainerView.addSubview(supportActionDividerBottom)
        supportActionContainerView.addSubview(contactSupportButton)

        steamConnectedBadgeView.addSubview(steamConnectedBadgeLabel)
        steamAccountIconContainerView.addSubview(steamAccountIconImageView)

        let steamTitleRow = UIStackView(arrangedSubviews: [steamAccountTitleLabel, steamConnectedBadgeView])
        steamTitleRow.axis = .horizontal
        steamTitleRow.alignment = .center
        steamTitleRow.spacing = 8

        let steamTextStack = UIStackView(arrangedSubviews: [steamTitleRow, steamAccountSubtitleLabel])
        steamTextStack.axis = .vertical
        steamTextStack.spacing = 4
        steamTextStack.translatesAutoresizingMaskIntoConstraints = false

        connectedAccountsContainerView.addSubview(steamAccountIconContainerView)
        connectedAccountsContainerView.addSubview(steamTextStack)
        connectedAccountsContainerView.addSubview(steamUnlinkButton)

        connectedAccountsSectionStackView.addArrangedSubview(connectedAccountsHeaderView)
        connectedAccountsSectionStackView.addArrangedSubview(connectedAccountsContainerView)
        recentPlaySectionStackView.addArrangedSubview(sectionHeader)
        recentPlaySectionStackView.addArrangedSubview(tableView)

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStackView)

        [
            headerCardView,
            statsContainerView,
            connectedAccountsSectionStackView,
            friendSectionHeaderView,
            friendActionContainerView,
            accountActionContainerView,
            supportActionContainerView,
            recentPlaySectionStackView
        ].forEach {
            contentStackView.addArrangedSubview($0)
        }

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

            contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),

            headerCardView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            headerCardView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            statsContainerView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            statsContainerView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            statsStack.topAnchor.constraint(equalTo: statsContainerView.topAnchor, constant: 16),
            statsStack.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor, constant: 16),
            statsStack.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor, constant: -16),
            statsStack.bottomAnchor.constraint(equalTo: statsContainerView.bottomAnchor, constant: -16),

            connectedAccountsSectionStackView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            connectedAccountsSectionStackView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            steamAccountIconContainerView.leadingAnchor.constraint(equalTo: connectedAccountsContainerView.leadingAnchor, constant: 16),
            steamAccountIconContainerView.centerYAnchor.constraint(equalTo: connectedAccountsContainerView.centerYAnchor),
            steamAccountIconContainerView.widthAnchor.constraint(equalToConstant: 36),
            steamAccountIconContainerView.heightAnchor.constraint(equalToConstant: 36),

            steamAccountIconImageView.centerXAnchor.constraint(equalTo: steamAccountIconContainerView.centerXAnchor),
            steamAccountIconImageView.centerYAnchor.constraint(equalTo: steamAccountIconContainerView.centerYAnchor),

            steamConnectedBadgeLabel.topAnchor.constraint(equalTo: steamConnectedBadgeView.topAnchor, constant: 3),
            steamConnectedBadgeLabel.bottomAnchor.constraint(equalTo: steamConnectedBadgeView.bottomAnchor, constant: -3),
            steamConnectedBadgeLabel.leadingAnchor.constraint(equalTo: steamConnectedBadgeView.leadingAnchor, constant: 8),
            steamConnectedBadgeLabel.trailingAnchor.constraint(equalTo: steamConnectedBadgeView.trailingAnchor, constant: -8),

            steamUnlinkButton.trailingAnchor.constraint(equalTo: connectedAccountsContainerView.trailingAnchor, constant: -16),
            steamUnlinkButton.centerYAnchor.constraint(equalTo: connectedAccountsContainerView.centerYAnchor),

            steamTextStack.topAnchor.constraint(equalTo: connectedAccountsContainerView.topAnchor, constant: 16),
            steamTextStack.leadingAnchor.constraint(equalTo: steamAccountIconContainerView.trailingAnchor, constant: 12),
            steamTextStack.trailingAnchor.constraint(lessThanOrEqualTo: steamUnlinkButton.leadingAnchor, constant: -12),
            steamTextStack.bottomAnchor.constraint(equalTo: connectedAccountsContainerView.bottomAnchor, constant: -16),

            friendSectionHeaderView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            friendSectionHeaderView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),
            friendSectionHeaderView.heightAnchor.constraint(equalToConstant: 44),

            friendActionContainerView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            friendActionContainerView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            friendsListButton.topAnchor.constraint(equalTo: friendActionContainerView.topAnchor),
            friendsListButton.leadingAnchor.constraint(equalTo: friendActionContainerView.leadingAnchor),
            friendsListButton.trailingAnchor.constraint(equalTo: friendActionContainerView.trailingAnchor),
            friendsListButton.heightAnchor.constraint(equalToConstant: 52),

            friendActionDividerTop.topAnchor.constraint(equalTo: friendsListButton.bottomAnchor),
            friendActionDividerTop.leadingAnchor.constraint(equalTo: friendActionContainerView.leadingAnchor, constant: 16),
            friendActionDividerTop.trailingAnchor.constraint(equalTo: friendActionContainerView.trailingAnchor, constant: -16),
            friendActionDividerTop.heightAnchor.constraint(equalToConstant: 1),

            steamFriendsButton.topAnchor.constraint(equalTo: friendActionDividerTop.bottomAnchor),
            steamFriendsButton.leadingAnchor.constraint(equalTo: friendActionContainerView.leadingAnchor),
            steamFriendsButton.trailingAnchor.constraint(equalTo: friendActionContainerView.trailingAnchor),
            steamFriendsButton.heightAnchor.constraint(equalToConstant: 52),

            friendActionDividerFourth.topAnchor.constraint(equalTo: steamFriendsButton.bottomAnchor),
            friendActionDividerFourth.leadingAnchor.constraint(equalTo: friendActionContainerView.leadingAnchor, constant: 16),
            friendActionDividerFourth.trailingAnchor.constraint(equalTo: friendActionContainerView.trailingAnchor, constant: -16),
            friendActionDividerFourth.heightAnchor.constraint(equalToConstant: 1),

            friendRequestsButton.topAnchor.constraint(equalTo: friendActionDividerFourth.bottomAnchor),
            friendRequestsButton.leadingAnchor.constraint(equalTo: friendActionContainerView.leadingAnchor),
            friendRequestsButton.trailingAnchor.constraint(equalTo: friendActionContainerView.trailingAnchor),
            friendRequestsButton.heightAnchor.constraint(equalToConstant: 52),

            friendActionDividerBottom.topAnchor.constraint(equalTo: friendRequestsButton.bottomAnchor),
            friendActionDividerBottom.leadingAnchor.constraint(equalTo: friendActionContainerView.leadingAnchor, constant: 16),
            friendActionDividerBottom.trailingAnchor.constraint(equalTo: friendActionContainerView.trailingAnchor, constant: -16),
            friendActionDividerBottom.heightAnchor.constraint(equalToConstant: 1),

            friendSearchButton.topAnchor.constraint(equalTo: friendActionDividerBottom.bottomAnchor),
            friendSearchButton.leadingAnchor.constraint(equalTo: friendActionContainerView.leadingAnchor),
            friendSearchButton.trailingAnchor.constraint(equalTo: friendActionContainerView.trailingAnchor),
            friendSearchButton.heightAnchor.constraint(equalToConstant: 52),
            
            friendActionDividerThird.topAnchor.constraint(equalTo: friendSearchButton.bottomAnchor),
            friendActionDividerThird.leadingAnchor.constraint(equalTo: friendActionContainerView.leadingAnchor, constant: 16),
            friendActionDividerThird.trailingAnchor.constraint(equalTo: friendActionContainerView.trailingAnchor, constant: -16),
            friendActionDividerThird.heightAnchor.constraint(equalToConstant: 1),

            friendActivityButton.topAnchor.constraint(equalTo: friendActionDividerThird.bottomAnchor),
            friendActivityButton.leadingAnchor.constraint(equalTo: friendActionContainerView.leadingAnchor),
            friendActivityButton.trailingAnchor.constraint(equalTo: friendActionContainerView.trailingAnchor),
            friendActivityButton.heightAnchor.constraint(equalToConstant: 52),
            friendActivityButton.bottomAnchor.constraint(equalTo: friendActionContainerView.bottomAnchor),

            accountActionContainerView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            accountActionContainerView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

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

            supportActionContainerView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: 20),
            supportActionContainerView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -20),

            termsOfServiceButton.topAnchor.constraint(equalTo: supportActionContainerView.topAnchor),
            termsOfServiceButton.leadingAnchor.constraint(equalTo: supportActionContainerView.leadingAnchor),
            termsOfServiceButton.trailingAnchor.constraint(equalTo: supportActionContainerView.trailingAnchor),
            termsOfServiceButton.heightAnchor.constraint(equalToConstant: 52),

            supportActionDividerTop.topAnchor.constraint(equalTo: termsOfServiceButton.bottomAnchor),
            supportActionDividerTop.leadingAnchor.constraint(equalTo: supportActionContainerView.leadingAnchor, constant: 16),
            supportActionDividerTop.trailingAnchor.constraint(equalTo: supportActionContainerView.trailingAnchor, constant: -16),
            supportActionDividerTop.heightAnchor.constraint(equalToConstant: 1),

            socialPrivacySettingsButton.topAnchor.constraint(equalTo: supportActionDividerTop.bottomAnchor),
            socialPrivacySettingsButton.leadingAnchor.constraint(equalTo: supportActionContainerView.leadingAnchor),
            socialPrivacySettingsButton.trailingAnchor.constraint(equalTo: supportActionContainerView.trailingAnchor),
            socialPrivacySettingsButton.heightAnchor.constraint(equalToConstant: 52),

            supportActionDividerFourth.topAnchor.constraint(equalTo: socialPrivacySettingsButton.bottomAnchor),
            supportActionDividerFourth.leadingAnchor.constraint(equalTo: supportActionContainerView.leadingAnchor, constant: 16),
            supportActionDividerFourth.trailingAnchor.constraint(equalTo: supportActionContainerView.trailingAnchor, constant: -16),
            supportActionDividerFourth.heightAnchor.constraint(equalToConstant: 1),

            privacyPolicyButton.topAnchor.constraint(equalTo: supportActionDividerFourth.bottomAnchor),
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

            sectionHeader.heightAnchor.constraint(equalToConstant: 44),
            recentPlaySectionStackView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor),
            recentPlaySectionStackView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor),
            sectionHeader.leadingAnchor.constraint(equalTo: recentPlaySectionStackView.leadingAnchor, constant: 20),
            sectionHeader.trailingAnchor.constraint(equalTo: recentPlaySectionStackView.trailingAnchor, constant: -20),
            tableView.leadingAnchor.constraint(equalTo: recentPlaySectionStackView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: recentPlaySectionStackView.trailingAnchor)
        ])

        recentPlayTableHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 0)
        recentPlayTableHeightConstraint?.isActive = true
    }

    // MARK: - State Rendering

    func render(_ state: ProfileState) {
        headerCardView.render(
            profileImageURL: state.profileImageURL,
            nickname: state.displayName,
            email: state.displayEmail,
            badgeTitle: state.badgeTitle,
            isLoading: state.isLoading && state.authenticatedUser == nil
        )

        playedStatView.configure(value: "\(state.playedGameCount)", label: "플레이한 게임")
        reviewStatView.configure(value: "\(state.writtenReviewCount)", label: "작성한 리뷰")
        wishlistStatView.configure(value: "\(state.wishlistCount)", label: "찜한 게임")
        connectedAccountsSectionStackView.isHidden = !state.isSteamConnected
        steamAccountSubtitleLabel.text = state.steamConnectionSubtitle
        updateRecentPlayTableHeight(rowCount: state.recentGames.count)

        updateAccountActionButtons(with: state)
    }

    func updateRecentPlayTableHeight(rowCount: Int) {
        recentPlayTableHeightConstraint?.constant = CGFloat(rowCount) * RecentPlayCell.height
        recentPlaySectionStackView.isHidden = rowCount == 0
        layoutIfNeeded()
    }

    private func updateAccountActionButtons(with state: ProfileState) {
        logoutButton.isEnabled = !state.isAccountActionInProgress
        deleteAccountButton.isEnabled = !state.isAccountActionInProgress
        logoutButton.alpha = logoutButton.isEnabled ? 1.0 : 0.7
        deleteAccountButton.alpha = deleteAccountButton.isEnabled ? 1.0 : 0.7
        steamUnlinkButton.isEnabled = state.isSteamConnected && !state.isUnlinkingSteamAccount
        steamUnlinkButton.alpha = steamUnlinkButton.isEnabled ? 1.0 : 0.6

        var logoutConfiguration = logoutButton.configuration
        logoutConfiguration?.showsActivityIndicator = state.isLoggingOut
        logoutConfiguration?.image = state.isLoggingOut ? nil : UIImage(systemName: "rectangle.portrait.and.arrow.right")
        logoutButton.configuration = logoutConfiguration

        var deleteConfiguration = deleteAccountButton.configuration
        deleteConfiguration?.showsActivityIndicator = state.isDeletingAccount
        deleteConfiguration?.image = state.isDeletingAccount ? nil : UIImage(systemName: "person.crop.circle.badge.minus")
        deleteAccountButton.configuration = deleteConfiguration

        var steamConfiguration = steamUnlinkButton.configuration
        steamConfiguration?.showsActivityIndicator = state.isUnlinkingSteamAccount
        steamUnlinkButton.configuration = steamConfiguration
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

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 84)
    }

    func configure(value: String, label: String) {
        valueLabel.text = value
        captionLabel.text = label
    }

    func setValueColor(_ color: UIColor) {
        valueLabel.textColor = color
    }
}

final class ProfileHeaderCardView: UIView {
    private let profileCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 20
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentInsetView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let horizontalStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let profileImageContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let profileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 32
        imageView.backgroundColor = .gpSurfaceElevated
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let profileImageSkeletonView = SkeletonPlaceholderView(cornerRadius: 32)

    private let textContentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let nicknameContainerView = UIView()
    private let emailContainerView = UIView()
    private let badgeContainerView = UIView()

    private let nicknameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let emailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusBadgeView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpPrimary
        view.layer.cornerRadius = 10
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let statusBadgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .gpOnPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let nicknameSkeletonView = SkeletonPlaceholderView(cornerRadius: 10)
    private let emailSkeletonView = SkeletonPlaceholderView(cornerRadius: 8)
    private let badgeSkeletonView = SkeletonPlaceholderView(cornerRadius: 10)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func render(
        profileImageURL: URL?,
        nickname: String?,
        email: String?,
        badgeTitle: String?,
        isLoading: Bool
    ) {
        let placeholderImage = UIImage(systemName: "person.fill")
        profileImageView.tintColor = .gpTextTertiary
        profileImageView.contentMode = profileImageURL == nil ? .center : .scaleAspectFill
        profileImageView.loadImage(url: profileImageURL, placeholder: placeholderImage)
        nicknameLabel.text = nickname ?? "GamePedia"
        emailLabel.text = email ?? ""
        statusBadgeLabel.text = badgeTitle

        let hasBadge = (badgeTitle?.isEmpty == false)
        emailContainerView.isHidden = (!isLoading && (email?.isEmpty ?? true))
        badgeContainerView.isHidden = (!isLoading && !hasBadge)
        statusBadgeView.isHidden = !hasBadge

        profileImageView.isHidden = isLoading
        nicknameLabel.isHidden = isLoading
        emailLabel.isHidden = isLoading
        statusBadgeLabel.isHidden = isLoading || !hasBadge

        profileImageSkeletonView.isHidden = !isLoading
        nicknameSkeletonView.isHidden = !isLoading
        emailSkeletonView.isHidden = !isLoading
        badgeSkeletonView.isHidden = !isLoading
    }

    private func setup() {
        backgroundColor = .clear

        [profileImageView, profileImageSkeletonView].forEach { profileImageContainerView.addSubview($0) }
        [nicknameLabel, nicknameSkeletonView].forEach { nicknameContainerView.addSubview($0) }
        [emailLabel, emailSkeletonView].forEach { emailContainerView.addSubview($0) }
        badgeContainerView.addSubview(statusBadgeView)
        badgeContainerView.addSubview(badgeSkeletonView)
        statusBadgeView.addSubview(statusBadgeLabel)

        [nicknameContainerView, emailContainerView, badgeContainerView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            textContentStackView.addArrangedSubview($0)
        }

        horizontalStackView.addArrangedSubview(profileImageContainerView)
        horizontalStackView.addArrangedSubview(textContentStackView)

        addSubview(profileCardView)
        profileCardView.addSubview(contentInsetView)
        contentInsetView.addSubview(horizontalStackView)

        profileImageContainerView.setContentHuggingPriority(.required, for: .horizontal)
        profileImageContainerView.setContentCompressionResistancePriority(.required, for: .horizontal)
        textContentStackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textContentStackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusBadgeView.setContentHuggingPriority(.required, for: .horizontal)
        statusBadgeView.setContentCompressionResistancePriority(.required, for: .horizontal)
        badgeSkeletonView.setContentHuggingPriority(.required, for: .horizontal)
        badgeSkeletonView.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            profileCardView.topAnchor.constraint(equalTo: topAnchor),
            profileCardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            profileCardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            profileCardView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentInsetView.topAnchor.constraint(equalTo: profileCardView.topAnchor, constant: 20),
            contentInsetView.leadingAnchor.constraint(equalTo: profileCardView.leadingAnchor, constant: 20),
            contentInsetView.trailingAnchor.constraint(equalTo: profileCardView.trailingAnchor, constant: -20),
            contentInsetView.bottomAnchor.constraint(equalTo: profileCardView.bottomAnchor, constant: -20),

            horizontalStackView.topAnchor.constraint(equalTo: contentInsetView.topAnchor),
            horizontalStackView.leadingAnchor.constraint(equalTo: contentInsetView.leadingAnchor),
            horizontalStackView.trailingAnchor.constraint(equalTo: contentInsetView.trailingAnchor),
            horizontalStackView.bottomAnchor.constraint(equalTo: contentInsetView.bottomAnchor),

            profileImageContainerView.widthAnchor.constraint(equalToConstant: 64),
            profileImageContainerView.heightAnchor.constraint(equalToConstant: 64),
            profileImageView.topAnchor.constraint(equalTo: profileImageContainerView.topAnchor),
            profileImageView.leadingAnchor.constraint(equalTo: profileImageContainerView.leadingAnchor),
            profileImageView.trailingAnchor.constraint(equalTo: profileImageContainerView.trailingAnchor),
            profileImageView.bottomAnchor.constraint(equalTo: profileImageContainerView.bottomAnchor),
            profileImageSkeletonView.topAnchor.constraint(equalTo: profileImageContainerView.topAnchor),
            profileImageSkeletonView.leadingAnchor.constraint(equalTo: profileImageContainerView.leadingAnchor),
            profileImageSkeletonView.trailingAnchor.constraint(equalTo: profileImageContainerView.trailingAnchor),
            profileImageSkeletonView.bottomAnchor.constraint(equalTo: profileImageContainerView.bottomAnchor),

            nicknameLabel.topAnchor.constraint(equalTo: nicknameContainerView.topAnchor),
            nicknameLabel.leadingAnchor.constraint(equalTo: nicknameContainerView.leadingAnchor),
            nicknameLabel.trailingAnchor.constraint(equalTo: nicknameContainerView.trailingAnchor),
            nicknameLabel.bottomAnchor.constraint(equalTo: nicknameContainerView.bottomAnchor),
            nicknameSkeletonView.topAnchor.constraint(equalTo: nicknameContainerView.topAnchor, constant: 2),
            nicknameSkeletonView.leadingAnchor.constraint(equalTo: nicknameContainerView.leadingAnchor),
            nicknameSkeletonView.widthAnchor.constraint(equalToConstant: 140),
            nicknameSkeletonView.heightAnchor.constraint(equalToConstant: 24),
            nicknameSkeletonView.bottomAnchor.constraint(equalTo: nicknameContainerView.bottomAnchor, constant: -2),

            emailLabel.topAnchor.constraint(equalTo: emailContainerView.topAnchor),
            emailLabel.leadingAnchor.constraint(equalTo: emailContainerView.leadingAnchor),
            emailLabel.trailingAnchor.constraint(equalTo: emailContainerView.trailingAnchor),
            emailLabel.bottomAnchor.constraint(equalTo: emailContainerView.bottomAnchor),
            emailSkeletonView.topAnchor.constraint(equalTo: emailContainerView.topAnchor, constant: 1),
            emailSkeletonView.leadingAnchor.constraint(equalTo: emailContainerView.leadingAnchor),
            emailSkeletonView.widthAnchor.constraint(equalToConstant: 164),
            emailSkeletonView.heightAnchor.constraint(equalToConstant: 16),
            emailSkeletonView.bottomAnchor.constraint(equalTo: emailContainerView.bottomAnchor, constant: -1),

            statusBadgeView.topAnchor.constraint(equalTo: badgeContainerView.topAnchor),
            statusBadgeView.leadingAnchor.constraint(equalTo: badgeContainerView.leadingAnchor),
            statusBadgeView.bottomAnchor.constraint(equalTo: badgeContainerView.bottomAnchor),
            statusBadgeLabel.topAnchor.constraint(equalTo: statusBadgeView.topAnchor, constant: 4),
            statusBadgeLabel.bottomAnchor.constraint(equalTo: statusBadgeView.bottomAnchor, constant: -4),
            statusBadgeLabel.leadingAnchor.constraint(equalTo: statusBadgeView.leadingAnchor, constant: 10),
            statusBadgeLabel.trailingAnchor.constraint(equalTo: statusBadgeView.trailingAnchor, constant: -10),

            badgeSkeletonView.topAnchor.constraint(equalTo: badgeContainerView.topAnchor),
            badgeSkeletonView.leadingAnchor.constraint(equalTo: badgeContainerView.leadingAnchor),
            badgeSkeletonView.widthAnchor.constraint(equalToConstant: 72),
            badgeSkeletonView.heightAnchor.constraint(equalToConstant: 22),
            badgeSkeletonView.bottomAnchor.constraint(equalTo: badgeContainerView.bottomAnchor)
        ])
    }
}
