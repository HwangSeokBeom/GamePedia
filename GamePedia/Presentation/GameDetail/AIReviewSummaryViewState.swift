import Foundation

enum AIReviewSummarySectionState: Equatable {
    case idle
    case loading
    case loaded(AIReviewSummaryViewState)
    case unavailable(String)
    case error(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

struct AIReviewSummaryViewState: Equatable {
    private enum CompactLimit {
        static let summaryLength = 120
        static let pros = 3
        static let cons = 3
        static let recommendedFor = 3
        static let notRecommendedFor = 3
        static let keywords = 6
    }

    let title: String
    let subtitle: String
    let generatedAtText: String?
    let summary: String
    let pros: [String]
    let cons: [String]
    let recommendedFor: [String]
    let notRecommendedFor: [String]
    let keywords: [String]
    let disclaimer: String
    let isExpandable: Bool
    let isExpanded: Bool

    static func make(from summary: AIReviewSummary, isExpanded: Bool = false) -> AIReviewSummaryViewState {
        AIReviewSummaryViewState(
            title: "AI 리뷰 요약",
            subtitle: "리뷰 \(summary.reviewCount)개 분석",
            generatedAtText: summary.generatedAt.map { "최근 생성: \(dateFormatter.string(from: $0))" },
            summary: summary.summary,
            pros: summary.pros,
            cons: summary.cons,
            recommendedFor: summary.recommendedFor,
            notRecommendedFor: summary.notRecommendedFor,
            keywords: summary.keywords,
            disclaimer: summary.disclaimer,
            isExpandable: summary.summary.count > CompactLimit.summaryLength
                || summary.pros.count > CompactLimit.pros
                || summary.cons.count > CompactLimit.cons
                || summary.recommendedFor.count > CompactLimit.recommendedFor
                || summary.notRecommendedFor.count > CompactLimit.notRecommendedFor
                || summary.keywords.count > CompactLimit.keywords,
            isExpanded: isExpanded
        )
    }

    var visiblePros: [String] {
        visibleItems(pros, compactLimit: CompactLimit.pros)
    }

    var visibleCons: [String] {
        visibleItems(cons, compactLimit: CompactLimit.cons)
    }

    var visibleRecommendedFor: [String] {
        visibleItems(recommendedFor, compactLimit: CompactLimit.recommendedFor)
    }

    var visibleNotRecommendedFor: [String] {
        visibleItems(notRecommendedFor, compactLimit: CompactLimit.notRecommendedFor)
    }

    var visibleKeywords: [String] {
        visibleItems(keywords, compactLimit: CompactLimit.keywords)
    }

    func settingExpanded(_ isExpanded: Bool) -> AIReviewSummaryViewState {
        AIReviewSummaryViewState(
            title: title,
            subtitle: subtitle,
            generatedAtText: generatedAtText,
            summary: summary,
            pros: pros,
            cons: cons,
            recommendedFor: recommendedFor,
            notRecommendedFor: notRecommendedFor,
            keywords: keywords,
            disclaimer: disclaimer,
            isExpandable: isExpandable,
            isExpanded: isExpanded
        )
    }

    private func visibleItems(_ items: [String], compactLimit: Int) -> [String] {
        isExpanded ? items : Array(items.prefix(compactLimit))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}
