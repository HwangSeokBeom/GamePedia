import UIKit

// MARK: - ProfileRootView

final class ProfileRootView: UIView {
    private struct RootRenderSignature: Equatable {
        let profileImageURL: URL?
        let nickname: String?
        let email: String?
        let badgeTitles: [String]
        let descriptionText: String
        let primaryMetaText: String
        let secondaryMetaText: String
        let isLoading: Bool
        let playedGameCount: Int
        let writtenReviewCount: Int
        let wishlistCount: Int
        let isSteamConnected: Bool
        let steamConnectionSubtitle: String
        let friendManagementText: String
        let friendActivityText: String
        let tasteSummaryText: String
        let isAccountActionInProgress: Bool
        let isUnlinkingSteamAccount: Bool
    }

    private struct RecentPlaySectionSignature: Equatable {
        let rowCount: Int
        let hasMoreRecentPlayed: Bool
        let recentPlayLoadState: ProfileRecentPlayLoadState
        let emptyText: String
    }

    private let sectionHorizontalInset: CGFloat = 20

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
        stackView.spacing = 14
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
        stackView.spacing = 10
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
        label.text = L10n.Profile.Account.connected
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let steamUnlinkButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = L10n.Profile.Action.unlinkSteam
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
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let friendActionRowsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    let friendsListButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let steamFriendsButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeCompactActionConfiguration(
            title: L10n.Profile.Action.steamFriends,
            systemImageName: "person.3",
            tintColor: .gpTextSecondary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let friendRequestsButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeCompactActionConfiguration(
            title: L10n.Profile.Action.friendRequests,
            systemImageName: "person.crop.circle.badge.plus",
            tintColor: .gpPrimaryLight
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let friendSearchButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeCompactActionConfiguration(
            title: L10n.Profile.Action.findFriends,
            systemImageName: "magnifyingglass",
            tintColor: .gpPrimary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let friendActivityButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let socialManagementRowView = SocialTasteRowView(
        systemImageName: "person.2.fill",
        title: L10n.Profile.Social.friendManagement,
        tintColor: .gpPrimary
    )

    private let socialActivityRowView = SocialTasteRowView(
        systemImageName: "waveform.path.ecg",
        title: L10n.Profile.Social.friendActivity,
        tintColor: .gpTeal
    )

    private let tasteSummaryRowView = SocialTasteRowView(
        systemImageName: "sparkles",
        title: L10n.Profile.Social.tasteTags,
        tintColor: .gpPrimaryLight,
        isInteractive: false
    )

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
            title: L10n.Profile.Action.logout,
            systemImageName: "rectangle.portrait.and.arrow.right",
            tintColor: .gpTextPrimary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }()

    let deleteAccountButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: L10n.Profile.Action.deleteAccount,
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
            title: L10n.Profile.Action.terms,
            systemImageName: "doc.text",
            tintColor: .gpTextPrimary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }()

    let privacyPolicyButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: L10n.Profile.Action.privacyPolicy,
            systemImageName: "lock.shield",
            tintColor: .gpTextPrimary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }()

    let communityGuidelinesButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: L10n.Profile.Action.communityGuidelines,
            systemImageName: "person.2.wave.2",
            tintColor: .gpTextPrimary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }()

    let contactSupportButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: L10n.Profile.Action.contactSupport,
            systemImageName: "envelope",
            tintColor: .gpPrimary
        ))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }()

    let socialPrivacySettingsButton: UIButton = {
        let button = UIButton(configuration: ProfileRootView.makeAccountActionConfiguration(
            title: L10n.Profile.Action.socialPrivacy,
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
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let recentPlayEmptyCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.gpSeparator.withAlphaComponent(0.24).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let recentPlayEmptyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .gpTextSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = L10n.Profile.Empty.noRecentPlayedGames
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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
    private var lastRootRenderSignature: RootRenderSignature?
    private var lastRecentPlaySectionSignature: RecentPlaySectionSignature?

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
        statsContainerView.backgroundColor = .clear
        statsContainerView.translatesAutoresizingMaskIntoConstraints = false

        // Stat cards — distinct accent colors per slot
        playedStatView.setValueColor(.gpTeal)
        reviewStatView.setValueColor(.gpPrimary)
        wishlistStatView.setValueColor(.gpRed)

        [playedStatView, reviewStatView, wishlistStatView].forEach {
            $0.backgroundColor = .gpCardBackground
            $0.layer.cornerRadius = 18
            $0.layer.cornerCurve = .continuous
            $0.layer.borderWidth = 1
            $0.layer.borderColor = UIColor.gpSeparator.withAlphaComponent(0.24).cgColor
            $0.clipsToBounds = true
            $0.isUserInteractionEnabled = true
        }

        let statsStack = UIStackView(arrangedSubviews: [playedStatView, reviewStatView, wishlistStatView])
        statsStack.axis = .horizontal
        statsStack.distribution = .fillEqually
        statsStack.spacing = 10
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        statsContainerView.addSubview(statsStack)

        // Section header
        sectionHeader.configure(title: L10n.Profile.Section.recentPlay)
        sectionHeader.titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        sectionHeader.translatesAutoresizingMaskIntoConstraints = false

        connectedAccountsHeaderView.configure(title: L10n.Profile.Section.connectedAccounts, showSeeMore: false)
        connectedAccountsHeaderView.titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        friendSectionHeaderView.configure(title: L10n.Profile.Section.socialTaste, showSeeMore: false)
        friendSectionHeaderView.titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        recentPlayEmptyCardView.addSubview(recentPlayEmptyLabel)

        accountActionContainerView.addSubview(logoutButton)
        accountActionContainerView.addSubview(accountActionDivider)
        accountActionContainerView.addSubview(deleteAccountButton)

        friendActionContainerView.addSubview(friendActionRowsStackView)
        [socialManagementRowView, socialActivityRowView, tasteSummaryRowView].forEach {
            friendActionRowsStackView.addArrangedSubview($0)
        }

        socialManagementRowView.actionButton = friendsListButton
        socialActivityRowView.actionButton = friendActivityButton

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
        recentPlaySectionStackView.addArrangedSubview(recentPlayEmptyCardView)

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStackView)

        [
            headerCardView,
            statsContainerView,
            friendSectionHeaderView,
            friendActionContainerView,
            recentPlaySectionStackView,
            connectedAccountsSectionStackView
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

            contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sectionHorizontalInset),
            contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -sectionHorizontalInset),
            contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),

            statsStack.topAnchor.constraint(equalTo: statsContainerView.topAnchor),
            statsStack.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor),
            statsStack.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor),
            statsStack.bottomAnchor.constraint(equalTo: statsContainerView.bottomAnchor),

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

            friendSectionHeaderView.heightAnchor.constraint(equalToConstant: 34),

            friendActionRowsStackView.topAnchor.constraint(equalTo: friendActionContainerView.topAnchor),
            friendActionRowsStackView.leadingAnchor.constraint(equalTo: friendActionContainerView.leadingAnchor),
            friendActionRowsStackView.trailingAnchor.constraint(equalTo: friendActionContainerView.trailingAnchor),
            friendActionRowsStackView.bottomAnchor.constraint(equalTo: friendActionContainerView.bottomAnchor),

            socialManagementRowView.heightAnchor.constraint(equalToConstant: 60),
            socialActivityRowView.heightAnchor.constraint(equalToConstant: 60),
            tasteSummaryRowView.heightAnchor.constraint(equalToConstant: 60),

            sectionHeader.heightAnchor.constraint(equalToConstant: 34),
            sectionHeader.leadingAnchor.constraint(equalTo: recentPlaySectionStackView.leadingAnchor),
            sectionHeader.trailingAnchor.constraint(equalTo: recentPlaySectionStackView.trailingAnchor),
            tableView.leadingAnchor.constraint(equalTo: recentPlaySectionStackView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: recentPlaySectionStackView.trailingAnchor),

            recentPlayEmptyLabel.topAnchor.constraint(equalTo: recentPlayEmptyCardView.topAnchor, constant: 20),
            recentPlayEmptyLabel.leadingAnchor.constraint(equalTo: recentPlayEmptyCardView.leadingAnchor, constant: 20),
            recentPlayEmptyLabel.trailingAnchor.constraint(equalTo: recentPlayEmptyCardView.trailingAnchor, constant: -20),
            recentPlayEmptyLabel.bottomAnchor.constraint(equalTo: recentPlayEmptyCardView.bottomAnchor, constant: -20),
            recentPlayEmptyCardView.leadingAnchor.constraint(equalTo: recentPlaySectionStackView.leadingAnchor),
            recentPlayEmptyCardView.trailingAnchor.constraint(equalTo: recentPlaySectionStackView.trailingAnchor)
        ])

        contentStackView.setCustomSpacing(12, after: headerCardView)
        contentStackView.setCustomSpacing(14, after: statsContainerView)
        contentStackView.setCustomSpacing(10, after: friendSectionHeaderView)
        contentStackView.setCustomSpacing(14, after: friendActionContainerView)

        recentPlayTableHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 0)
        recentPlayTableHeightConstraint?.isActive = true
    }

    // MARK: - State Rendering

    func render(_ state: ProfileState) {
        let friendActivitySubtitle: String
        if state.friendCount == 0 || state.friendActivityCount == 0 {
            friendActivitySubtitle = L10n.Profile.Activity.none
        } else {
            friendActivitySubtitle = L10n.Profile.Activity.newCount(state.friendActivityCount)
        }
        let rootRenderSignature = RootRenderSignature(
            profileImageURL: state.profileImageURL,
            nickname: state.displayName,
            email: state.displayEmail,
            badgeTitles: state.heroBadgeTitles,
            descriptionText: makeProfileDescription(from: state),
            primaryMetaText: L10n.Common.Count.friends(state.friendCount),
            secondaryMetaText: L10n.Profile.Count.likes(state.wishlistCount),
            isLoading: state.isLoading && state.authenticatedUser == nil,
            playedGameCount: state.playedGameCount,
            writtenReviewCount: state.writtenReviewCount,
            wishlistCount: state.wishlistCount,
            isSteamConnected: state.isSteamConnected,
            steamConnectionSubtitle: state.steamConnectionSubtitle,
            friendManagementText: L10n.Profile.Meta.friendsConnected(state.friendCount),
            friendActivityText: friendActivitySubtitle,
            tasteSummaryText: makeTasteSummary(from: state),
            isAccountActionInProgress: state.isAccountActionInProgress,
            isUnlinkingSteamAccount: state.isUnlinkingSteamAccount
        )
        if lastRootRenderSignature != rootRenderSignature {
            headerCardView.render(
                profileImageURL: state.profileImageURL,
                nickname: state.displayName,
                email: state.displayEmail,
                badgeTitles: state.heroBadgeTitles,
                descriptionText: rootRenderSignature.descriptionText,
                primaryMetaText: rootRenderSignature.primaryMetaText,
                secondaryMetaText: rootRenderSignature.secondaryMetaText,
                isLoading: rootRenderSignature.isLoading
            )

            playedStatView.configure(value: "\(state.playedGameCount)", title: L10n.Profile.Stat.playedGames)
            reviewStatView.configure(value: "\(state.writtenReviewCount)", title: L10n.Profile.Stat.writtenReviews)
            wishlistStatView.configure(value: "\(state.wishlistCount)", title: L10n.Profile.Stat.wishlistedGames)
            connectedAccountsSectionStackView.isHidden = !state.isSteamConnected
            steamAccountSubtitleLabel.text = state.steamConnectionSubtitle
            socialManagementRowView.setSecondaryText(rootRenderSignature.friendManagementText)
            socialActivityRowView.setSecondaryText(rootRenderSignature.friendActivityText)
            tasteSummaryRowView.setSecondaryText(rootRenderSignature.tasteSummaryText)
            updateAccountActionButtons(with: state)
            lastRootRenderSignature = rootRenderSignature
        }

        let recentPlaySectionSignature = RecentPlaySectionSignature(
            rowCount: state.recentlyPlayedGames.count,
            hasMoreRecentPlayed: state.hasMoreRecentPlayed,
            recentPlayLoadState: state.recentPlayLoadState,
            emptyText: makeRecentPlayEmptyText(from: state)
        )
        if lastRecentPlaySectionSignature != recentPlaySectionSignature {
            recentPlayEmptyLabel.text = recentPlaySectionSignature.emptyText
            updateRecentPlayTableHeight(
                rowCount: recentPlaySectionSignature.rowCount,
                hasMoreRecentPlayed: recentPlaySectionSignature.hasMoreRecentPlayed
            )
            lastRecentPlaySectionSignature = recentPlaySectionSignature
        }
    }

    func updateRecentPlayTableHeight(rowCount: Int, hasMoreRecentPlayed: Bool = false) {
        recentPlayTableHeightConstraint?.constant = CGFloat(rowCount) * RecentPlayCell.height
        tableView.isHidden = rowCount == 0
        recentPlayEmptyCardView.isHidden = rowCount > 0
        let canSeeMore = hasMoreRecentPlayed || rowCount > 0
        sectionHeader.seeMoreButton.isEnabled = canSeeMore
        sectionHeader.seeMoreButton.alpha = canSeeMore ? 1.0 : 0.45
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

    private static func makeCompactActionConfiguration(
        title: String,
        systemImageName: String,
        tintColor: UIColor
    ) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: systemImageName)
        configuration.imagePadding = 6
        configuration.baseForegroundColor = tintColor
        configuration.baseBackgroundColor = UIColor.gpSurfaceElevated.withAlphaComponent(0.78)
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            return attributes
        }
        return configuration
    }

    private func makeTasteSummary(from state: ProfileState) -> String {
        if state.profileTags.isEmpty == false {
            return state.profileTags.prefix(3).joined(separator: " · ")
        }
        if state.selectedBadgeTitles.contains("RPG Lover") {
            return "RPG · Soulslike"
        }
        if state.selectedBadgeTitles.contains("Hardcore Gamer") {
            return L10n.tr("Localizable", "profile.taste.placeholderHardcore")
        }
        if state.selectedBadgeTitles.contains("Pro Reviewer") {
            return L10n.Profile.Taste.reviewStoryFocused
        }
        if !state.selectedBadgeTitles.isEmpty {
            return state.selectedBadgeTitles.joined(separator: " · ")
        }
        if state.writtenReviewCount > 0 && state.wishlistCount > 0 {
            return L10n.Profile.Taste.reviewWishlistBased
        }
        if state.recentlyPlayedGames.isEmpty == false {
            return L10n.Profile.Taste.playRecordBased
        }
        return L10n.Profile.Taste.dataAccumulating
    }

    private func makeRecentPlayEmptyText(from state: ProfileState) -> String {
        switch state.recentPlayLoadState {
        case .loading:
            return L10n.Profile.Empty.recentPlayLoading
        case .partialFailure, .failed:
            return L10n.Profile.Empty.recentPlayUnavailable
        case .idle, .empty, .loaded:
            return L10n.Profile.Empty.noRecentPlayedGames
        }
    }

    private func makeProfileDescription(from state: ProfileState) -> String {
        return L10n.Profile.Description.growth
    }
}

// MARK: - ProfileStatView

final class ProfileStatView: UIView {

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.textColor = .gpPrimary
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: [valueLabel, titleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 12, bottom: 14, right: 12)
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
        CGSize(width: UIView.noIntrinsicMetric, height: 86)
    }

    func configure(value: String, title: String) {
        valueLabel.text = value
        titleLabel.text = title
    }

    func setValueColor(_ color: UIColor) {
        valueLabel.textColor = color
    }
}

final class ProfileHeaderCardView: UIView {
    private struct HeaderRenderSignature: Equatable {
        let profileImageURL: URL?
        let nickname: String?
        let email: String?
        let badgeTitles: [String]
        let descriptionText: String
        let primaryMetaText: String
        let secondaryMetaText: String
        let isLoading: Bool
    }

    private let profileCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 20
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.gpSeparator.withAlphaComponent(0.35).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentInsetView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let verticalStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    let editProfileButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = L10n.tr("Localizable", "common.button.edit")
        configuration.baseBackgroundColor = UIColor.gpPrimary.withAlphaComponent(0.14)
        configuration.baseForegroundColor = .gpPrimaryLight
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
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

    private let profileImageHaloView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.08)
        view.layer.cornerRadius = 44
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let profileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 40
        imageView.backgroundColor = .gpSurfaceElevated
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let profileImageSkeletonView = SkeletonPlaceholderView(cornerRadius: 40)

    private let textContentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 6
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let nicknameContainerView = UIView()
    private let emailContainerView = UIView()
    private let badgeContainerView = UIView()

    private let nicknameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let emailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let nicknameSkeletonView = SkeletonPlaceholderView(cornerRadius: 10)
    private let emailSkeletonView = SkeletonPlaceholderView(cornerRadius: 8)
    private let badgeSkeletonView = SkeletonPlaceholderView(cornerRadius: 10)

    private let badgeScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.isScrollEnabled = false
        scrollView.clipsToBounds = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let badgeStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        stackView.setContentHuggingPriority(.required, for: .horizontal)
        return stackView
    }()
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionSkeletonView = SkeletonPlaceholderView(cornerRadius: 8)
    private var lastRenderSignature: HeaderRenderSignature?
    private var lastBadgeTitles: [String] = []
    private var badgeLoadedConstraints: [NSLayoutConstraint] = []
    private var badgeLoadingConstraints: [NSLayoutConstraint] = []
    private var isBadgeLoadingLayoutActive = false

    private let metadataStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let primaryMetaLabel = PaddingLabel(insets: UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10))
    private let secondaryMetaLabel = PaddingLabel(insets: UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10))

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
        badgeTitles: [String],
        descriptionText: String,
        primaryMetaText: String,
        secondaryMetaText: String,
        isLoading: Bool
    ) {
        let renderSignature = HeaderRenderSignature(
            profileImageURL: profileImageURL,
            nickname: nickname,
            email: email,
            badgeTitles: badgeTitles,
            descriptionText: descriptionText,
            primaryMetaText: primaryMetaText,
            secondaryMetaText: secondaryMetaText,
            isLoading: isLoading
        )
        guard renderSignature != lastRenderSignature else {
            return
        }
        lastRenderSignature = renderSignature

        let placeholderImage = UIImage(systemName: "person.fill")
        profileImageView.tintColor = .gpTextTertiary
        profileImageView.contentMode = profileImageURL == nil ? .center : .scaleAspectFill
        profileImageView.loadImage(url: profileImageURL, placeholder: placeholderImage)
        nicknameLabel.text = nickname ?? L10n.App.name
        emailLabel.text = email ?? ""
        emailLabel.lineBreakMode = .byTruncatingTail
        descriptionLabel.text = descriptionText
        primaryMetaLabel.text = primaryMetaText
        secondaryMetaLabel.text = secondaryMetaText
        if lastBadgeTitles != badgeTitles {
            configureBadgeTitles(badgeTitles)
            lastBadgeTitles = badgeTitles
        }

        emailContainerView.isHidden = (!isLoading && (email?.isEmpty ?? true))
        badgeContainerView.isHidden = (!isLoading && badgeTitles.isEmpty)

        profileImageView.isHidden = isLoading
        nicknameLabel.isHidden = isLoading
        emailLabel.isHidden = isLoading
        descriptionLabel.isHidden = isLoading
        metadataStackView.isHidden = isLoading

        profileImageSkeletonView.isHidden = !isLoading
        nicknameSkeletonView.isHidden = !isLoading
        emailSkeletonView.isHidden = !isLoading
        badgeSkeletonView.isHidden = !isLoading
        descriptionSkeletonView.isHidden = !isLoading
        badgeScrollView.isHidden = isLoading
        updateBadgeLoadingLayout(isLoading: isLoading)
    }

    private func setup() {
        backgroundColor = .clear
        badgeContainerView.clipsToBounds = false

        profileImageContainerView.addSubview(profileImageHaloView)
        [profileImageView, profileImageSkeletonView].forEach { profileImageContainerView.addSubview($0) }
        [nicknameLabel, nicknameSkeletonView].forEach { nicknameContainerView.addSubview($0) }
        [emailLabel, emailSkeletonView].forEach { emailContainerView.addSubview($0) }
        badgeContainerView.addSubview(badgeScrollView)
        badgeContainerView.addSubview(badgeSkeletonView)
        badgeScrollView.addSubview(badgeStackView)
        [descriptionLabel, descriptionSkeletonView].forEach { contentInsetView.addSubview($0) }

        [primaryMetaLabel, secondaryMetaLabel].forEach {
            $0.font = .systemFont(ofSize: 11, weight: .semibold)
            $0.textColor = .gpTextPrimary
            $0.backgroundColor = .gpSurfaceElevated.withAlphaComponent(0.88)
            $0.layer.cornerRadius = 12
            $0.layer.masksToBounds = true
            metadataStackView.addArrangedSubview($0)
        }

        [nicknameContainerView, emailContainerView, badgeContainerView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            textContentStackView.addArrangedSubview($0)
        }

        let spacerView = UIView()
        spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        horizontalStackView.addArrangedSubview(profileImageContainerView)
        horizontalStackView.addArrangedSubview(textContentStackView)
        horizontalStackView.addArrangedSubview(spacerView)
        horizontalStackView.addArrangedSubview(editProfileButton)

        addSubview(profileCardView)
        profileCardView.addSubview(contentInsetView)
        contentInsetView.addSubview(verticalStackView)
        contentInsetView.addSubview(metadataStackView)

        verticalStackView.addArrangedSubview(horizontalStackView)

        profileImageContainerView.setContentHuggingPriority(.required, for: .horizontal)
        profileImageContainerView.setContentCompressionResistancePriority(.required, for: .horizontal)
        textContentStackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textContentStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        badgeSkeletonView.setContentHuggingPriority(.required, for: .horizontal)
        badgeSkeletonView.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            profileCardView.topAnchor.constraint(equalTo: topAnchor),
            profileCardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            profileCardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            profileCardView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentInsetView.topAnchor.constraint(equalTo: profileCardView.topAnchor, constant: 20),
            contentInsetView.leadingAnchor.constraint(equalTo: profileCardView.leadingAnchor, constant: 18),
            contentInsetView.trailingAnchor.constraint(equalTo: profileCardView.trailingAnchor, constant: -18),
            contentInsetView.bottomAnchor.constraint(equalTo: profileCardView.bottomAnchor, constant: -18),

            verticalStackView.topAnchor.constraint(equalTo: contentInsetView.topAnchor),
            verticalStackView.leadingAnchor.constraint(equalTo: contentInsetView.leadingAnchor),
            verticalStackView.trailingAnchor.constraint(equalTo: contentInsetView.trailingAnchor),
            
            descriptionLabel.topAnchor.constraint(equalTo: verticalStackView.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentInsetView.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentInsetView.trailingAnchor),

            descriptionSkeletonView.topAnchor.constraint(equalTo: verticalStackView.bottomAnchor, constant: 12),
            descriptionSkeletonView.leadingAnchor.constraint(equalTo: contentInsetView.leadingAnchor),
            descriptionSkeletonView.widthAnchor.constraint(equalToConstant: 220),
            descriptionSkeletonView.heightAnchor.constraint(equalToConstant: 16),

            metadataStackView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 16),
            metadataStackView.leadingAnchor.constraint(equalTo: contentInsetView.leadingAnchor),
            metadataStackView.bottomAnchor.constraint(equalTo: contentInsetView.bottomAnchor),

            profileImageContainerView.widthAnchor.constraint(equalToConstant: 80),
            profileImageContainerView.heightAnchor.constraint(equalToConstant: 80),
            profileImageHaloView.centerXAnchor.constraint(equalTo: profileImageContainerView.centerXAnchor),
            profileImageHaloView.centerYAnchor.constraint(equalTo: profileImageContainerView.centerYAnchor),
            profileImageHaloView.widthAnchor.constraint(equalToConstant: 88),
            profileImageHaloView.heightAnchor.constraint(equalToConstant: 88),
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
            emailSkeletonView.widthAnchor.constraint(equalToConstant: 132),
            emailSkeletonView.heightAnchor.constraint(equalToConstant: 16),
            emailSkeletonView.bottomAnchor.constraint(equalTo: emailContainerView.bottomAnchor, constant: -1),
        ])

        badgeContainerView.heightAnchor.constraint(equalToConstant: 24).isActive = true

        badgeLoadedConstraints = [
            badgeScrollView.topAnchor.constraint(equalTo: badgeContainerView.topAnchor),
            badgeScrollView.leadingAnchor.constraint(equalTo: badgeContainerView.leadingAnchor),
            badgeScrollView.trailingAnchor.constraint(equalTo: badgeContainerView.trailingAnchor),
            badgeScrollView.bottomAnchor.constraint(equalTo: badgeContainerView.bottomAnchor),
            badgeStackView.topAnchor.constraint(equalTo: badgeScrollView.contentLayoutGuide.topAnchor),
            badgeStackView.leadingAnchor.constraint(equalTo: badgeScrollView.contentLayoutGuide.leadingAnchor),
            badgeStackView.trailingAnchor.constraint(equalTo: badgeScrollView.contentLayoutGuide.trailingAnchor),
            badgeStackView.bottomAnchor.constraint(equalTo: badgeScrollView.contentLayoutGuide.bottomAnchor),
            badgeStackView.heightAnchor.constraint(equalTo: badgeScrollView.frameLayoutGuide.heightAnchor)
        ]

        badgeLoadingConstraints = [
            badgeSkeletonView.centerYAnchor.constraint(equalTo: badgeContainerView.centerYAnchor),
            badgeSkeletonView.leadingAnchor.constraint(equalTo: badgeContainerView.leadingAnchor),
            badgeSkeletonView.widthAnchor.constraint(equalToConstant: 96),
            badgeSkeletonView.heightAnchor.constraint(equalToConstant: 22)
        ]

        NSLayoutConstraint.activate(badgeLoadedConstraints)
        isBadgeLoadingLayoutActive = false
    }

    private func configureBadgeTitles(_ badgeTitles: [String]) {
        badgeStackView.arrangedSubviews.forEach { arrangedSubview in
            badgeStackView.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }

        badgeTitles.prefix(1).forEach { badgeTitle in
            let badgeLabel = PaddingLabel(insets: UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10))
            badgeLabel.text = badgeTitle
            badgeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
            badgeLabel.lineBreakMode = .byTruncatingTail
            badgeLabel.numberOfLines = 1
            badgeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            badgeLabel.setContentHuggingPriority(.required, for: .horizontal)
            badgeLabel.textColor = .gpPrimaryLight
            badgeLabel.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.18)
            badgeLabel.layer.cornerRadius = 11
            badgeLabel.layer.masksToBounds = true
            badgeStackView.addArrangedSubview(badgeLabel)
        }
    }

    private func updateBadgeLoadingLayout(isLoading: Bool) {
        guard isBadgeLoadingLayoutActive != isLoading else { return }

        if isLoading {
            NSLayoutConstraint.deactivate(badgeLoadedConstraints)
            NSLayoutConstraint.activate(badgeLoadingConstraints)
        } else {
            NSLayoutConstraint.deactivate(badgeLoadingConstraints)
            NSLayoutConstraint.activate(badgeLoadedConstraints)
        }

        isBadgeLoadingLayoutActive = isLoading
    }
}

private final class SocialTasteRowView: UIView {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        return label
    }()

    private let secondaryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextSecondary
        label.textAlignment = .natural
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let disclosureImageView: UIImageView = {
        let imageView = UIImageView(
            image: UIImage(
                systemName: "chevron.forward",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            )
        )
        imageView.tintColor = .gpTextTertiary
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let isInteractive: Bool

    var actionButton: UIButton? {
        didSet {
            oldValue?.removeFromSuperview()
            guard let actionButton else { return }
            actionButton.backgroundColor = .clear
            actionButton.tintColor = .clear
            addSubview(actionButton)
            NSLayoutConstraint.activate([
                actionButton.topAnchor.constraint(equalTo: topAnchor),
                actionButton.leadingAnchor.constraint(equalTo: leadingAnchor),
                actionButton.trailingAnchor.constraint(equalTo: trailingAnchor),
                actionButton.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
    }

    init(systemImageName: String, title: String, tintColor: UIColor, isInteractive: Bool = true) {
        self.isInteractive = isInteractive
        super.init(frame: .zero)
        titleLabel.text = title
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSecondaryText(_ text: String) {
        secondaryLabel.text = text
    }

    private func setup() {
        backgroundColor = .gpCardBackground
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.gpSeparator.withAlphaComponent(0.24).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        disclosureImageView.isHidden = !isInteractive

        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(UIView())
        contentStackView.addArrangedSubview(secondaryLabel)
        contentStackView.addArrangedSubview(disclosureImageView)

        addSubview(contentStackView)

        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),

            secondaryLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 156)
        ])
    }
}

private final class PaddingLabel: UILabel {

    private let insets: UIEdgeInsets

    init(insets: UIEdgeInsets) {
        self.insets = insets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}
