import Foundation

// MARK: - AppleTranslationProvider

@available(iOS 26.0, *)
final class AppleTranslationProvider: TranslationProviding {

    func supportsOnDeviceTranslation(targetLanguage: String) -> Bool {
        let normalizedTarget = targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedTarget.isEmpty else {
            print("[Translation] skipped reason=empty-target-language")
            return false
        }
        guard normalizedTarget != "en" else {
            print("[Translation] skipped reason=target-language-is-english")
            return false
        }
        print("[Translation] provider ready target=\(normalizedTarget) sessionLifecycle=view-hosted")
        return true
    }
}
