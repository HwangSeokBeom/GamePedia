import Combine
import Foundation

// MARK: - ProfileViewModel

final class ProfileViewModel {

    // MARK: State
    private(set) var state: ProfileState = ProfileState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((ProfileState) -> Void)?
    var onRoute: ((ProfileRoute) -> Void)?

    // MARK: Dependencies
    private let fetchCurrentUserUseCase: FetchCurrentUserUseCase
    private let fetchFriendsListUseCase: FetchFriendsListUseCase
    private let fetchMyReviewsUseCase: FetchMyReviewsUseCase
    private let fetchMyFavoritesUseCase: FetchMyFavoritesUseCase
    private let fetchSteamLinkStatusUseCase: FetchSteamLinkStatusUseCase
    private let logoutUseCase: LogoutUseCase
    private let deleteAccountUseCase: DeleteAccountUseCase
    private let unlinkSteamAccountUseCase: UnlinkSteamAccountUseCase
    private let userSessionStore: any UserSessionStore
    private let apiClient: APIClient
    private let translateTextUseCase: TranslateTextUseCase
    private let profileBadgeSelectionStore: ProfileBadgeSelectionStore
    private var cancellables = Set<AnyCancellable>()
    private var didTriggerInitialLoad = false

    // MARK: Init
    init(
        fetchCurrentUserUseCase: FetchCurrentUserUseCase,
        fetchFriendsListUseCase: FetchFriendsListUseCase = FetchFriendsListUseCase(
            repository: DefaultFriendRepository()
        ),
        fetchMyReviewsUseCase: FetchMyReviewsUseCase = FetchMyReviewsUseCase(
            reviewRepository: DefaultReviewRepository()
        ),
        fetchMyFavoritesUseCase: FetchMyFavoritesUseCase = FetchMyFavoritesUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        ),
        fetchSteamLinkStatusUseCase: FetchSteamLinkStatusUseCase = FetchSteamLinkStatusUseCase(
            libraryRepository: DefaultLibraryRepository()
        ),
        logoutUseCase: LogoutUseCase,
        deleteAccountUseCase: DeleteAccountUseCase,
        unlinkSteamAccountUseCase: UnlinkSteamAccountUseCase = UnlinkSteamAccountUseCase(
            libraryRepository: DefaultLibraryRepository()
        ),
        userSessionStore: any UserSessionStore,
        apiClient: APIClient = .shared,
        translateTextUseCase: TranslateTextUseCase? = nil,
        profileBadgeSelectionStore: ProfileBadgeSelectionStore = .shared
    ) {
        self.fetchCurrentUserUseCase = fetchCurrentUserUseCase
        self.fetchFriendsListUseCase = fetchFriendsListUseCase
        self.fetchMyReviewsUseCase = fetchMyReviewsUseCase
        self.fetchMyFavoritesUseCase = fetchMyFavoritesUseCase
        self.fetchSteamLinkStatusUseCase = fetchSteamLinkStatusUseCase
        self.logoutUseCase = logoutUseCase
        self.deleteAccountUseCase = deleteAccountUseCase
        self.unlinkSteamAccountUseCase = unlinkSteamAccountUseCase
        self.userSessionStore = userSessionStore
        self.apiClient = apiClient
        self.profileBadgeSelectionStore = profileBadgeSelectionStore
        self.translateTextUseCase = translateTextUseCase ?? DefaultTranslateTextUseCase(
            repository: DefaultTranslationRepository(),
            languageProvider: DefaultLanguageProvider.shared
        )
        observeReviewChanges()
    }

    // MARK: - Intent Processing

    func send(_ intent: ProfileIntent) {
        switch intent {
        case .viewDidLoad:
            print("[ProfileAction] intent=viewDidLoad")
            guard !didTriggerInitialLoad else {
                print("[ProfileAction] intent=viewDidLoad skipped reason=alreadyTriggered")
                return
            }
            didTriggerInitialLoad = true
            loadProfileData()
        case .didTapSettings:
            onRoute?(.showSettings)
        case .didTapEditProfile:
            onRoute?(.showEditProfile)
        case .didTapSteamUnlink:
            unlinkSteamAccount()
        case .didTapLogout:
            logout()
        case .didTapDeleteAccount:
            deleteAccount()
        case .didTapPlayedGamesStat:
            print("[Profile] playedStat intent received")
            print("[Profile] route emitted route=showPlayedGames")
            onRoute?(.showPlayedGames)
        case .didTapWrittenReviews:
            onRoute?(.showWrittenReviews)
        case .didTapFavoriteGames:
            onRoute?(.showFavoriteGames)
        case .didTapGame:
            break
        case .didTapFriendsList:
            onRoute?(.showFriendsList)
        case .didTapSteamFriends:
            onRoute?(.showSteamFriends)
        case .didTapFriendRequests:
            onRoute?(.showFriendRequests)
        case .didTapFriendSearch:
            onRoute?(.showFriendSearch)
        case .didTapFriendActivity:
            onRoute?(.showFriendActivity)
        case .didTapSocialPrivacySettings:
            onRoute?(.showSocialPrivacySettings)
        case .didTapTermsOfService:
            onRoute?(.showTermsOfService)
        case .didTapPrivacyPolicy:
            onRoute?(.showPrivacyPolicy)
        case .didTapCommunityGuidelines:
            onRoute?(.showCommunityGuidelines)
        case .didTapContactSupport:
            onRoute?(.contactSupport)
        case .didConsumeSuccessMessage:
            apply(.clearSuccessMessage)
        case .didTapSeeMoreRecentPlay:
            print("[Profile] recentPlay seeMore intent received count=\(state.recentlyPlayedGames.count)")
            print("[Profile] route emitted route=showRecentPlayList")
            onRoute?(.showRecentPlayList)
        }
    }

    // MARK: - Private

    private func apply(_ mutation: ProfileMutation) {
        let reducedState = ProfileReducer.reduce(state, mutation)
        guard reducedState != state else {
            print("[ProfileState] reducedSkipped mutation=\(mutation.logName) reason=unchanged")
            return
        }

        print("[ProfileState] reduced mutation=\(mutation.logName)")
        state = reducedState
    }

    private func loadProfileData() {
        print("[Profile] fetchStarted source=initial")
        apply(.setLoading(true))
        apply(.clearError)
        if state.recentlyPlayedGames.isEmpty {
            apply(.setRecentPlayLoadState(.loading))
        } else {
            print("[Profile] recentPlay loading skipped reason=existingVisibleData")
        }

        if let authenticatedUser = userSessionStore.fetchUser() {
            apply(.setAuthenticatedUser(authenticatedUser))
            refreshSelectedBadges()
        }

        fetchAuthenticatedUser()

        Task {
            await fetchProfileSummary()
        }

        Task {
            await fetchWrittenReviewCount()
        }

        Task {
            await fetchWishlistCount()
        }

        Task {
            await fetchFriendCount()
        }

        Task {
            await fetchSteamLinkStatus()
        }
    }

    private func fetchAuthenticatedUser() {
        fetchCurrentUserUseCase.execute()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }

                    if case .failure(let error) = completion {
                        if self.handleProtectedSessionFailure(error) {
                            return
                        }

                        if self.state.authenticatedUser == nil {
                            self.apply(.setError(error.errorDescription ?? L10n.tr("Localizable", "profile.error.loadFailed")))
                        }
                    }
                },
                receiveValue: { [weak self] authenticatedUser in
                    self?.apply(.setAuthenticatedUser(authenticatedUser))
                    self?.refreshSelectedBadges()
                }
            )
            .store(in: &cancellables)
    }

    private func fetchProfileSummary() async {
        do {
            let response = try await apiClient.request(.myProfile, as: CurrentUserProfileResponseDTO.self)
            print(
                "[Profile] dto received " +
                "selectedTitle=\(response.profile.selectedTitle ?? "nil") " +
                "selectedTitles=\(response.profile.selectedTitles) " +
                "explicitSelected=\(response.profile.explicitSelected.map(String.init(describing:)) ?? "nil") " +
                "availableTitles=\(response.profile.availableTitles.count) " +
                "recentPlayedPreview=\(response.profile.recentPlayedPreview.count) " +
                "recentPlayedCount=\(response.profile.recentPlayedCount) " +
                "recentPlayedSource=\(response.profile.recentPlayedSource ?? "nil")"
            )
            response.profile.recentPlayedPreview.forEach { game in
                print(
                    "[RecentPlayDecode] " +
                    "screen=Profile.summary " +
                    "title=\(game.title) " +
                    "recentPlaytimeMinutes=\(game.recentPlaytimeMinutes.map(String.init) ?? "nil") " +
                    "lastPlayedAt=\(game.lastPlayedAt) " +
                    "hasReliableLastPlayedAt=\(game.hasReliableLastPlayedAt.map(String.init) ?? "nil") " +
                    "lastPlayedAtSource=\(game.lastPlayedAtSource ?? "nil") " +
                    "fallbackReason=\(game.fallbackReason ?? "nil")"
                )
            }
            let profileSummary = UserProfileMapper.toEntity(response.profile)
            let selectedTitleKey = self.profileBadgeSelectionStore.selectedTitleKey(for: profileSummary.resolvedBadgeTitle)
            print(
                "[Profile] entity mapped " +
                "selectedTitle=\(profileSummary.selectedTitle ?? "nil") " +
                "selectedTitleKey=\(selectedTitleKey ?? "nil") " +
                "selectedTitles=\(profileSummary.selectedTitles) " +
                "explicitSelected=\(profileSummary.explicitSelected.map(String.init(describing:)) ?? "nil") " +
                "availableTitles=\(profileSummary.availableTitles.count) " +
                "profileTags=\(profileSummary.profileTags.count) " +
                "recentPlayedPreview=\(profileSummary.recentPlayedPreview.count) " +
                "recentPlayedCount=\(profileSummary.recentPlayedCount) " +
                "recentPlayedSource=\(profileSummary.recentPlayedSource ?? "nil") " +
                "friendCount=\(profileSummary.friendCount)"
            )

            await MainActor.run {
                self.apply(.setProfileSummary(profileSummary))
                self.apply(.setFriendActivityCount(0))
                if profileSummary.recentPlayedPreview.isEmpty == false {
                    let mergedPreviewGames = self.mergeRecentGames(
                        current: self.state.recentlyPlayedGames,
                        incoming: Array(profileSummary.recentPlayedPreview.prefix(5)),
                        screen: "Profile.summaryPreview"
                    )
                    self.apply(.setRecentlyPlayedGames(mergedPreviewGames))
                    self.apply(.setHasMoreRecentPlayed(profileSummary.hasMoreRecentPlayed))
                    self.apply(.setRecentPlayLoadState(.loaded))
                }
                self.refreshSelectedBadges()
                print(
                    "[Profile] current selectedTitleKey from server = \(self.state.selectedTitleKey ?? "nil")"
                )
                print(
                    "[Profile] state emitted " +
                    "selectedTitle=\(self.state.selectedTitle ?? "nil") " +
                    "selectedTitleKey=\(self.state.selectedTitleKey ?? "nil") " +
                    "selectedTitles=\(self.state.selectedTitles) " +
                    "explicitSelected=\(self.state.hasExplicitSelectedTitles.map(String.init(describing:)) ?? "nil") " +
                    "recentPlayed=\(self.state.recentlyPlayedGames.count) " +
                    "friendCount=\(self.state.friendCount) " +
                    "friendActivityCount=\(self.state.friendActivityCount)"
                )
            }

            if profileSummary.recentPlayedPreview.isEmpty || profileSummary.hasMoreRecentPlayed {
                await fetchRecentGames(source: "dedicated")
            }
        } catch {
            print("[Profile] summary failed error=\(error.localizedDescription)")
            await fetchRecentGames(source: "fallback")
        }
    }

    private func fetchRecentGames(source: String) async {
        print("[Profile] recentPlay fetchStarted source=\(source)")
        do {
            let response = try await apiClient.request(.recentPlays(), as: RecentGameListResponseDTO.self)
            print(
                "[Profile] recent dto received " +
                "source=\(source) " +
                "count=\(response.recentGames.count) " +
                "hasMore=\(response.hasMoreRecentPlayed ?? false)"
            )
            response.recentGames.forEach { game in
                print(
                    "[RecentPlayDecode] " +
                    "screen=Profile.\(source).dto " +
                    "title=\(game.title) " +
                    "recentPlaytimeMinutes=\(game.recentPlaytimeMinutes.map(String.init) ?? "nil") " +
                    "lastPlayedAt=\(game.lastPlayedAt) " +
                    "hasReliableLastPlayedAt=\(game.hasReliableLastPlayedAt.map(String.init) ?? "nil") " +
                    "lastPlayedAtSource=\(game.lastPlayedAtSource ?? "nil") " +
                    "fallbackReason=\(game.fallbackReason ?? "nil")"
                )
            }
            let games = response.recentGames
                .map { UserProfileMapper.toRecentGameEntity($0) }
                .sorted { lhs, rhs in
                    switch (lhs.lastPlayedAt, rhs.lastPlayedAt) {
                    case let (lhsDate?, rhsDate?):
                        return lhsDate > rhsDate
                    case (.some, .none):
                        return true
                    case (.none, .some):
                        return false
                    case (.none, .none):
                        return lhs.gameId > rhs.gameId
                    }
                }
            let translatedGames = await translateRecentGames(
                mergeRecentGames(
                    current: self.state.recentlyPlayedGames,
                    incoming: Array(games.prefix(5)),
                    screen: "Profile.\(source)"
                )
            )
            print("[Profile] recentPlayedPreview mapped source=\(source) count=\(translatedGames.count)")
            await MainActor.run {
                if translatedGames.isEmpty, self.state.recentlyPlayedGames.isEmpty == false {
                    self.apply(.setRecentPlayLoadState(.loaded))
                    print(
                        "[Profile] recentPlayed empty response ignored " +
                        "existingCount=\(self.state.recentlyPlayedGames.count)"
                    )
                    return
                }

                self.apply(.setRecentlyPlayedGames(translatedGames))
                self.apply(.setHasMoreRecentPlayed(response.hasMoreRecentPlayed ?? false))
                self.apply(.setRecentPlayLoadState(translatedGames.isEmpty ? .empty : .loaded))
                self.refreshSelectedBadges()
            }
        } catch {
            print("[Profile] recentPlayed failed source=\(source) error=\(error.localizedDescription)")
            await MainActor.run {
                let loadState: ProfileRecentPlayLoadState = self.state.authenticatedUser == nil ? .failed : .partialFailure
                self.apply(.setRecentPlayLoadState(loadState))
            }
        }
    }

    private func mergeRecentGames(
        current: [RecentGame],
        incoming: [RecentGame],
        screen: String
    ) -> [RecentGame] {
        guard incoming.isEmpty == false else { return current }

        let currentByGameID = Dictionary(uniqueKeysWithValues: current.map { ($0.gameId, $0) })
        return incoming.map { incomingGame in
            guard let currentGame = currentByGameID[incomingGame.gameId] else { return incomingGame }

            let resolvedLastPlayedAt: Date?
            let resolvedLastPlayedAtSource: String?
            let resolvedHasReliableLastPlayedAt: Bool
            if incomingGame.hasReliableLastPlayedAt, let incomingLastPlayedAt = incomingGame.lastPlayedAt {
                resolvedLastPlayedAt = incomingLastPlayedAt
                resolvedLastPlayedAtSource = incomingGame.lastPlayedAtSource
                resolvedHasReliableLastPlayedAt = true
            } else {
                resolvedLastPlayedAt = currentGame.lastPlayedAt
                resolvedLastPlayedAtSource = currentGame.lastPlayedAtSource
                resolvedHasReliableLastPlayedAt = currentGame.hasReliableLastPlayedAt
            }

            let resolvedRecentPlaytimeMinutes = incomingGame.recentPlaytimeMinutes ?? currentGame.recentPlaytimeMinutes
            let resolvedFallbackReason = incomingGame.fallbackReason ?? currentGame.fallbackReason
            let display = RecentPlayMetadataFormatter.makeDisplay(
                lastPlayedAt: resolvedLastPlayedAt,
                hasReliableLastPlayedAt: resolvedHasReliableLastPlayedAt,
                recentPlaytimeMinutes: resolvedRecentPlaytimeMinutes,
                fallbackReason: resolvedFallbackReason
            )
            let resolvedFormattedLastPlayed = display.finalText
            let mergedGame = incomingGame.replacingRecentPlayMetadata(
                formattedLastPlayed: resolvedFormattedLastPlayed,
                lastPlayedAt: resolvedLastPlayedAt,
                lastPlayedAtSource: resolvedLastPlayedAtSource,
                hasReliableLastPlayedAt: resolvedHasReliableLastPlayedAt,
                recentPlaytimeMinutes: resolvedRecentPlaytimeMinutes,
                fallbackReason: resolvedFallbackReason
            )
            return mergedGame
        }
    }

    private func fetchWrittenReviewCount() async {
        do {
            let reviews = try await fetchMyReviewsUseCase.execute(sort: .latest)
            await MainActor.run {
                self.apply(.setWrittenReviewCount(reviews.count))
                self.refreshSelectedBadges()
            }
        } catch {
            let reviewError = ReviewError.from(error: error)
            if case .unauthorized = reviewError {
                await MainActor.run {
                    _ = self.handleProtectedSessionFailure(.unauthorized)
                }
            }
        }
    }

    private func fetchFriendCount() async {
        do {
            let friends = try await fetchFriendsListUseCase.execute()
            await MainActor.run {
                self.apply(.setFriendCount(friends.count))
                self.refreshSelectedBadges()
            }
        } catch {
            // Friend count failing silently — profile still renders.
        }
    }

    private func observeReviewChanges() {
        NotificationCenter.default.publisher(for: .reviewDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.userSessionStore.fetchUser() != nil else { return }
                print("[ProfileAction] notification=reviewDidChange")
                Task {
                    await self.fetchWrittenReviewCount()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .favoriteDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.userSessionStore.fetchUser() != nil else { return }
                print("[ProfileAction] notification=favoriteDidChange")
                Task {
                    await self.fetchWishlistCount()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .friendRelationshipDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.userSessionStore.fetchUser() != nil else { return }
                print("[ProfileAction] notification=friendRelationshipDidChange")
                Task {
                    await self.fetchFriendCount()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .currentUserProfileDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self, let user = self.userSessionStore.fetchUser() else { return }
                self.apply(.setAuthenticatedUser(user))
                let selectedTitleKey = notification.userInfo?[ProfileChangeUserInfoKey.selectedTitleKey] as? String
                let selectedTitle = notification.userInfo?[ProfileChangeUserInfoKey.selectedTitle] as? String
                print("[Profile] profileChanged selectedTitleKey=\(selectedTitleKey ?? "nil") selectedTitle=\(selectedTitle ?? "nil")")
                self.apply(.setSelectedTitleSelection(title: selectedTitle, key: selectedTitleKey))
                self.refreshSelectedBadges()
                Task {
                    await self.fetchProfileSummary()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .steamLinkDidComplete)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.userSessionStore.fetchUser() != nil else { return }
                Task {
                    await self.fetchSteamLinkStatus()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .steamLinkStateDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                if let isLinked = notification.userInfo?[SteamLinkStateChangeUserInfoKey.isLinked] as? Bool,
                   isLinked == false {
                    self.apply(.setSteamLinkStatus(.notLinked))
                    self.refreshSelectedBadges()
                }

                guard self.userSessionStore.fetchUser() != nil else { return }
                Task {
                    await self.fetchSteamLinkStatus()
                }
            }
            .store(in: &cancellables)
    }

    private func logout() {
        guard !state.isAccountActionInProgress else { return }
        apply(.clearError)
        apply(.setLoggingOut(true))
        logoutUseCase.execute()
        apply(.setLoggingOut(false))
        onRoute?(.loggedOut)
    }

    private func deleteAccount() {
        guard !state.isAccountActionInProgress else { return }

        apply(.clearError)
        apply(.setDeletingAccount(true))

        deleteAccountUseCase.execute()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.apply(.setDeletingAccount(false))

                    if case .failure(let error) = completion {
                        if self.handleProtectedSessionFailure(error) {
                            return
                        }
                        self.apply(
                            .setError(
                                error.errorDescription
                                ?? L10n.tr("Localizable", "profile.error.deleteAccountFailed")
                            )
                        )
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.onRoute?(.loggedOut)
                }
            )
            .store(in: &cancellables)
    }

    private func handleProtectedSessionFailure(_ error: AuthError) -> Bool {
        switch error {
        case .unauthorized, .tokenExpired:
            logoutUseCase.execute()
            onRoute?(.loggedOut)
            return true
        default:
            return false
        }
    }

    private func fetchWishlistCount() async {
        do {
            let favorites = try await fetchMyFavoritesUseCase.execute(sort: .latest)
            await MainActor.run {
                self.apply(.setWishlistCount(favorites.count))
                self.refreshSelectedBadges()
            }
        } catch {
            let favoriteError = FavoriteError.from(error: error)
            if case .unauthorized = favoriteError {
                await MainActor.run {
                    _ = self.handleProtectedSessionFailure(.unauthorized)
                }
            }
        }
    }

    private func fetchSteamLinkStatus() async {
        print("[Profile] steamLinkStatus fetchStarted")
        await MainActor.run {
            self.apply(.setLoadingSteamLinkStatus(true))
        }

        do {
            let steamLinkStatus = try await fetchSteamLinkStatusUseCase.execute()
            await MainActor.run {
                self.apply(.setSteamLinkStatus(steamLinkStatus))
            }
        } catch {
            let libraryError = LibraryError.from(error: error)
            if case .unauthorized = libraryError {
                await MainActor.run {
                    _ = self.handleProtectedSessionFailure(.unauthorized)
                }
                return
            }

            await MainActor.run {
                self.apply(.setLoadingSteamLinkStatus(false))
            }
        }
    }

    private func unlinkSteamAccount() {
        guard state.isSteamConnected else { return }
        guard !state.isUnlinkingSteamAccount else { return }

        apply(.clearError)
        apply(.clearSuccessMessage)
        apply(.setUnlinkingSteamAccount(true))

        Task {
            do {
                let result = try await unlinkSteamAccountUseCase.execute()
                await MainActor.run {
                    self.apply(.setUnlinkingSteamAccount(false))
                    LibraryCacheStore.shared.clear()
                    LibraryCacheStore.shared.clearSteamSyncDates()
                    self.apply(.setSteamLinkStatus(result.steamLinkStatus))
                    self.apply(.setSuccessMessage(L10n.tr("Localizable", "profile.success.unlinkSteam")))
                    NotificationCenter.default.post(
                        name: .steamLinkStateDidChange,
                        object: nil,
                        userInfo: [SteamLinkStateChangeUserInfoKey.isLinked: result.steamLinkStatus.isLinked]
                    )
                }
            } catch {
                let libraryError = LibraryError.from(error: error)
                await MainActor.run {
                    self.apply(.setUnlinkingSteamAccount(false))
                    if case .unauthorized = libraryError {
                        _ = self.handleProtectedSessionFailure(.unauthorized)
                        return
                    }
                    self.apply(.setError(libraryError.errorDescription ?? L10n.tr("Localizable", "profile.error.unlinkSteamFailed")))
                }
            }
        }
    }

    private func translateRecentGames(_ games: [RecentGame]) async -> [RecentGame] {
        games
    }

    private func refreshSelectedBadges() {
        let nextBadgeTitles: [String]
        if let selectedTitle = state.selectedTitle,
           selectedTitle.isEmpty == false {
            nextBadgeTitles = [selectedTitle]
        } else {
            nextBadgeTitles = []
        }

        guard nextBadgeTitles != state.selectedBadgeTitles else {
            print("[ProfileRender] selectedBadgeSkipped reason=unchanged")
            return
        }

        print("[ProfileRender] selectedBadgeUpdated reason=changed")
        apply(.setSelectedBadgeTitles(nextBadgeTitles))
    }
}
