import Foundation

struct DefaultHomeHighlightSelector: HomeHighlightSelecting {

    func selectHighlights(
        from candidates: [Game],
        minimumCount: Int = 3,
        maximumCount: Int = 5
    ) -> [HomeHighlightItem] {
        let uniqueCandidates = candidates.uniquedByID()

        let strictCandidates = uniqueCandidates
            .filter(hasCoverImage)
            .filter(hasReasonableTitleLength)
            .filter(hasEnoughDisplayMetadata)
            .sorted(by: isBetterHighlightCandidate)

        let selectedCandidates = Array(strictCandidates.prefix(maximumCount))
        guard selectedCandidates.count >= minimumCount else {
            return selectedCandidates.map(makeHighlightItem)
        }

        return selectedCandidates.map(makeHighlightItem)
    }

    private func isBetterHighlightCandidate(_ lhs: Game, _ rhs: Game) -> Bool {
        let lhsScore = highlightCandidateScore(for: lhs)
        let rhsScore = highlightCandidateScore(for: rhs)
        if abs(lhsScore - rhsScore) > 0.001 { return lhsScore > rhsScore }
        if abs(lhs.rating - rhs.rating) > 0.001 { return lhs.rating > rhs.rating }
        return lhs.popularity > rhs.popularity
    }

    private func highlightCandidateScore(for game: Game) -> Double {
        let ratingScore = min(max(game.rating / 5.0, 0), 1) * 35
        let popularityScore = min(max(game.popularity / 100.0, 0), 1) * 28
        let metadataScore = Double(metadataCount(for: game)) * 10
        let trendingBoost: Double = game.isTrending ? 8 : 0
        let summaryBoost: Double = hasSummary(game) ? 6 : 0
        let releaseBoost: Double = game.releaseYear > 0 ? 4 : 0
        let total = ratingScore + popularityScore + metadataScore
        return total + trendingBoost + summaryBoost + releaseBoost
    }

    private func hasCoverImage(_ game: Game) -> Bool {
        game.coverImageURL != nil
    }

    private func hasReasonableTitleLength(_ game: Game) -> Bool {
        let title = game.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty && title.count <= 34
    }

    private func hasEnoughDisplayMetadata(_ game: Game) -> Bool {
        metadataCount(for: game) >= 2
    }

    private func metadataCount(for game: Game) -> Int {
        var count = 0
        if hasSummary(game) { count += 1 }
        if !game.genre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, game.genre != "기타" { count += 1 }
        if game.releaseYear > 0 { count += 1 }
        return count
    }

    private func hasSummary(_ game: Game) -> Bool {
        guard let summary = game.resolvedSummary?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return summary.count >= 18
    }

    private func makeHighlightItem(from game: Game) -> HomeHighlightItem {
        HomeHighlightItem(
            game: game,
            badgeText: "오늘의 추천",
            titleText: game.displayTitle,
            metaText: metaText(for: game),
            supportingText: supportingText(for: game)
        )
    }

    private func metaText(for game: Game) -> String {
        var parts: [String] = []
        if !game.genre.isEmpty { parts.append(game.genre) }
        if game.releaseYear > 0 { parts.append("\(game.releaseYear)") }
        if game.rating > 0 { parts.append("★ \(game.formattedRating)") }
        return parts.joined(separator: " · ")
    }

    private func supportingText(for game: Game) -> String {
        if let summary = game.resolvedSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            let singleLine = summary.replacingOccurrences(of: "\n", with: " ")
            if singleLine.count <= 76 { return singleLine }
            let index = singleLine.index(singleLine.startIndex, offsetBy: 76)
            return "\(singleLine[..<index])..."
        }

        if game.isTrending {
            return "지금 반응이 좋은 작품이라 하이라이트로 골랐어요."
        }
        if game.popularity >= 75 {
            return "인기 지표와 평점을 함께 고려해 상단에 배치했어요."
        }
        return "메타 정보가 탄탄해서 첫 화면에서 보기 좋은 작품이에요."
    }
}

private extension Array where Element == Game {
    func uniquedByID() -> [Game] {
        var seen = Set<Int>()
        return filter { seen.insert($0.id).inserted }
    }
}
