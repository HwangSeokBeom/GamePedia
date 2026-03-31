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
    private let fetchMyReviewsUseCase: FetchMyReviewsUseCase
    private let fetchMyFavoritesUseCase: FetchMyFavoritesUseCase
    private let fetchSteamLinkStatusUseCase: FetchSteamLinkStatusUseCase
    private let logoutUseCase: LogoutUseCase
    private let deleteAccountUseCase: DeleteAccountUseCase
    private let unlinkSteamAccountUseCase: UnlinkSteamAccountUseCase
    private let userSessionStore: any UserSessionStore
    private let apiClient: APIClient
    private let translateTextUseCase: TranslateTextUseCase
    private var cancellables = Set<AnyCancellable>()

    // MARK: Init
    init(
        fetchCurrentUserUseCase: FetchCurrentUserUseCase,
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
        translateTextUseCase: TranslateTextUseCase? = nil
    ) {
        self.fetchCurrentUserUseCase = fetchCurrentUserUseCase
        self.fetchMyReviewsUseCase = fetchMyReviewsUseCase
        self.fetchMyFavoritesUseCase = fetchMyFavoritesUseCase
        self.fetchSteamLinkStatusUseCase = fetchSteamLinkStatusUseCase
        self.logoutUseCase = logoutUseCase
        self.deleteAccountUseCase = deleteAccountUseCase
        self.unlinkSteamAccountUseCase = unlinkSteamAccountUseCase
        self.userSessionStore = userSessionStore
        self.apiClient = apiClient
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
            loadProfileData()
        case .didTapEditProfile:
            onRoute?(.showEditProfile)
        case .didTapSteamUnlink:
            unlinkSteamAccount()
        case .didTapLogout:
            logout()
        case .didTapDeleteAccount:
            deleteAccount()
        case .didTapWrittenReviews:
            onRoute?(.showWrittenReviews)
        case .didTapFavoriteGames:
            onRoute?(.showFavoriteGames)
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
        case .didTapSettings, .didTapGame, .didTapSeeMoreRecentPlay:
            break
        }
    }

    // MARK: - Private

    private func apply(_ mutation: ProfileMutation) {
        state = ProfileReducer.reduce(state, mutation)
    }

    private func loadProfileData() {
        apply(.setLoading(true))
        apply(.clearError)

        if let authenticatedUser = userSessionStore.fetchUser() {
            apply(.setAuthenticatedUser(authenticatedUser))
        }

        fetchAuthenticatedUser()

        Task {
            await fetchRecentGames()
        }

        Task {
            await fetchWrittenReviewCount()
        }

        Task {
            await fetchWishlistCount()
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
                            self.apply(.setError(error.errorDescription ?? "프로필 정보를 불러오지 못했습니다."))
                        }
                    }
                },
                receiveValue: { [weak self] authenticatedUser in
                    self?.apply(.setAuthenticatedUser(authenticatedUser))
                }
            )
            .store(in: &cancellables)
    }

    private func fetchRecentGames() async {
        do {
            let response = try await apiClient.request(.recentPlays(), as: RecentGameListResponseDTO.self)
            let games = response.recentGames.map { UserProfileMapper.toRecentGameEntity($0) }
            let translatedGames = await translateRecentGames(games)
            await MainActor.run {
                self.apply(.setRecentGames(translatedGames))
            }
        } catch {
            // Recent games failing silently — basic auth profile still shows
        }
    }

    private func fetchWrittenReviewCount() async {
        do {
            let reviews = try await fetchMyReviewsUseCase.execute(sort: .latest)
            await MainActor.run {
                self.apply(.setWrittenReviewCount(reviews.count))
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

    private func observeReviewChanges() {
        NotificationCenter.default.publisher(for: .reviewDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.userSessionStore.fetchUser() != nil else { return }
                Task {
                    await self.fetchWrittenReviewCount()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .favoriteDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.userSessionStore.fetchUser() != nil else { return }
                Task {
                    await self.fetchWishlistCount()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .currentUserProfileDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, let user = self.userSessionStore.fetchUser() else { return }
                self.apply(.setAuthenticatedUser(user))
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
                                ?? "회원 탈퇴를 처리하지 못했습니다. 잠시 후 다시 시도해주세요."
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
                    self.apply(.setSteamLinkStatus(result.steamLinkStatus))
                    self.apply(.setSuccessMessage("Steam 연동이 해제되었어요"))
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
                    self.apply(.setError(libraryError.errorDescription ?? "Steam 연동을 해제하지 못했어요."))
                }
            }
        }
    }

    private func translateRecentGames(_ games: [RecentGame]) async -> [RecentGame] {
        guard !games.isEmpty else { return games }

        let titleItems = games.compactMap { game -> TranslationRequestItem? in
            guard game.translatedTitle == nil else { return nil }
            return TranslationRequestItem(
                identifier: String(game.gameId),
                field: "title",
                text: game.title
            )
        }

        guard !titleItems.isEmpty else { return games }

        let results = await translateTextUseCase.execute(
            items: titleItems,
            context: "Profile.recentGames",
            sourceLanguage: "en"
        )
        let translatedTitles: [Int: String] = Dictionary(
            uniqueKeysWithValues: results.compactMap { result in
                guard let gameIdentifier = Int(result.identifier) else { return nil }
                return (gameIdentifier, result.translatedText)
            }
        )
        await MainActor.run {
            self.apply(.setTranslatedRecentGameTitles(translatedTitles))
        }

        return games.map { game in
            game.replacingTranslated(translatedTitle: translatedTitles[game.gameId])
        }
    }
}
