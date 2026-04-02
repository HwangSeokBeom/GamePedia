import CryptoKit
import Foundation

// MARK: - DefaultTranslationCache

final class DefaultTranslationCache: TranslationCaching {

    static let shared = DefaultTranslationCache()

    private let cache = NSCache<NSString, NSString>()

    private init() {
        cache.countLimit = 512
    }

    func get(text: String, lang: AppLanguage) -> String? {
        let key = cacheKey(text: text, lang: lang)
        return cache.object(forKey: key as NSString) as String?
    }

    func save(text: String, lang: AppLanguage, translated: String) {
        let normalizedTranslated = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTranslated.isEmpty else { return }
        let key = cacheKey(text: text, lang: lang)
        cache.setObject(normalizedTranslated as NSString, forKey: key as NSString)
    }

    private func cacheKey(text: String, lang: AppLanguage) -> String {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let input = "\(lang.rawValue)::\(normalizedText)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
