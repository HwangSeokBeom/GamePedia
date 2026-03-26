import Foundation
import Combine

final class AuthRemoteDataSource {

    private let baseURL: URL
    private let urlSession: URLSession
    private let tokenStore: any TokenStore
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    init(
        baseURL: URL = AppConfig.authBaseURL,
        tokenStore: any TokenStore,
        urlSession: URLSession? = nil
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        if let urlSession {
            self.urlSession = urlSession
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 60
            self.urlSession = URLSession(configuration: configuration)
        }
        self.jsonEncoder = JSONEncoder()
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func login(requestDTO: LoginRequestDTO) -> AnyPublisher<AuthResponseDTO, AuthError> {
        performRequest(.login(requestDTO), responseType: AuthResponseDTO.self)
    }

    func forgotPassword(requestDTO: ForgotPasswordRequestDTO) -> AnyPublisher<ForgotPasswordResponseDataDTO, AuthError> {
        performRequest(.forgotPassword(requestDTO), responseType: ForgotPasswordResponseDataDTO.self)
    }

    func resetPassword(requestDTO: ResetPasswordRequestDTO) -> AnyPublisher<ResetPasswordResponseDataDTO, AuthError> {
        performRequest(.resetPassword(requestDTO), responseType: ResetPasswordResponseDataDTO.self)
    }

    func loginWithApple(requestDTO: AppleLoginRequestDTO) -> AnyPublisher<AuthResponseDTO, AuthError> {
        performRequest(.appleLogin(requestDTO), responseType: AuthResponseDTO.self)
    }

    func loginWithGoogle(requestDTO: GoogleLoginRequestDTO) -> AnyPublisher<AuthResponseDTO, AuthError> {
        performRequest(.googleLogin(requestDTO), responseType: AuthResponseDTO.self)
    }

    func signUp(requestDTO: SignUpRequestDTO) -> AnyPublisher<AuthResponseDTO, AuthError> {
        performRequest(.signUp(requestDTO), responseType: AuthResponseDTO.self)
    }

    func refreshSession(refreshToken: String) -> AnyPublisher<AuthResponseDTO, AuthError> {
        performRequest(
            .refresh(RefreshRequestDTO(refreshToken: refreshToken)),
            responseType: AuthResponseDTO.self
        )
    }

    func fetchCurrentUser() -> AnyPublisher<AuthUser, AuthError> {
        performRequest(.currentUser, responseType: AuthResponseDTO.self)
            .tryMap { try $0.toDomainUser() }
            .mapError { $0 as? AuthError ?? AuthError.unknown(message: $0.localizedDescription) }
            .eraseToAnyPublisher()
    }

    func logout(refreshToken: String?) -> AnyPublisher<Void, AuthError> {
        performVoidRequest(.logout(refreshToken.map { LogoutRequestDTO(refreshToken: $0) }))
    }

    func deleteAccount() -> AnyPublisher<Void, AuthError> {
        performVoidRequest(.deleteAccount)
    }

    private func performRequest<ResponseDTO: Decodable>(
        _ endpoint: AuthEndpoint,
        responseType: ResponseDTO.Type
    ) -> AnyPublisher<ResponseDTO, AuthError> {
        do {
            let urlRequest = try makeURLRequest(for: endpoint)
            return urlSession.dataTaskPublisher(for: urlRequest)
                .mapError { _ in AuthError.networkError }
                .tryMap { [weak self] data, response in
                    guard let self else { throw AuthError.invalidResponse }
                    return try self.decodeResponse(data: data, response: response, responseType: responseType)
                }
                .mapError { $0 as? AuthError ?? AuthError.unknown(message: $0.localizedDescription) }
                .eraseToAnyPublisher()
        } catch {
            let authError = error as? AuthError ?? .unknown(message: error.localizedDescription)
            return Fail(error: authError).eraseToAnyPublisher()
        }
    }

    private func performVoidRequest(_ endpoint: AuthEndpoint) -> AnyPublisher<Void, AuthError> {
        do {
            let urlRequest = try makeURLRequest(for: endpoint)
            return urlSession.dataTaskPublisher(for: urlRequest)
                .mapError { _ in AuthError.networkError }
                .tryMap { [weak self] data, response in
                    guard let self else { throw AuthError.invalidResponse }
                    try self.validateVoidResponse(data: data, response: response)
                    return ()
                }
                .mapError { $0 as? AuthError ?? AuthError.unknown(message: $0.localizedDescription) }
                .eraseToAnyPublisher()
        } catch {
            let authError = error as? AuthError ?? .unknown(message: error.localizedDescription)
            return Fail(error: authError).eraseToAnyPublisher()
        }
    }

    private func makeURLRequest(for endpoint: AuthEndpoint) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(endpoint.path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let httpBody = try endpoint.httpBody(using: jsonEncoder) {
            urlRequest.httpBody = httpBody
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if endpoint.requiresAuthorization {
            guard let accessToken = tokenStore.fetchAccessToken() else {
                throw AuthError.unauthorized
            }
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        print("[AuthNetwork] runtime=\(AppConfig.networkRuntimeDescription) baseURL=\(baseURL.absoluteString) requestURL=\(url.absoluteString) method=\(endpoint.method.rawValue)")

        if case .appleLogin(let requestDTO) = endpoint {
            print(
                """
                [AppleLogin] request sending \
                requestURL=\(url.absoluteString) \
                identityTokenExists=\(!requestDTO.identityToken.isEmpty) \
                identityTokenLength=\(requestDTO.identityToken.count) \
                deviceNameExists=\((requestDTO.deviceName?.isEmpty == false))
                """
            )
        }

        if case .googleLogin(let requestDTO) = endpoint {
            print(
                """
                [GoogleLogin] request sending \
                requestURL=\(url.absoluteString) \
                idTokenExists=\(!requestDTO.idToken.isEmpty) \
                idTokenLength=\(requestDTO.idToken.count) \
                deviceNameExists=\((requestDTO.deviceName?.isEmpty == false))
                """
            )
        }

        return urlRequest
    }

    private func decodeResponse<ResponseDTO: Decodable>(
        data: Data,
        response: URLResponse,
        responseType: ResponseDTO.Type
    ) throws -> ResponseDTO {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw decodeFailure(from: data, statusCode: httpResponse.statusCode)
        }

        if responseType == AuthResponseDTO.self {
            let authResponseDTO = try jsonDecoder.decode(AuthResponseDTO.self, from: data)
            guard authResponseDTO.success, authResponseDTO.data != nil else {
                if let errorPayload = authResponseDTO.error {
                    throw AuthError.from(serverCode: errorPayload.code, message: errorPayload.message)
                }
                throw AuthError.invalidResponse
            }

            guard let typedResponse = authResponseDTO as? ResponseDTO else {
                throw AuthError.invalidResponse
            }

            return typedResponse
        }

        let envelope = try jsonDecoder.decode(AuthFailureEnvelopeDTO<ResponseDTO>.self, from: data)
        guard envelope.success, let payload = envelope.data else {
            if let errorPayload = envelope.error {
                throw AuthError.from(serverCode: errorPayload.code, message: errorPayload.message)
            }
            throw AuthError.invalidResponse
        }

        return payload
    }

    private func validateVoidResponse(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw decodeFailure(from: data, statusCode: httpResponse.statusCode)
        }

        guard !data.isEmpty else { return }

        if let envelope = try? jsonDecoder.decode(AuthFailureEnvelopeDTO<EmptyResponseDTO>.self, from: data),
           envelope.success == false,
           let errorPayload = envelope.error {
            throw AuthError.from(serverCode: errorPayload.code, message: errorPayload.message)
        }
    }

    private func decodeFailure(from data: Data, statusCode: Int) -> AuthError {
        if let envelope = try? jsonDecoder.decode(AuthFailureEnvelopeDTO<EmptyResponseDTO>.self, from: data),
           let errorPayload = envelope.error {
            return AuthError.from(serverCode: errorPayload.code, message: errorPayload.message)
        }

        return .server(
            code: "HTTP_\(statusCode)",
            message: HTTPURLResponse.localizedString(forStatusCode: statusCode)
        )
    }
}

private struct AuthFailureEnvelopeDTO<DataDTO: Decodable>: Decodable {
    let success: Bool
    let data: DataDTO?
    let error: AuthErrorPayloadDTO?
}

private struct EmptyResponseDTO: Decodable {}
