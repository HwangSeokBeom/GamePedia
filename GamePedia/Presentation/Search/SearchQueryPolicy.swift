import Foundation

enum SearchQueryPolicy {
    static let minimumSuggestionCharacterCount = 1
    static let minimumMeaningfulCharacterCount = 2
    static let suggestionLimit = 6

    static func normalizedQuery(from query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func canTriggerSuggestions(for query: String) -> Bool {
        meaningfulCharacterCount(in: normalizedQuery(from: query)) >= minimumSuggestionCharacterCount
    }

    static func canTriggerFullSearch(for query: String) -> Bool {
        meaningfulCharacterCount(in: normalizedQuery(from: query)) >= minimumMeaningfulCharacterCount
    }

    static func meaningfulCharacterCount(in query: String) -> Int {
        query
            .precomposedStringWithCanonicalMapping
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .count
    }
}
