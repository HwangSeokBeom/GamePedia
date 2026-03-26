import Foundation

// MARK: - TranslationRemoteResponse

struct TranslationRemoteResponse {
    let data: Data
    let statusCode: Int
}

// MARK: - TranslationRemoteDataSource

protocol TranslationRemoteDataSource {
    func requestTranslation(_ requestDTO: TranslationRequestDTO) async throws -> TranslationRemoteResponse
}

// MARK: - DefaultTranslationRemoteDataSource

final class DefaultTranslationRemoteDataSource: TranslationRemoteDataSource {

    private let session: URLSession
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = AppConfig.translationBaseURL
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func requestTranslation(_ requestDTO: TranslationRequestDTO) async throws -> TranslationRemoteResponse {
        let url = baseURL.appendingPathComponent("translate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestDTO)

        print("[Translation] request start")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown(URLError(.badServerResponse))
            }

            print("[Translation] response received")

            return TranslationRemoteResponse(
                data: data,
                statusCode: httpResponse.statusCode
            )
        } catch {
            print("[Translation] request failed", error)
            throw error
        }
    }
}
