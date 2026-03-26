import Foundation

// MARK: - Endpoint

struct Endpoint {

    enum Service {
        case igdb
        case backend
    }

    // MARK: Body type — drives Content-Type header and httpBody encoding
    enum Body {
        /// No request body (GET requests)
        case none
        /// IGDB Apicalypse query sent as text/plain
        case igdbQuery(String)
        /// JSON-encoded body for custom backend endpoints
        case json(any Encodable)
    }

    let path: String
    let service: Service
    let method: HTTPMethod
    let queryItems: [URLQueryItem]
    let body: Body
    /// When true, also attaches the user-level JWT in addition to IGDB auth.
    /// IGDB Client-ID + Bearer are always added automatically.
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
            service: .backend,
            method: .GET,
            queryItems: query,
            body: .none,
            requiresUserAuth: userAuth
        )
    }

    static func igdb(_ path: String, query: String) -> Endpoint {
        Endpoint(
            path: path,
            service: .igdb,
            method: .POST,
            queryItems: [],
            body: .igdbQuery(query),
            requiresUserAuth: false
        )
    }

    static func post<T: Encodable>(
        _ path: String,
        body: T,
        userAuth: Bool = true
    ) -> Endpoint {
        Endpoint(
            path: path,
            service: .backend,
            method: .POST,
            queryItems: [],
            body: .json(body),
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
            service: .backend,
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
            service: .backend,
            method: .PATCH,
            queryItems: [],
            body: .json(body),
            requiresUserAuth: userAuth
        )
    }
}

// MARK: - IGDB Game Endpoints
// IGDB Apicalypse reference: https://api-docs.igdb.com/#apicalypse

extension Endpoint {

    /// Top-rated game with a cover — used as the featured banner on Home
    static var featuredGame: Endpoint {
        .igdb("/games", query: """
            fields name, summary, cover.url, genres.name, platforms.name, rating, rating_count, first_release_date;
            where cover != null & rating != null & rating_count > 100;
            sort rating desc;
            limit 1;
            """)
    }

    /// Popular games sorted by rating — Home horizontal scroll
    static func popularGames(limit: Int = 10) -> Endpoint {
        .igdb("/games", query: """
            fields name, summary, cover.url, genres.name, platforms.name, rating, rating_count, first_release_date;
            where cover != null & rating != null & rating_count > 50;
            sort rating desc;
            limit \(limit);
            """)
    }

    /// Trending games sorted by hype count — Home recommended scroll
    static func recommendedGames(limit: Int = 10) -> Endpoint {
        .igdb("/games", query: """
            fields name, summary, cover.url, genres.name, platforms.name, rating, rating_count, hypes, first_release_date;
            where cover != null & hypes != null;
            sort hypes desc;
            limit \(limit);
            """)
    }

    /// Latest releases for recommendation fallback and freshness scoring.
    static func latestGames(limit: Int = 10) -> Endpoint {
        .igdb("/games", query: """
            fields name, summary, cover.url, genres.name, platforms.name, rating, rating_count, hypes, first_release_date;
            where cover != null & first_release_date != null;
            sort first_release_date desc;
            limit \(limit);
            """)
    }

    /// Keyword search with optional genre filter
    static func searchGames(query: String, genre: String? = nil, limit: Int = 20) -> Endpoint {
        let apicalypse = """
            search "\(query)";
            fields name, summary, cover.url, genres.name, platforms.name, rating, rating_count, first_release_date;
            where cover != null;
            limit \(limit);
            """
        // TODO: Map Korean genre name → IGDB genre ID for proper filtering
        // IGDB genre filter uses numeric IDs, e.g.: where genres = (12) & cover != null;
        _ = genre  // reserved for future genre ID mapping
        return .igdb("/games", query: apicalypse)
    }

    /// Full game detail by IGDB game ID
    static func gameDetail(id: Int) -> Endpoint {
        .igdb("/games", query: """
            fields name, summary, cover.url, genres.name, platforms.name, rating,
                   rating_count, total_rating, screenshots.url, first_release_date,
                   involved_companies.company.name, involved_companies.developer;
            where id = \(id);
            limit 1;
            """)
    }

    static func games(ids: [Int]) -> Endpoint {
        let joinedIDs = ids.map(String.init).joined(separator: ",")
        return .igdb("/games", query: """
            fields name, summary, cover.url, genres.name, platforms.name, rating, rating_count, first_release_date;
            where id = (\(joinedIDs));
            limit \(ids.count);
            """)
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
