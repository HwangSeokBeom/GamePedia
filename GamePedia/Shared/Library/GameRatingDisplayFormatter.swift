import Foundation

struct GameRatingDisplayParts: Equatable {
    let normalizedRating: Double?
    let displayText: String?
    let selectedDisplaySource: String
}

enum GameRatingDisplayFormatter {
    static func makeDisplay(
        userRating: Double?,
        aggregatedRating: Double?,
        totalRating: Double?
    ) -> GameRatingDisplayParts {
        let selected: (value: Double?, source: String)
        if let userRating {
            selected = (userRating, "userRating")
        } else if let aggregatedRating {
            selected = (aggregatedRating, "aggregatedRating")
        } else if let totalRating {
            selected = (totalRating, "totalRating")
        } else {
            selected = (nil, "none")
        }

        guard let rawValue = selected.value, rawValue.isFinite, rawValue > 0 else {
            return GameRatingDisplayParts(
                normalizedRating: nil,
                displayText: nil,
                selectedDisplaySource: selected.source
            )
        }

        let normalizedRating = rawValue > 5 ? rawValue / 20.0 : rawValue
        return GameRatingDisplayParts(
            normalizedRating: normalizedRating,
            displayText: String(format: "%.1f", normalizedRating),
            selectedDisplaySource: selected.source
        )
    }
}
