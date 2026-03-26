import Foundation

protocol HomeHighlightSelecting {
    func selectHighlights(
        from candidates: [Game],
        minimumCount: Int,
        maximumCount: Int
    ) -> [HomeHighlightItem]
}
