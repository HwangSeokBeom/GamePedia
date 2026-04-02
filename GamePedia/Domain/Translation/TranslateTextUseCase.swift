import Foundation

// MARK: - TranslateTextUseCase

protocol TranslateTextUseCase {
    func execute(
        text: String,
        context: String,
        sourceLanguage: String?
    ) async -> String

    func execute(
        items: [TranslationRequestItem],
        context: String,
        sourceLanguage: String?
    ) async -> [TranslationResultItem]
}

// MARK: - Convenience Helpers

extension TranslateTextUseCase {
    func execute(
        item: TranslationRequestItem,
        context: String,
        sourceLanguage: String? = "en"
    ) async -> TranslationResultItem {
        let translatedText = await execute(
            text: item.text,
            context: context,
            sourceLanguage: sourceLanguage
        )
        return TranslationResultItem(
            identifier: item.identifier,
            field: item.field,
            sourceText: item.text,
            translatedText: translatedText
        )
    }
}

// MARK: - DefaultTranslateTextUseCase

final class DefaultTranslateTextUseCase: TranslateTextUseCase {

    private let repository: TranslationRepository
    private let languageProvider: LanguageProviding

    init(repository: TranslationRepository, languageProvider: LanguageProviding) {
        self.repository = repository
        self.languageProvider = languageProvider
    }

    func execute(
        text: String,
        context: String,
        sourceLanguage: String? = "en"
    ) async -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return text }

        guard !languageProvider.currentLanguage.isEnglish else {
            print("[Translation] skipped reason=current-language-en context=\(context)")
            return trimmedText
        }

        print("[Translate Start] screen: \(screenName(from: context)) textLength: \(trimmedText.count)")
        return await requestTranslatedText(
            trimmedText,
            context: context,
            sourceLanguage: sourceLanguage
        )
    }

    func execute(
        items: [TranslationRequestItem],
        context: String,
        sourceLanguage: String? = "en"
    ) async -> [TranslationResultItem] {
        guard !items.isEmpty else { return [] }

        var orderedResults = Array<TranslationResultItem?>(repeating: nil, count: items.count)

        await withTaskGroup(of: (Int, TranslationResultItem).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask { [self] in
                    let translatedText = await execute(
                        text: item.text,
                        context: "\(context).\(item.field)",
                        sourceLanguage: sourceLanguage
                    )
                    return (
                        index,
                        TranslationResultItem(
                            identifier: item.identifier,
                            field: item.field,
                            sourceText: item.text,
                            translatedText: translatedText
                        )
                    )
                }
            }

            for await (index, result) in group {
                orderedResults[index] = result
            }
        }

        return orderedResults.compactMap { $0 }
    }

    private func resolvedFallbackText(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        if !text.isEmpty {
            return text
        }
        return "—"
    }

    private func requestTranslatedText(
        _ text: String,
        context: String,
        sourceLanguage: String?
    ) async -> String {
        let fallbackText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fallbackText.isEmpty else { return text }

        do {
            let response = try await repository.translate(
                text: fallbackText,
                sourceLanguage: sourceLanguage,
                targetLanguage: languageProvider.currentLanguageCode
            )
            let resolvedText = resolvedFallbackText(from: response.translatedText)
            let finalText = resolvedText.isEmpty ? fallbackText : resolvedText
            print("[Translate Success] translatedLength: \(finalText.count)")
            return finalText
        } catch {
            print("[Translate Fallback] reason: request-failed context=\(context)")
            return fallbackText
        }
    }

    private func screenName(from context: String) -> String {
        context.split(separator: ".").first.map(String.init) ?? context
    }
}
