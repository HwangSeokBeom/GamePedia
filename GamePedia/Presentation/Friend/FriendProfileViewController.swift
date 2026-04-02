import UIKit

struct FriendProfileState {
    var isLoading = false
    var profile: FriendProfile?
    var errorMessage: String?
    var isLoadingRecommendations = false
    var recommendations: [FriendRecommendation] = []
    var recommendationsErrorMessage: String?
    var isManagingRelationship = false
    var relationshipErrorMessage: String?
}

enum FriendProfileIntent {
    case viewDidLoad
    case didTapRemoveFriend
    case didTapBlockUser
}

enum FriendProfileRoute {
    case didRemoveFriend
    case didBlockUser
}

final class FriendProfileViewModel {
    private(set) var state = FriendProfileState() { didSet { onStateChanged?(state) } }
    var onStateChanged: ((FriendProfileState) -> Void)?
    var onRoute: ((FriendProfileRoute) -> Void)?

    private let userID: String
    private let fetchFriendProfileUseCase: FetchFriendProfileUseCase
    private let removeFriendUseCase: RemoveFriendUseCase
    private let blockUserUseCase: BlockFriendUserUseCase

    init(
        userID: String,
        fetchFriendProfileUseCase: FetchFriendProfileUseCase = FetchFriendProfileUseCase(repository: DefaultFriendRepository()),
        removeFriendUseCase: RemoveFriendUseCase = RemoveFriendUseCase(repository: DefaultFriendRepository()),
        blockUserUseCase: BlockFriendUserUseCase = BlockFriendUserUseCase(repository: DefaultFriendRepository())
    ) {
        self.userID = userID
        self.fetchFriendProfileUseCase = fetchFriendProfileUseCase
        self.removeFriendUseCase = removeFriendUseCase
        self.blockUserUseCase = blockUserUseCase
    }

    func send(_ intent: FriendProfileIntent) {
        switch intent {
        case .viewDidLoad:
            loadProfile()
        case .didTapRemoveFriend:
            removeFriend()
        case .didTapBlockUser:
            blockUser()
        }
    }

    private func loadProfile() {
        state.isLoading = true
        state.isLoadingRecommendations = true
        state.recommendations = []
        state.recommendationsErrorMessage = nil
        Task {
            do {
                let profile = try await fetchFriendProfileUseCase.execute(userID: userID)
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.profile = profile
                    self.state.errorMessage = nil
                    self.state.isLoadingRecommendations = false
                    self.state.recommendations = profile.friendRecommendations
                    self.state.recommendationsErrorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.profile = nil
                    self.state.errorMessage = nil
                    self.state.isLoadingRecommendations = false
                    self.state.recommendations = []
                    self.state.recommendationsErrorMessage = nil
                }
            }
        }
    }

    private func removeFriend() {
        guard !state.isManagingRelationship else { return }
        state.isManagingRelationship = true
        state.relationshipErrorMessage = nil
        Task {
            do {
                try await removeFriendUseCase.execute(userID: userID)
                await MainActor.run {
                    self.state.isManagingRelationship = false
                    self.onRoute?(.didRemoveFriend)
                }
            } catch {
                await MainActor.run {
                    self.state.isManagingRelationship = false
                    self.state.relationshipErrorMessage = L10n.Friend.Profile.errorRemoveFailed
                }
            }
        }
    }

    private func blockUser() {
        guard !state.isManagingRelationship else { return }
        state.isManagingRelationship = true
        state.relationshipErrorMessage = nil
        Task {
            do {
                try await blockUserUseCase.execute(userID: userID)
                await MainActor.run {
                    self.state.isManagingRelationship = false
                    self.onRoute?(.didBlockUser)
                }
            } catch {
                await MainActor.run {
                    self.state.isManagingRelationship = false
                    self.state.relationshipErrorMessage = L10n.Friend.Profile.errorBlockFailed
                }
            }
        }
    }
}

final class FriendProfileViewController: BaseViewController<UIView, FriendProfileState> {
    private enum Section: Int, CaseIterable {
        case similarity
        case sharedGames
        case commonLiked
        case commonInterest
        case commonHighlyRated
        case recent
        case liked
        case reviews
        case recommendations

        var title: String {
            switch self {
            case .similarity: return L10n.Friend.Profile.sectionTaste
            case .sharedGames: return L10n.Friend.Profile.sectionSharedGames
            case .commonLiked: return L10n.Friend.Profile.sectionCommonLikedGames
            case .commonInterest: return L10n.Friend.Profile.sectionCommonInterestGames
            case .commonHighlyRated: return L10n.Friend.Profile.sectionCommonHighlyRatedGames
            case .recent: return L10n.Friend.Profile.sectionRecentlyPlayedGames
            case .liked: return L10n.Friend.Profile.sectionLikedGames
            case .reviews: return L10n.Friend.Profile.sectionReviews
            case .recommendations: return L10n.Friend.Profile.sectionRecommendations
            }
        }
    }

    private let viewModel: FriendProfileViewModel
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let loadingIndicatorView = UIActivityIndicatorView(style: .medium)
    private let emptyLabel = UILabel()
    private var profile: FriendProfile?
    private var isProfileLoading = false
    private var recommendationState = (isLoading: false, items: [FriendRecommendation](), errorMessage: String? .none)
    private var lastRelationshipErrorMessage: String?

    var onGameSelected: ((Int) -> Void)?
    var onReviewGameSelected: ((Int) -> Void)?

    init(userID: String) {
        self.viewModel = FriendProfileViewModel(userID: userID)
        super.init(rootView: UIView())
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        bind()
        viewModel.send(.viewDidLoad)
    }

    override func render(_ state: FriendProfileState) {
        profile = state.profile
        isProfileLoading = state.isLoading
        recommendationState = (
            isLoading: state.isLoadingRecommendations,
            items: state.recommendations,
            errorMessage: state.recommendationsErrorMessage
        )
        navigationItem.title = state.profile?.user.nickname ?? L10n.Friend.Profile.title
        state.isLoading ? loadingIndicatorView.startAnimating() : loadingIndicatorView.stopAnimating()
        tableView.reloadData()
        emptyLabel.isHidden = true
        emptyLabel.text = nil
        updateManagementButton()

        if let errorMessage = state.relationshipErrorMessage,
           errorMessage != lastRelationshipErrorMessage {
            lastRelationshipErrorMessage = errorMessage
            let alert = UIAlertController(title: L10n.Common.Error.title, message: errorMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.Common.Button.confirm, style: .default))
            present(alert, animated: true)
        } else if state.relationshipErrorMessage == nil {
            lastRelationshipErrorMessage = nil
        }
    }

    private func setup() {
        rootView.backgroundColor = .gpBackground
        tableView.backgroundColor = .gpBackground
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(FriendGamePreviewCell.self, forCellReuseIdentifier: FriendGamePreviewCell.reuseID)
        tableView.register(FriendReviewPreviewCell.self, forCellReuseIdentifier: FriendReviewPreviewCell.reuseID)
        tableView.register(FriendTasteSummaryCell.self, forCellReuseIdentifier: FriendTasteSummaryCell.reuseID)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FriendInfoCell")
        tableView.tableHeaderView = makeHeaderView()

        emptyLabel.font = .systemFont(ofSize: 15, weight: .medium)
        emptyLabel.textColor = .gpTextSecondary
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        loadingIndicatorView.color = .gpPrimary
        loadingIndicatorView.translatesAutoresizingMaskIntoConstraints = false

        [tableView, emptyLabel, loadingIndicatorView].forEach { rootView.addSubview($0) }

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: rootView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: rootView.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -24),

            loadingIndicatorView.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            loadingIndicatorView.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
    }

    private func bind() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async { self?.render(state) }
        }

        viewModel.onRoute = { [weak self] route in
            guard let self else { return }
            switch route {
            case .didRemoveFriend:
                NotificationCenter.default.post(
                    name: .friendRelationshipDidChange,
                    object: nil,
                    userInfo: [
                        FriendRelationshipChangeUserInfoKey.userID: self.profile?.user.id ?? "",
                        FriendRelationshipChangeUserInfoKey.action: FriendRelationshipChangeAction.removed.rawValue
                    ]
                )
                self.showCompletionAlert(message: L10n.Friend.Profile.successRemoved)
            case .didBlockUser:
                NotificationCenter.default.post(
                    name: .friendRelationshipDidChange,
                    object: nil,
                    userInfo: [
                        FriendRelationshipChangeUserInfoKey.userID: self.profile?.user.id ?? "",
                        FriendRelationshipChangeUserInfoKey.action: FriendRelationshipChangeAction.blocked.rawValue
                    ]
                )
                self.showCompletionAlert(message: L10n.Friend.Profile.successBlocked)
            }
        }
    }

    private func makeHeaderView() -> UIView {
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 132))
        containerView.backgroundColor = .gpBackground

        let cardView = UIView()
        cardView.backgroundColor = .gpCardBackground
        cardView.layer.cornerRadius = 20
        cardView.translatesAutoresizingMaskIntoConstraints = false

        let avatarView = UIImageView()
        avatarView.tag = 101
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 28
        avatarView.backgroundColor = .gpSurface
        avatarView.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.tag = 102
        nameLabel.font = .systemFont(ofSize: 20, weight: .bold)
        nameLabel.textColor = .gpTextPrimary

        let bioLabel = UILabel()
        bioLabel.tag = 103
        bioLabel.font = .systemFont(ofSize: 13)
        bioLabel.textColor = .gpTextSecondary
        bioLabel.numberOfLines = 2

        let textStack = UIStackView(arrangedSubviews: [nameLabel, bioLabel])
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(cardView)
        cardView.addSubview(avatarView)
        cardView.addSubview(textStack)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            cardView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),

            avatarView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            avatarView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 56),
            avatarView.heightAnchor.constraint(equalToConstant: 56),

            textStack.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            textStack.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
        ])
        return containerView
    }

    private func updateHeader() {
        guard let headerView = tableView.tableHeaderView,
              let avatarView = headerView.viewWithTag(101) as? UIImageView,
              let nameLabel = headerView.viewWithTag(102) as? UILabel,
              let bioLabel = headerView.viewWithTag(103) as? UILabel else { return }

        avatarView.loadImage(url: profile?.user.profileImageURL, placeholder: UIImage(systemName: "person.fill"))
        nameLabel.text = profile?.user.nickname
        bioLabel.text = profile?.user.bio ?? L10n.Friend.Profile.bioEmpty
        tableView.tableHeaderView = headerView
    }

    private func updateManagementButton() {
        guard let relationshipStatus = profile?.user.relationshipStatus, relationshipStatus != .self else {
            navigationItem.rightBarButtonItem = nil
            return
        }

        let menu = UIMenu(children: managementActions(for: relationshipStatus))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            menu: menu
        )
        navigationItem.rightBarButtonItem?.isEnabled = !viewModel.state.isManagingRelationship
    }

    private func managementActions(for relationshipStatus: FriendRelationshipStatus) -> [UIAction] {
        var actions: [UIAction] = []
        if relationshipStatus == .friends {
            actions.append(
                UIAction(title: L10n.Friend.Action.remove, image: UIImage(systemName: "person.crop.circle.badge.minus"), attributes: .destructive) { [weak self] _ in
                    self?.confirmRemoveFriend()
                }
            )
        }
        actions.append(
            UIAction(title: L10n.Friend.Action.block, image: UIImage(systemName: "hand.raised.fill"), attributes: .destructive) { [weak self] _ in
                self?.confirmBlockUser()
            }
        )
        return actions
    }

    private func confirmRemoveFriend() {
        let alert = UIAlertController(
            title: L10n.Friend.Profile.alertRemoveTitle,
            message: L10n.Friend.Profile.alertRemoveMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.Friend.Action.remove, style: .destructive) { [weak self] _ in
            self?.viewModel.send(.didTapRemoveFriend)
        })
        present(alert, animated: true)
    }

    private func confirmBlockUser() {
        let alert = UIAlertController(
            title: L10n.Friend.Profile.alertBlockTitle,
            message: L10n.Friend.Profile.alertBlockMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.Friend.Action.block, style: .destructive) { [weak self] _ in
            self?.viewModel.send(.didTapBlockUser)
        })
        present(alert, animated: true)
    }

    private func showCompletionAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.Common.Button.confirm, style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}

extension FriendProfileViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        updateHeader()
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .similarity:
            return 1
        case .sharedGames:
            guard let profile else { return 1 }
            return max(min(profile.sharedGames.count, 3), profile.sharedGames.isEmpty ? 1 : 0)
        case .commonLiked:
            guard let profile else { return 1 }
            return max(min(profile.commonLikedGames.count, 3), profile.commonLikedGames.isEmpty ? 1 : 0)
        case .commonInterest:
            guard let profile else { return 1 }
            return max(min(profile.commonInterestGames.count, 3), profile.commonInterestGames.isEmpty ? 1 : 0)
        case .commonHighlyRated:
            guard let profile else { return 1 }
            return max(min(profile.commonHighlyRatedGames.count, 3), profile.commonHighlyRatedGames.isEmpty ? 1 : 0)
        case .recent:
            guard let profile else { return 1 }
            return max(min(profile.recentlyPlayed.count, 3), profile.recentlyPlayed.isEmpty ? 1 : 0)
        case .liked:
            guard let profile else { return 1 }
            return max(min(profile.likedGames.count, 3), profile.likedGames.isEmpty ? 1 : 0)
        case .reviews:
            guard let profile else { return 1 }
            return max(min(profile.writtenReviews.count, 3), profile.writtenReviews.isEmpty ? 1 : 0)
        case .recommendations:
            if recommendationState.isLoading || recommendationState.items.isEmpty {
                return 1
            }
            return min(recommendationState.items.count, 3)
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch section {
        case .similarity:
            guard let profile else {
                return emptyCell(message: isProfileLoading ? L10n.Friend.Profile.loadingTaste : L10n.Friend.Profile.emptyTaste)
            }
            let title = profile.tasteProfile?.highlightTitle ?? profile.tasteSimilarity?.titleText ?? L10n.Friend.Profile.tasteFallbackTitle
            let summary = profile.tasteProfile?.summaryText ?? profile.tasteSimilarity?.summaryText ?? L10n.Friend.Profile.tasteFallbackSummary
            let chips = profile.tasteProfile?.displayChips ?? []
            guard profile.tasteProfile != nil || profile.tasteSimilarity != nil else {
                return emptyCell(message: L10n.Friend.Profile.emptyTaste)
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: FriendTasteSummaryCell.reuseID, for: indexPath) as! FriendTasteSummaryCell
            cell.configure(title: title, summary: summary, chips: chips)
            return cell
        case .sharedGames:
            if isProfileLoading && profile == nil {
                return emptyCell(message: L10n.Friend.Profile.loadingSharedGames)
            }
            guard let profile else {
                return emptyCell(message: L10n.Friend.Profile.emptySharedGames)
            }
            if profile.steamFriendsContext?.isLimitedByPrivacy == true {
                return emptyCell(message: L10n.Friend.Profile.emptySharedGamesPrivate)
            }
            guard !profile.sharedGames.isEmpty else {
                return emptyCell(message: L10n.Friend.Profile.emptySharedGames)
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: FriendGamePreviewCell.reuseID, for: indexPath) as! FriendGamePreviewCell
            let sharedGame = profile.sharedGames[indexPath.row]
            cell.configure(game: sharedGame.game, subtitleOverride: sharedGame.reasonText)
            return cell
        case .commonLiked:
            if isProfileLoading && profile == nil {
                return emptyCell(message: L10n.Friend.Profile.loadingCommonLikedGames)
            }
            guard let profile, !profile.commonLikedGames.isEmpty else {
                return emptyCell(message: L10n.Friend.Profile.emptyCommonLikedGames)
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: FriendGamePreviewCell.reuseID, for: indexPath) as! FriendGamePreviewCell
            cell.configure(game: profile.commonLikedGames[indexPath.row])
            return cell
        case .commonInterest:
            if isProfileLoading && profile == nil {
                return emptyCell(message: L10n.Friend.Profile.loadingCommonInterestGames)
            }
            guard let profile, !profile.commonInterestGames.isEmpty else {
                return emptyCell(message: L10n.Friend.Profile.emptyCommonInterestGames)
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: FriendGamePreviewCell.reuseID, for: indexPath) as! FriendGamePreviewCell
            cell.configure(game: profile.commonInterestGames[indexPath.row])
            return cell
        case .commonHighlyRated:
            if isProfileLoading && profile == nil {
                return emptyCell(message: L10n.Friend.Profile.loadingCommonHighlyRatedGames)
            }
            guard let profile, !profile.commonHighlyRatedGames.isEmpty else {
                return emptyCell(message: L10n.Friend.Profile.emptyCommonHighlyRatedGames)
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: FriendGamePreviewCell.reuseID, for: indexPath) as! FriendGamePreviewCell
            cell.configure(game: profile.commonHighlyRatedGames[indexPath.row])
            return cell
        case .recent:
            if isProfileLoading && profile == nil {
                return emptyCell(message: L10n.Friend.Profile.loadingRecentlyPlayedGames)
            }
            guard let profile, !profile.recentlyPlayed.isEmpty else {
                return emptyCell(message: L10n.Friend.Profile.emptyRecentlyPlayedGames)
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: FriendGamePreviewCell.reuseID, for: indexPath) as! FriendGamePreviewCell
            cell.configure(recentGame: profile.recentlyPlayed[indexPath.row])
            return cell
        case .liked:
            if isProfileLoading && profile == nil {
                return emptyCell(message: L10n.Friend.Profile.loadingLikedGames)
            }
            guard let profile, !profile.likedGames.isEmpty else {
                return emptyCell(message: L10n.Friend.Profile.emptyLikedGames)
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: FriendGamePreviewCell.reuseID, for: indexPath) as! FriendGamePreviewCell
            cell.configure(game: profile.likedGames[indexPath.row])
            return cell
        case .reviews:
            if isProfileLoading && profile == nil {
                return emptyCell(message: L10n.Friend.Profile.loadingReviews)
            }
            guard let profile, !profile.writtenReviews.isEmpty else {
                return emptyCell(message: L10n.Friend.Profile.emptyReviews)
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: FriendReviewPreviewCell.reuseID, for: indexPath) as! FriendReviewPreviewCell
            cell.configure(review: profile.writtenReviews[indexPath.row])
            return cell
        case .recommendations:
            if recommendationState.isLoading || (isProfileLoading && profile == nil) {
                return emptyCell(message: L10n.Friend.Profile.loadingRecommendations)
            }
            if recommendationState.items.isEmpty {
                return emptyCell(message: L10n.Friend.Profile.emptyRecommendations)
            }
            let recommendation = recommendationState.items[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: FriendGamePreviewCell.reuseID, for: indexPath) as! FriendGamePreviewCell
            cell.configure(game: recommendation.game, subtitleOverride: recommendation.reasonText)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section), let profile else { return }
        switch section {
        case .similarity:
            return
        case .sharedGames:
            guard profile.sharedGames.indices.contains(indexPath.row) else { return }
            onGameSelected?(profile.sharedGames[indexPath.row].game.id)
        case .commonLiked:
            guard profile.commonLikedGames.indices.contains(indexPath.row) else { return }
            onGameSelected?(profile.commonLikedGames[indexPath.row].id)
        case .commonInterest:
            guard profile.commonInterestGames.indices.contains(indexPath.row) else { return }
            onGameSelected?(profile.commonInterestGames[indexPath.row].id)
        case .commonHighlyRated:
            guard profile.commonHighlyRatedGames.indices.contains(indexPath.row) else { return }
            onGameSelected?(profile.commonHighlyRatedGames[indexPath.row].id)
        case .recent:
            guard profile.recentlyPlayed.indices.contains(indexPath.row) else { return }
            onGameSelected?(profile.recentlyPlayed[indexPath.row].gameId)
        case .liked:
            guard profile.likedGames.indices.contains(indexPath.row) else { return }
            onGameSelected?(profile.likedGames[indexPath.row].id)
        case .reviews:
            guard profile.writtenReviews.indices.contains(indexPath.row),
                  let gameID = profile.writtenReviews[indexPath.row].gameID else { return }
            onReviewGameSelected?(gameID)
        case .recommendations:
            guard recommendationState.items.indices.contains(indexPath.row) else { return }
            onGameSelected?(recommendationState.items[indexPath.row].game.id)
        }
    }

    private func emptyCell(message: String) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = .clear
        cell.textLabel?.text = message
        cell.textLabel?.textColor = .gpTextSecondary
        cell.textLabel?.font = .systemFont(ofSize: 14)
        cell.selectionStyle = .none
        return cell
    }
}
