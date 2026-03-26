import Foundation

// MARK: - TranslationRequestItem

struct TranslationRequestItem: Hashable {
    let identifier: String
    let field: String
    let text: String

    init(identifier: String, field: String, text: String) {
        self.identifier = identifier
        self.field = field
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - TranslationBatchRequest

struct TranslationBatchRequest: Equatable {
    let context: String
    let sourceLanguage: String?
    let targetLanguage: String
    let items: [TranslationRequestItem]

    var signature: String {
        let itemSignature = items
            .map { "\($0.identifier)|\($0.field)|\($0.text)" }
            .joined(separator: "||")
        return [
            context,
            sourceLanguage ?? "auto",
            targetLanguage,
            itemSignature
        ].joined(separator: "::")
    }
}

// MARK: - TranslationResultItem

struct TranslationResultItem: Equatable {
    let identifier: String
    let field: String
    let sourceText: String
    let translatedText: String
}
