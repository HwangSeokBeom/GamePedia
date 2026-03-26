import Foundation

// MARK: - TranslationCaching

protocol TranslationCaching: AnyObject {
    func get(text: String, lang: AppLanguage) -> String?
    func save(text: String, lang: AppLanguage, translated: String)
}
