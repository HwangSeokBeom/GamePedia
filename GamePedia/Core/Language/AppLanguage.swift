import Foundation

// MARK: - AppLanguage

enum AppLanguage: String, CaseIterable, Equatable {
    case english  = "en"
    case korean   = "ko"
    case japanese = "ja"
    case chinese  = "zh"

    var isEnglish: Bool { self == .english }

    /// Best-effort match from an IETF language tag (e.g. "ko-KR" → .korean).
    static func from(languageCode: String) -> AppLanguage {
        let prefix = languageCode.prefix(2).lowercased()
        return AppLanguage.allCases.first { $0.rawValue == prefix } ?? .english
    }

    /// Detects the user's preferred language from `Locale.preferredLanguages`.
    static func detectedFromSystem() -> AppLanguage {
        for code in Locale.preferredLanguages {
            let prefix = code.prefix(2).lowercased()
            if let match = AppLanguage.allCases.first(where: { $0.rawValue == prefix }) {
                return match
            }
        }
        return .english
    }
}

// MARK: - LanguageProviding

protocol LanguageProviding: AnyObject {
    var currentLanguage: AppLanguage { get }
    var currentLanguageCode: String { get }
}

// MARK: - DefaultLanguageProvider

final class DefaultLanguageProvider: LanguageProviding {

    static let shared = DefaultLanguageProvider()

    private static let userDefaultsKey = "app.selectedLanguage"

    private(set) var currentLanguage: AppLanguage

    var currentLanguageCode: String { currentLanguage.rawValue }

    private init() {
        if let stored = UserDefaults.standard.string(forKey: Self.userDefaultsKey),
           let language = AppLanguage(rawValue: stored) {
            self.currentLanguage = language
        } else {
            // The app UI is Korean-first, so translation should default to Korean on first run.
            self.currentLanguage = .korean
        }
    }

    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.userDefaultsKey)
    }
}
