import Foundation

struct FetchLibraryFriendRecommendationsUseCase {
    let libraryRepository: any LibraryRepository
    let friendRepository: any FriendRepository

    func execute(isSteamConnected: Bool = true) async throws -> LibraryFriendRecommendationsResult {
        let inAppRecommendationsResult = await captureResult {
            try await libraryRepository.fetchInAppFriendRecommendations()
        }

        if case .success(let recommendations) = inAppRecommendationsResult,
           !recommendations.isEmpty {
            print("[Library] friendRecommendations source=inAppFriends count=\(recommendations.count)")
            return LibraryFriendRecommendationsResult(
                recommendations: recommendations,
                source: .inAppFriends,
                emptyState: nil
            )
        }

        let friendsResult = await captureResult {
            try await friendRepository.fetchFriends()
        }

        let steamRecommendationsResult: Result<[SteamFriendRecommendation], Error>
        if isSteamConnected {
            steamRecommendationsResult = await captureResult {
                try await libraryRepository.fetchSteamFriendRecommendations()
            }
        } else {
            steamRecommendationsResult = .success([])
        }

        if case .success(let recommendations) = steamRecommendationsResult,
           !recommendations.isEmpty {
            print("[Library] friendRecommendations source=steamFriends count=\(recommendations.count)")
            return LibraryFriendRecommendationsResult(
                recommendations: recommendations,
                source: .steamFriends,
                emptyState: nil
            )
        }

        if case .failure(let error) = inAppRecommendationsResult {
            throw error
        }

        let hasInAppFriends = {
            if case .success(let friends) = friendsResult {
                return friends.isEmpty == false
            }
            return false
        }()

        let steamFriendsContext: Result<(friends: [SteamFriend], isAvailable: Bool, isLimitedByPrivacy: Bool, syncWarningCode: String?), Error>
        if isSteamConnected {
            steamFriendsContext = await captureResult {
                try await friendRepository.fetchSteamFriends()
            }
        } else {
            steamFriendsContext = .success(
                (friends: [], isAvailable: false, isLimitedByPrivacy: false, syncWarningCode: nil)
            )
        }
        let steamUnavailable = {
            if case .success(let steamFriends) = steamFriendsContext {
                return steamFriends.isLimitedByPrivacy
                    || steamFriends.syncWarningCode != nil
                    || steamFriends.isAvailable == false
            }
            return false
        }()

        let emptyState: LibraryFriendRecommendationsEmptyState
        if steamUnavailable {
            emptyState = .steamUnavailable
        } else if hasInAppFriends {
            emptyState = .insufficientActivity
        } else {
            emptyState = .noFriendData
        }

        print("[Library] friendRecommendations source=none emptyState=\(emptyState.rawValue)")
        return LibraryFriendRecommendationsResult(
            recommendations: [],
            source: .none,
            emptyState: emptyState
        )
    }

    private func captureResult<T>(_ operation: @escaping () async throws -> T) async -> Result<T, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }
}

struct FetchSteamFriendRecommendationsUseCase {
    let libraryRepository: any LibraryRepository

    func execute() async throws -> [SteamFriendRecommendation] {
        try await libraryRepository.fetchSteamFriendRecommendations()
    }
}
