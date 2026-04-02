import SwiftUI
import Translation

@available(iOS 26.0, *)
struct TranslationHostView: View {
    let request: TranslationBatchRequest?
    let onResult: ([TranslationResultItem]) -> Void

    @State private var configuration: TranslationSession.Configuration?
    @State private var configuredSignature: String?

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .task(id: request?.signature) {
                syncConfiguration(with: request)
            }
            .translationTask(configuration) { session in
                guard let request else {
                    print("[TranslationHost] skipped reason=missing-request")
                    return
                }
                await performTranslation(using: session, request: request)
            }
    }

    private func syncConfiguration(with request: TranslationBatchRequest?) {
        guard let request else {
            configuredSignature = nil
            configuration?.invalidate()
            configuration = nil
            print("[TranslationHost] skipped reason=no-request")
            return
        }

        guard configuredSignature != request.signature else { return }
        configuredSignature = request.signature

        let sourceLanguage = request.sourceLanguage.map(Locale.Language.init(identifier:))
        let targetLanguage = Locale.Language(identifier: request.targetLanguage)
        configuration?.invalidate()
        configuration = TranslationSession.Configuration(
            source: sourceLanguage,
            target: targetLanguage
        )
    }

    private func performTranslation(
        using session: TranslationSession,
        request: TranslationBatchRequest
    ) async {
        do {
            try await session.prepareTranslation()
        } catch {
            print("[TranslationHost] skipped reason=session-unavailable error=\(error.localizedDescription)")
            await MainActor.run {
                onResult([])
            }
            return
        }

        print("[TranslationHost] session ready source=\(request.sourceLanguage ?? "auto") target=\(request.targetLanguage)")

        var translatedItems: [TranslationResultItem] = []
        for item in request.items {
            guard !item.text.isEmpty else {
                print("[TranslationHost] skipped reason=empty-text field=\(item.field)")
                continue
            }

            print("[TranslationHost] requested field=\(item.field) text=\(item.text.prefix(60))")

            do {
                let response = try await session.translate(item.text)
                let translatedText = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !translatedText.isEmpty else {
                    print("[TranslationHost] skipped reason=empty-result field=\(item.field)")
                    continue
                }

                translatedItems.append(
                    TranslationResultItem(
                        identifier: item.identifier,
                        field: item.field,
                        sourceText: item.text,
                        translatedText: translatedText
                    )
                )
                print("[TranslationHost] translated field=\(item.field) result=\(translatedText.prefix(60))")
            } catch {
                print("[TranslationHost] skipped reason=translation-failed field=\(item.field) error=\(error.localizedDescription)")
            }
        }

        guard !translatedItems.isEmpty else {
            print("[TranslationHost] skipped reason=no-results")
            await MainActor.run {
                onResult([])
            }
            return
        }

        await MainActor.run {
            onResult(translatedItems)
            translatedItems.forEach { item in
                print("[TranslationHost] callback delivered field=\(item.field)")
            }
        }
    }
}
