import Foundation

// MARK: - TranslationProviding

protocol TranslationProviding: AnyObject {
    func supportsOnDeviceTranslation(targetLanguage: String) -> Bool
}

// MARK: - Factory

func makeTranslationProvider() -> any TranslationProviding {
    if #available(iOS 26.0, *) {
        return AppleTranslationProvider()
    }
    print("[Translation] skipped reason=OS below iOS 26.0, using NoOp provider")
    return NoOpTranslationProvider()
}

// MARK: - NoOpTranslationProvider

final class NoOpTranslationProvider: TranslationProviding {
    func supportsOnDeviceTranslation(targetLanguage: String) -> Bool {
        TranslationSupportLogLimiter.logOnce(
            key: "noop-\(targetLanguage)",
            message: "[Translation] skipped reason=NoOp target=\(targetLanguage)"
        )
        return false
    }
}

enum TranslationSupportLogLimiter {
    private static var loggedKeys = Set<String>()
    private static let lock = NSLock()

    static func logOnce(key: String, message: String) {
        lock.lock()
        let shouldLog = loggedKeys.insert(key).inserted
        lock.unlock()

        if shouldLog {
            print(message)
        }
    }
}
