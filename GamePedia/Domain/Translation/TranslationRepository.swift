import Foundation

// MARK: - TranslationRepository

protocol TranslationRepository {
    func translate(
        text: String,
        sourceLanguage: String?,
        targetLanguage: String
    ) async throws -> TranslationDTO
}
