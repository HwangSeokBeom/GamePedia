import Foundation

// MARK: - DefaultTranslationRepository

final class DefaultTranslationRepository: TranslationRepository {

    private let remoteDataSource: any TranslationRemoteDataSource
    private let cache: any TranslationCaching

    init(
        remoteDataSource: any TranslationRemoteDataSource = DefaultTranslationRemoteDataSource(),
        cache: any TranslationCaching = DefaultTranslationCache.shared
    ) {
        self.remoteDataSource = remoteDataSource
        self.cache = cache
    }

    func translate(
        text: String,
        sourceLanguage: String?,
        targetLanguage: String
    ) async throws -> TranslationDTO {
        _ = sourceLanguage
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetAppLanguage = AppLanguage.from(languageCode: targetLanguage)

        if let cachedTranslation = cache.get(text: normalizedText, lang: targetAppLanguage) {
            return TranslationDTO(
                translatedText: cachedTranslation,
                translationSkipped: false,
                reason: "memory-cache"
            )
        }

        let requestDTO = TranslationRequestDTO(
            text: normalizedText,
            targetLanguage: targetLanguage
        )
        let response = try await remoteDataSource.requestTranslation(requestDTO)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let dto: TranslationDTO
        do {
            dto = try decoder.decode(TranslationDTO.self, from: response.data)
        } catch {
            if (500...599).contains(response.statusCode) {
                throw NetworkError.serverError(statusCode: response.statusCode, message: nil)
            }
            throw NetworkError.decodingFailed(error)
        }

        let normalizedTranslation = dto.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTranslation.isEmpty else {
            if (500...599).contains(response.statusCode) {
                throw NetworkError.serverError(statusCode: response.statusCode, message: dto.reason)
            }

            let error = NSError(
                domain: "TranslationRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "translatedText was empty"]
            )
            throw NetworkError.decodingFailed(error)
        }

        let normalizedDTO = TranslationDTO(
            translatedText: normalizedTranslation,
            translationSkipped: dto.translationSkipped,
            reason: dto.reason
        )
        cache.save(text: requestDTO.text, lang: targetAppLanguage, translated: normalizedTranslation)
        print("[Translation] received skipped=\(normalizedDTO.translationSkipped ?? false)")
        return normalizedDTO
    }
}
