import Foundation

// MARK: - APIErrorResponse

private struct APIErrorResponse: Decodable {
    let message: String
}

private struct APIErrorDetail: Decodable {
    let code: String?
    let message: String?
}

private struct APIErrorEnvelope: Decodable {
    let message: String?
    let error: APIErrorDetail?
}

// MARK: - APIClient
//
// All game/auth/review/favorite/translation requests are routed through
// GamePediaCoreServer or other app backend endpoints. The iOS client no longer
// talks to IGDB directly or performs Twitch token exchange on-device.

final class APIClient {
    private static let verboseNetworkBodyLogs = false

    // MARK: Singleton
    static let shared = APIClient(baseURL: AppConfig.authBaseURL)

    // MARK: Properties
    private let baseURL: URL
    private let session: URLSession

    // MARK: User auth token (separate from Twitch token)
    // TODO: Set this after user login, e.g. from Keychain
    var userAuthToken: String? = nil

    // MARK: Init
    init(
        baseURL: URL = AppConfig.authBaseURL,
        session: URLSession? = nil
    ) {
        self.baseURL = baseURL
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 60
            self.session = URLSession(configuration: configuration)
        }
    }

    // MARK: - Public Interface

    /// Executes an endpoint and decodes the JSON response into type T.
    func request<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        let urlRequest = try await buildRequest(from: endpoint)
        let isGameRequest = endpoint.path.hasPrefix("/games")
        let homeEndpointName = homeEndpointName(for: endpoint.path)
        let homeLogPrefix = "[HomeAPI][\(AppConfig.apiEnvironment.rawValue)]"
        let isLibraryStatusRequest = endpoint.path == "/users/me/library/status"
        let isLibraryPreviewRequest = endpoint.path == "/users/me/library"
        let isNotificationsRequest = endpoint.path == "/users/me/notifications"
        let isFriendActivityRequest = endpoint.path == "/users/me/friends/activity"
        let isProfileSummaryRequest = endpoint.path == "/users/me"
        let isProfileRecentPlaysRequest = endpoint.path == "/users/me/recent-plays"
        let isAIRecommendationRequest = endpoint.path == "/api/v1/ai/game-recommendations"
        let isLibraryCuratorRequest = endpoint.path == "/api/v1/ai/library-curator"
        let aiReviewSummaryGameId = aiReviewSummaryGameId(for: endpoint.path)
        if let homeEndpointName {
            print(
                "\(homeLogPrefix) endpoint=\(homeEndpointName) " +
                "url=\(urlRequest.url?.absoluteString ?? "nil") method=\(urlRequest.httpMethod ?? "nil")"
            )
        }
        if isGameRequest {
            print("[GameAPI] request url=\(urlRequest.url?.absoluteString ?? "nil") method=\(urlRequest.httpMethod ?? "nil")")
        }
        if endpoint.path.contains("/reviews") {
            let bodyString = requestBodyPreview(from: urlRequest.httpBody)
            print("[ReviewSubmit] APIClient.request url=\(urlRequest.url?.absoluteString ?? "nil") method=\(urlRequest.httpMethod ?? "nil") headers=\(redactedHeaders(urlRequest.allHTTPHeaderFields)) bodyPrefix=\(bodyString)")
        }
        let (data, response) = try await session.data(for: urlRequest)
        if let homeEndpointName, let httpResponse = response as? HTTPURLResponse {
            print(
                "\(homeLogPrefix) endpoint=\(homeEndpointName) " +
                "url=\(urlRequest.url?.absoluteString ?? "nil") status=\(httpResponse.statusCode)"
            )
            print("\(homeLogPrefix) endpoint=\(homeEndpointName) bodyPrefix=\(responseBodyPreview(from: data))")
        }
        if isGameRequest, let httpResponse = response as? HTTPURLResponse {
            print("[GameAPI] response status=\(httpResponse.statusCode) url=\(urlRequest.url?.absoluteString ?? "nil")")
        }
        if isNotificationsRequest, let httpResponse = response as? HTTPURLResponse {
            let responseBody = networkBodyForLog(from: data)
            print("[Notifications] rawResponse endpoint=/users/me/notifications status=\(httpResponse.statusCode) body=\(responseBody)")
        }
        if isFriendActivityRequest, let httpResponse = response as? HTTPURLResponse {
            let responseBody = networkBodyForLog(from: data)
            print("[FriendActivity] rawResponse endpoint=/users/me/friends/activity status=\(httpResponse.statusCode) body=\(responseBody)")
        }
        if isLibraryStatusRequest, let httpResponse = response as? HTTPURLResponse {
            let responseBody = networkBodyForLog(from: data)
            print("[Library] rawResponse endpoint=/users/me/library/status status=\(httpResponse.statusCode) body=\(responseBody)")
        }
        if isLibraryPreviewRequest, let httpResponse = response as? HTTPURLResponse {
            let responseBody = networkBodyForLog(from: data)
            print("[Library] rawResponse endpoint=/users/me/library status=\(httpResponse.statusCode) body=\(responseBody)")
        }
        if isProfileSummaryRequest, let httpResponse = response as? HTTPURLResponse {
            print("[Profile] response endpoint=/users/me status=\(httpResponse.statusCode)")
        }
        if isProfileRecentPlaysRequest, let httpResponse = response as? HTTPURLResponse {
            print("[Profile] response endpoint=/users/me/recent-plays status=\(httpResponse.statusCode)")
        }
        if endpoint.path.contains("/reviews"), let httpResponse = response as? HTTPURLResponse {
            print("[ReviewSubmit] APIClient.response status=\(httpResponse.statusCode)")
        }
        if isAIRecommendationRequest, let httpResponse = response as? HTTPURLResponse {
            print(
                "[AIRecommendation] httpResponse " +
                "endpoint=/api/v1/ai/game-recommendations " +
                "statusCode=\(httpResponse.statusCode) " +
                "bodyPreview=\(responseBodyPreview(from: data))"
            )
        }
        if isLibraryCuratorRequest, let httpResponse = response as? HTTPURLResponse {
            print(
                "[LibraryCurator] httpResponse " +
                "endpoint=/api/v1/ai/library-curator " +
                "statusCode=\(httpResponse.statusCode) " +
                "bodyPreview=\(responseBodyPreview(from: data))"
            )
        }
        if let aiReviewSummaryGameId, let httpResponse = response as? HTTPURLResponse {
            print(
                "[AIReviewSummary] httpResponse " +
                "gameId=\(aiReviewSummaryGameId) " +
                "statusCode=\(httpResponse.statusCode) " +
                "bodyPreview=\(responseBodyPreview(from: data))"
            )
        }
        try validate(response: response, data: data)
        do {
            let decoded: T = try decode(data, as: type)
            if let homeEndpointName {
                print(
                    "\(homeLogPrefix) endpoint=\(homeEndpointName) " +
                    "decodeSuccess type=\(String(describing: type))"
                )
            }
            if isGameRequest {
                print("[GameAPI] decodeSuccess type=\(String(describing: type))")
            }
            if isAIRecommendationRequest {
                print("[AIRecommendation] decodeSuccess type=\(String(describing: type))")
            }
            if isLibraryCuratorRequest {
                print("[LibraryCurator] decodeSuccess type=\(String(describing: type))")
            }
            if let aiReviewSummaryGameId {
                print("[AIReviewSummary] decodeSuccess gameId=\(aiReviewSummaryGameId) type=\(String(describing: type))")
            }
            if let httpResponse = response as? HTTPURLResponse {
                logDecodedSummaryIfNeeded(
                    decoded,
                    endpoint: endpoint,
                    statusCode: httpResponse.statusCode
                )
            }
            return decoded
        } catch {
            if let homeEndpointName {
                print(
                    "\(homeLogPrefix) endpoint=\(homeEndpointName) " +
                    "decodeError=\(error)"
                )
                print("\(homeLogPrefix) endpoint=\(homeEndpointName) bodyPrefix=\(responseBodyPreview(from: data))")
            }
            if isGameRequest {
                let responseBody = networkBodyForLog(from: data)
                print("[GameAPI] decodeFailure type=\(String(describing: type)) error=\(error.localizedDescription) body=\(responseBody)")
            }
            if isNotificationsRequest {
                let responseBody = networkBodyForLog(from: data)
                print("[Notifications] decodeFailure endpoint=/users/me/notifications type=\(String(describing: type)) error=\(error) body=\(responseBody)")
            }
            if isFriendActivityRequest {
                let responseBody = networkBodyForLog(from: data)
                print("[FriendActivity] decodeFailure endpoint=/users/me/friends/activity type=\(String(describing: type)) error=\(error) body=\(responseBody)")
            }
            if isLibraryStatusRequest {
                let responseBody = networkBodyForLog(from: data)
                print("[Library] decodeFailure endpoint=/users/me/library/status type=\(String(describing: type)) error=\(error) body=\(responseBody)")
            }
            if isLibraryPreviewRequest {
                let responseBody = networkBodyForLog(from: data)
                print("[Library] decodeFailure endpoint=/users/me/library type=\(String(describing: type)) error=\(error) body=\(responseBody)")
            }
            if isProfileSummaryRequest {
                let responseBody = networkBodyForLog(from: data)
                print("[Profile] decodeFailure endpoint=/users/me type=\(String(describing: type)) error=\(error) body=\(responseBody)")
            }
            if isProfileRecentPlaysRequest {
                let responseBody = networkBodyForLog(from: data)
                print("[Profile] decodeFailure endpoint=/users/me/recent-plays type=\(String(describing: type)) error=\(error) body=\(responseBody)")
            }
            if let aiReviewSummaryGameId {
                print(
                    "[AIReviewSummary] decodeFailed " +
                    "gameId=\(aiReviewSummaryGameId) " +
                    "error=\(error) " +
                    "bodyPreview=\(responseBodyPreview(from: data))"
                )
            }
            if isAIRecommendationRequest {
                print(
                    "[AIRecommendation] decodeFailure " +
                    "type=\(String(describing: type)) " +
                    "error=\(error) " +
                    "bodyPreview=\(responseBodyPreview(from: data))"
                )
            }
            if isLibraryCuratorRequest {
                print(
                    "[LibraryCurator] decodeFailure " +
                    "type=\(String(describing: type)) " +
                    "error=\(error) " +
                    "bodyPreview=\(responseBodyPreview(from: data))"
                )
            }
            throw error
        }
    }

    func requestVoid(_ endpoint: Endpoint) async throws {
        let urlRequest = try await buildRequest(from: endpoint)
        if endpoint.path.contains("/reviews") {
            let bodyString = requestBodyPreview(from: urlRequest.httpBody)
            print("[ReviewSubmit] APIClient.requestVoid url=\(urlRequest.url?.absoluteString ?? "nil") method=\(urlRequest.httpMethod ?? "nil") headers=\(redactedHeaders(urlRequest.allHTTPHeaderFields)) bodyPrefix=\(bodyString)")
        }
        let (data, response) = try await session.data(for: urlRequest)
        if endpoint.path.contains("/reviews"), let httpResponse = response as? HTTPURLResponse {
            print("[ReviewSubmit] APIClient.responseVoid status=\(httpResponse.statusCode)")
        }
        try validate(response: response, data: data)
    }

    // MARK: - Private: Request Builder

    private func buildRequest(from endpoint: Endpoint) async throws -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: true
        )

        if !endpoint.queryItems.isEmpty {
            components?.queryItems = endpoint.queryItems
        }

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        // Body encoding — drives Content-Type
        switch endpoint.body {
        case .none:
            break

        case .json(let encodable):
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(encodable)
        }

        // Optional user JWT for custom backend endpoints
        if endpoint.requiresUserAuth {
            guard let userToken = userAuthToken else {
                throw NetworkError.unauthorized
            }
            request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    // MARK: - Private: Validation

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw NetworkError.unauthorized
        default:
            let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            let plainMessage = try? JSONDecoder().decode(APIErrorResponse.self, from: data).message
            let code = envelope?.error?.code
            let message = envelope?.error?.message ?? envelope?.message ?? plainMessage
            if httpResponse.statusCode == 429 {
                throw NetworkError.rateLimited(
                    statusCode: httpResponse.statusCode,
                    code: code,
                    message: message
                )
            }
            throw NetworkError.serverError(
                statusCode: httpResponse.statusCode,
                code: code,
                message: message
            )
        }
    }

    // MARK: - Private: Decoding

    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(type, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }

    private func responseBodyPreview(from data: Data, maxLength: Int = 240) -> String {
        let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        let normalizedBody = rawBody.replacingOccurrences(of: "\n", with: " ")
        guard normalizedBody.count > maxLength else { return normalizedBody }
        let endIndex = normalizedBody.index(normalizedBody.startIndex, offsetBy: maxLength)
        return "\(normalizedBody[..<endIndex])..."
    }

    private func networkBodyForLog(from data: Data) -> String {
        if Self.verboseNetworkBodyLogs {
            return String(data: data, encoding: .utf8) ?? "<non-utf8>"
        }
        return responseBodyPreview(from: data)
    }

    private func requestBodyPreview(from data: Data?) -> String {
        guard let data else { return "" }
        return responseBodyPreview(from: data, maxLength: 250)
    }

    private func logDecodedSummaryIfNeeded<T>(
        _ decoded: T,
        endpoint: Endpoint,
        statusCode: Int
    ) {
        if endpoint.path == "/users/me",
           let response = decoded as? CurrentUserProfileResponseDTO {
            let profile = response.profile
            print(
                "[Profile] decoded " +
                "status=\(statusCode) " +
                "userId=\(profile.id) " +
                "nickname=\(profile.name) " +
                "reviewCount=\(profile.writtenReviewCount) " +
                "favoriteCount=\(profile.wishlistCount)"
            )
            return
        }

        if endpoint.path == "/users/me/recent-plays",
           let response = decoded as? RecentGameListResponseDTO {
            print(
                "[Profile] decoded " +
                "status=\(statusCode) " +
                "recentPlayCount=\(response.recentGames.count) " +
                "hasMore=\(response.hasMoreRecentPlayed ?? false)"
            )
            return
        }

        guard endpoint.path.contains("/reviews") else { return }

        if let response = decoded as? ReviewResponseEnvelopeDTO<MyReviewsResponseDataDTO> {
            print("[ReviewSubmit] response status=\(statusCode) reviewCount=\(response.data.reviews.count) sort=\(reviewSortQueryValue(from: endpoint) ?? "nil")")
        } else if let response = decoded as? ReviewResponseEnvelopeDTO<ReviewListResponseDataDTO> {
            print("[ReviewSubmit] response status=\(statusCode) reviewCount=\(response.data.reviews.count) sort=\(reviewSortQueryValue(from: endpoint) ?? "nil")")
        } else if let response = decoded as? ReviewResponseEnvelopeDTO<ReviewObjectResponseDataDTO> {
            print("[ReviewSubmit] response status=\(statusCode) reviewId=\(response.data.review.id)")
        } else if let response = decoded as? ReviewResponseEnvelopeDTO<DeleteReviewResponseDataDTO> {
            print("[ReviewSubmit] response status=\(statusCode) deleted=\(response.data.deleted) reviewId=\(response.data.reviewId)")
        } else if let response = decoded as? ReviewResponseEnvelopeDTO<ReviewLikeResponseDataDTO> {
            print("[ReviewSubmit] response status=\(statusCode) reviewId=\(response.data.reviewId) likeCount=\(response.data.likeCount)")
        }
    }

    private func reviewSortQueryValue(from endpoint: Endpoint) -> String? {
        endpoint.queryItems.first { $0.name == "sort" }?.value
    }

    private func redactedHeaders(_ headers: [String: String]?) -> [String: String] {
        guard let headers else { return [:] }
        return headers.reduce(into: [:]) { result, pair in
            let normalizedKey = pair.key.lowercased()
            if normalizedKey == "authorization"
                || normalizedKey.contains("token")
                || normalizedKey.contains("cookie") {
                result[pair.key] = "<redacted>"
            } else {
                result[pair.key] = pair.value
            }
        }
    }

    private func homeEndpointName(for path: String) -> String? {
        switch path {
        case "/games/highlights":
            return "highlights"
        case "/games/popular":
            return "popular"
        case "/games/recommended":
            return "recommended"
        default:
            return nil
        }
    }

    private func aiReviewSummaryGameId(for path: String) -> String? {
        let pattern = #"^/api/v1/ai/games/([^/]+)/review-summary$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
              let range = Range(match.range(at: 1), in: path) else {
            return nil
        }
        return String(path[range])
    }
}
