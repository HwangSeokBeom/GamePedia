import Foundation

// MARK: - AuthService
// Manages the Twitch client_credentials OAuth token for IGDB.
//
// Uses Swift `actor` for automatic thread safety — no manual locking needed.
// Token is cached in memory and refreshed when missing or expired.

actor AuthService {

    // MARK: Singleton
    static let shared = AuthService()

    // MARK: Cached State
    private var cachedToken: String? = nil
    private var tokenExpiresAt: Date? = nil

    // MARK: Dependencies
    private let session: URLSession

    // MARK: Init
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public Interface

    /// Returns a valid token, fetching a new one if the cache is empty or expired.
    func validToken() async throws -> String {
        if let token = cachedToken,
           let expiresAt = tokenExpiresAt,
           Date() < expiresAt {
            return token
        }
        return try await fetchNewToken()
    }

    // MARK: - Private

    private func fetchNewToken() async throws -> String {
        var request = URLRequest(url: AppConfig.twitchTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // client_credentials flow — no user scope required
        let bodyString = [
            "client_id=\(AppConfig.twitchClientID)",
            "client_secret=\(AppConfig.twitchClientSecret)",
            "grant_type=client_credentials"
        ].joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(URLError(.badServerResponse))
        }
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(
                statusCode: httpResponse.statusCode,
                code: nil,
                message: "Twitch token request failed"
            )
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let dto = try decoder.decode(AuthTokenDTO.self, from: data)

        // Cache with a 60-second safety buffer before actual expiry
        cachedToken = dto.accessToken
        tokenExpiresAt = Date().addingTimeInterval(TimeInterval(dto.expiresIn - 60))

        return dto.accessToken
    }
}
