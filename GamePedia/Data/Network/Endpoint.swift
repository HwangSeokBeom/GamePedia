import Foundation

// MARK: - Endpoint

struct Endpoint {
    // MARK: Body type — drives Content-Type header and httpBody encoding
    enum Body {
        /// No request body (GET requests)
        case none
        /// JSON-encoded body for custom backend endpoints
        case json(any Encodable)
    }

    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]
    let body: Body
    /// When true, attaches the user-level JWT for authenticated backend endpoints.
    let requiresUserAuth: Bool

    enum HTTPMethod: String {
        case GET, POST, PUT, PATCH, DELETE
    }
}

// MARK: - Generic Factory Helpers

extension Endpoint {
    static func get(
        _ path: String,
        query: [URLQueryItem] = [],
        userAuth: Bool = false
    ) -> Endpoint {
        Endpoint(
            path: path,
            method: .GET,
            queryItems: query,
            body: .none,
            requiresUserAuth: userAuth
        )
    }

    static func post<T: Encodable>(
        _ path: String,
        body: T,
        userAuth: Bool = true
    ) -> Endpoint {
        Endpoint(
            path: path,
            method: .POST,
            queryItems: [],
            body: .json(body),
            requiresUserAuth: userAuth
        )
    }

    static func post(
        _ path: String,
        userAuth: Bool = true
    ) -> Endpoint {
        Endpoint(
            path: path,
            method: .POST,
            queryItems: [],
            body: .none,
            requiresUserAuth: userAuth
        )
    }

    static func delete(
        _ path: String,
        query: [URLQueryItem] = [],
        userAuth: Bool = true
    ) -> Endpoint {
        Endpoint(
            path: path,
            method: .DELETE,
            queryItems: query,
            body: .none,
            requiresUserAuth: userAuth
        )
    }

    static func patch<T: Encodable>(
        _ path: String,
        body: T,
        userAuth: Bool = true
    ) -> Endpoint {
        Endpoint(
            path: path,
            method: .PATCH,
            queryItems: [],
            body: .json(body),
            requiresUserAuth: userAuth
        )
    }
}

// MARK: - Game Endpoints
// Routed through GamePediaCoreServer IGDB proxy endpoints.

extension Endpoint {

    static func highlightGames(limit: Int = 10) -> Endpoint {
        .get("/games/highlights", query: [
            URLQueryItem(name: "limit", value: "\(limit)")
        ])
    }

    static var featuredGame: Endpoint {
        highlightGames(limit: 1)
    }

    static func popularGames(limit: Int = 10) -> Endpoint {
        .get("/games/popular", query: [
            URLQueryItem(name: "limit", value: "\(limit)")
        ])
    }

    static func recommendedGames(limit: Int = 10) -> Endpoint {
        .get("/games/recommended", query: [
            URLQueryItem(name: "limit", value: "\(limit)")
        ])
    }

    static func latestGames(limit: Int = 10) -> Endpoint {
        recommendedGames(limit: limit)
    }

    static func searchGames(query: String, genre: String? = nil, limit: Int = 20) -> Endpoint {
        _ = genre
        return .get("/games/search", query: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)")
        ])
    }

    static func gameDetail(id: Int) -> Endpoint {
        .get("/games/\(id)")
    }
}

// MARK: - Review Endpoints

extension Endpoint {
    static func createReview(body: CreateReviewRequestDTO) -> Endpoint {
        .post("/reviews", body: body, userAuth: true)
    }

    static func gameReviews(gameId: String, sort: String? = nil) -> Endpoint {
        let queryItems = sort.map { [URLQueryItem(name: "sort", value: $0)] } ?? []
        return .get("/games/\(gameId)/reviews", query: queryItems, userAuth: true)
    }

    static func updateReview(reviewId: String, body: UpdateReviewRequestDTO) -> Endpoint {
        .patch("/reviews/\(reviewId)", body: body, userAuth: true)
    }

    static func deleteReview(reviewId: String) -> Endpoint {
        .delete("/reviews/\(reviewId)", userAuth: true)
    }

    static func myReviews(sort: String? = nil) -> Endpoint {
        let queryItems = sort.map { [URLQueryItem(name: "sort", value: $0)] } ?? []
        return .get("/users/me/reviews", query: queryItems, userAuth: true)
    }
}

// MARK: - Favorite Endpoints

extension Endpoint {
    static func addFavorite(body: AddFavoriteRequestDTO) -> Endpoint {
        .post("/favorites", body: body, userAuth: true)
    }

    static func removeFavorite(gameId: String) -> Endpoint {
        .delete("/favorites/\(gameId)", userAuth: true)
    }

    static func myFavorites(sort: String? = nil) -> Endpoint {
        let queryItems = sort.map { [URLQueryItem(name: "sort", value: $0)] } ?? []
        return .get("/users/me/favorites", query: queryItems, userAuth: true)
    }

    static func favoriteStatus(gameId: String) -> Endpoint {
        .get("/games/\(gameId)/favorite-status", userAuth: true)
    }
}

// MARK: - User Endpoints

extension Endpoint {
    static var myProfile: Endpoint {
        .get("/users/me", userAuth: true)
    }

    static func recentPlays(limit: Int = 20) -> Endpoint {
        .get("/users/me/recent-plays", query: [
            URLQueryItem(name: "limit", value: "\(limit)")
        ], userAuth: true)
    }
}

// MARK: - Library Endpoints

extension Endpoint {
    static func myLibrary(sort: String? = nil) -> Endpoint {
        let queryItems = sort.map { [URLQueryItem(name: "sort", value: $0)] } ?? []
        return .get("/users/me/library", query: queryItems, userAuth: true)
    }

    static var mySteamLinkStatus: Endpoint {
        .get("/users/me/steam", userAuth: true)
    }

    static var startSteamLink: Endpoint {
        .post("/users/me/library/steam/link", userAuth: true)
    }

    static var unlinkSteamLink: Endpoint {
        .delete("/users/me/library/steam/link", userAuth: true)
    }

    static var syncOwnedSteamLibrary: Endpoint {
        .post("/users/me/library/steam/sync-owned", userAuth: true)
    }

    static var myOwnedLibrary: Endpoint {
        .get("/users/me/library/owned", userAuth: true)
    }

    static var myPlayingLibrary: Endpoint {
        .get("/users/me/library/playing", userAuth: true)
    }

    static var myRecentlyPlayedLibrary: Endpoint {
        .get("/users/me/library/recently-played", userAuth: true)
    }

    static var mySteamFriendRecommendations: Endpoint {
        .get("/users/me/recommendations/steam-friends", userAuth: true)
    }

    static var myPlaytimeRecommendations: Endpoint {
        .get("/users/me/recommendations/playtime-based", userAuth: true)
    }

    static func updateLibraryStatus(body: UpdateLibraryStatusRequestDTO) -> Endpoint {
        .post("/users/me/library/status", body: body, userAuth: true)
    }
}
