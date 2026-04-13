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
            let bodyString = urlRequest.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            print("[ReviewSubmit] APIClient.request url=\(urlRequest.url?.absoluteString ?? "nil") method=\(urlRequest.httpMethod ?? "nil") headers=\(urlRequest.allHTTPHeaderFields ?? [:]) body=\(bodyString)")
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
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            print("[Notifications] rawResponse endpoint=/users/me/notifications status=\(httpResponse.statusCode) body=\(responseBody)")
        }
        if isFriendActivityRequest, let httpResponse = response as? HTTPURLResponse {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            print("[FriendActivity] rawResponse endpoint=/users/me/friends/activity status=\(httpResponse.statusCode) body=\(responseBody)")
        }
        if isLibraryStatusRequest, let httpResponse = response as? HTTPURLResponse {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            print("[Library] rawResponse endpoint=/users/me/library/status status=\(httpResponse.statusCode) body=\(responseBody)")
        }
        if isLibraryPreviewRequest, let httpResponse = response as? HTTPURLResponse {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            print("[Library] rawResponse endpoint=/users/me/library status=\(httpResponse.statusCode) body=\(responseBody)")
        }
        if isProfileSummaryRequest, let httpResponse = response as? HTTPURLResponse {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            print("[Profile] rawResponse endpoint=/users/me status=\(httpResponse.statusCode) body=\(responseBody)")
        }
        if isProfileRecentPlaysRequest, let httpResponse = response as? HTTPURLResponse {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            print("[Profile] rawResponse endpoint=/users/me/recent-plays status=\(httpResponse.statusCode) body=\(responseBody)")
        }
        if endpoint.path.contains("/reviews"), let httpResponse = response as? HTTPURLResponse {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            print("[ReviewSubmit] APIClient.response status=\(httpResponse.statusCode) body=\(responseBody)")
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
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                print("[GameAPI] decodeFailure type=\(String(describing: type)) error=\(error.localizedDescription) body=\(responseBody)")
            }
            if isNotificationsRequest {
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                print("[Notifications] decodeFailure endpoint=/users/me/notifications type=\(String(describing: type)) error=\(error) body=\(responseBody)")
            }
            if isFriendActivityRequest {
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                print("[FriendActivity] decodeFailure endpoint=/users/me/friends/activity type=\(String(describing: type)) error=\(error) body=\(responseBody)")
            }
            if isLibraryStatusRequest {
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                print("[Library] decodeFailure endpoint=/users/me/library/status type=\(String(describing: type)) error=\(error) body=\(responseBody)")
            }
            if isLibraryPreviewRequest {
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                print("[Library] decodeFailure endpoint=/users/me/library type=\(String(describing: type)) error=\(error) body=\(responseBody)")
            }
            if isProfileSummaryRequest {
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                print("[Profile] decodeFailure endpoint=/users/me type=\(String(describing: type)) error=\(error) body=\(responseBody)")
            }
            if isProfileRecentPlaysRequest {
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                print("[Profile] decodeFailure endpoint=/users/me/recent-plays type=\(String(describing: type)) error=\(error) body=\(responseBody)")
            }
            throw error
        }
    }

    func requestVoid(_ endpoint: Endpoint) async throws {
        let urlRequest = try await buildRequest(from: endpoint)
        if endpoint.path.contains("/reviews") {
            let bodyString = urlRequest.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            print("[ReviewSubmit] APIClient.requestVoid url=\(urlRequest.url?.absoluteString ?? "nil") method=\(urlRequest.httpMethod ?? "nil") headers=\(urlRequest.allHTTPHeaderFields ?? [:]) body=\(bodyString)")
        }
        let (data, response) = try await session.data(for: urlRequest)
        if endpoint.path.contains("/reviews"), let httpResponse = response as? HTTPURLResponse {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            print("[ReviewSubmit] APIClient.responseVoid status=\(httpResponse.statusCode) body=\(responseBody)")
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
}
