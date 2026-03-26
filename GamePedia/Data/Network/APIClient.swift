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
// Requests are routed by Endpoint.Service.
// - IGDB uses Twitch auth headers
// - backend uses the app backend base URL
//
// For backend endpoints, requiresUserAuth controls whether a user-level JWT
// is attached. User JWT is separate from the Twitch token.

final class APIClient {

    // MARK: Singleton
    static let shared = APIClient()

    // MARK: Properties
    private let session: URLSession
    private let authService: AuthService

    // MARK: User auth token (separate from Twitch token)
    // TODO: Set this after user login, e.g. from Keychain
    var userAuthToken: String? = nil

    // MARK: Init
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.authService = .shared
    }

    // MARK: - Public Interface

    /// Executes an endpoint and decodes the JSON response into type T.
    /// IGDB auth headers are automatically injected.
    func request<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        let urlRequest = try await buildRequest(from: endpoint)
        if endpoint.path.contains("/reviews") {
            let bodyString = urlRequest.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            print("[ReviewSubmit] APIClient.request url=\(urlRequest.url?.absoluteString ?? "nil") method=\(urlRequest.httpMethod ?? "nil") headers=\(urlRequest.allHTTPHeaderFields ?? [:]) body=\(bodyString)")
        }
        let (data, response) = try await session.data(for: urlRequest)
        if endpoint.path.contains("/reviews"), let httpResponse = response as? HTTPURLResponse {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            print("[ReviewSubmit] APIClient.response status=\(httpResponse.statusCode) body=\(responseBody)")
        }
        try validate(response: response, data: data)
        return try decode(data, as: type)
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
        let baseURL: URL
        switch endpoint.service {
        case .igdb:
            baseURL = AppConfig.igdbBaseURL
        case .backend:
            baseURL = AppConfig.authBaseURL
        }
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

        if endpoint.service == .igdb {
            let twitchToken = try await authService.validToken()
            request.setValue(AppConfig.twitchClientID, forHTTPHeaderField: "Client-ID")
            request.setValue("Bearer \(twitchToken)", forHTTPHeaderField: "Authorization")
        }

        // Body encoding — drives Content-Type
        switch endpoint.body {
        case .none:
            break

        case .igdbQuery(let queryString):
            // IGDB uses text/plain for Apicalypse queries
            request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            request.httpBody = queryString.data(using: .utf8)

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
}
