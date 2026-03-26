import Foundation

// MARK: - TranslationRequestDTO

struct TranslationRequestDTO: Encodable {
    let text: String
    let targetLanguage: String
}

// MARK: - TranslationDTO

struct TranslationDTO: Decodable {
    let translatedText: String
    let translationSkipped: Bool?
    let reason: String?
}
