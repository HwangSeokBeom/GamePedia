import Foundation

protocol PushTokenRemoteDataSource {
    func savePushToken(_ requestDTO: PushTokenRequestDTO) async throws
    func deletePushToken(deviceId: String) async throws
    func deletePushToken(deviceId: String, accessToken: String) async throws
}

final class DefaultPushTokenRemoteDataSource: PushTokenRemoteDataSource {
    private let apiClient: APIClient
    private let baseURL: URL
    private let session: URLSession

    init(
        apiClient: APIClient = .shared,
        baseURL: URL = AppConfig.authBaseURL,
        session: URLSession = .shared
    ) {
        self.apiClient = apiClient
        self.baseURL = baseURL
        self.session = session
    }

    func savePushToken(_ requestDTO: PushTokenRequestDTO) async throws {
        print(
            "[FCM] token save request platform=\(requestDTO.platform) " +
            "environment=\(requestDTO.environment) deviceIdLength=\(requestDTO.deviceId.count)"
        )
        try await apiClient.requestVoid(.savePushToken(body: requestDTO))
    }

    func deletePushToken(deviceId: String) async throws {
        print("[FCM] token delete request deviceIdLength=\(deviceId.count)")
        try await apiClient.requestVoid(.deletePushToken(deviceId: deviceId))
    }

    func deletePushToken(deviceId: String, accessToken: String) async throws {
        guard accessToken.isEmpty == false else {
            throw NetworkError.unauthorized
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("/users/me/push-token"),
            resolvingAgainstBaseURL: true
        )
        components?.queryItems = [URLQueryItem(name: "deviceId", value: deviceId)]

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = Endpoint.HTTPMethod.DELETE.rawValue
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(URLError(.badServerResponse))
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 || httpResponse.statusCode == 419 {
                throw NetworkError.unauthorized
            }
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, code: nil, message: nil)
        }
    }
}
