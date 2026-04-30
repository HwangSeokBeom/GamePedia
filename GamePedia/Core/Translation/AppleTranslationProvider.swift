import Foundation

// MARK: - AppleTranslationProvider

@available(iOS 26.0, *)
final class AppleTranslationProvider: TranslationProviding {

    func supportsOnDeviceTranslation(targetLanguage: String) -> Bool {
        let normalizedTarget = targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedTarget.isEmpty else {
            TranslationSupportLogLimiter.logOnce(
                key: "empty-target-language",
                message: "[Translation] skipped reason=empty-target-language"
            )
            return false
        }
        guard normalizedTarget != "en" else {
            TranslationSupportLogLimiter.logOnce(
                key: "target-language-is-english",
                message: "[Translation] skipped reason=target-language-is-english"
            )
            return false
        }
#if targetEnvironment(simulator)
        TranslationSupportLogLimiter.logOnce(
            key: "unsupported-simulator-\(normalizedTarget)",
            message: "[Translation] skipped reason=unsupported-simulator target=\(normalizedTarget)"
        )
        return false
#else
        TranslationSupportLogLimiter.logOnce(
            key: "provider-ready-\(normalizedTarget)",
            message: "[Translation] provider ready target=\(normalizedTarget) sessionLifecycle=view-hosted"
        )
        return true
#endif
    }
}
