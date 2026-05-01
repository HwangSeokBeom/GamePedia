import XCTest
@testable import GamePedia

final class LibraryCuratorTests: XCTestCase {
    func testDTO_decodesSuccessResponse() throws {
        let result = try decodeResult(source: "llm", selectedCount: 1)

        XCTAssertEqual(result.mode, .today)
        XCTAssertEqual(result.source, "llm")
        XCTAssertEqual(result.summary.title, "Today")
        XCTAssertEqual(result.tasteProfile.topGenres, ["RPG"])
        XCTAssertEqual(result.sections.first?.items.first?.gameId, "1942")
        XCTAssertEqual(result.games.first?.title, "Stardew Valley")
        XCTAssertEqual(result.meta.selectedCount, 1)
    }

    func testDTO_decodesFallbackAsSuccessfulData() throws {
        let result = try decodeResult(source: "fallback", selectedCount: 1, fallbackReason: "LLM_REQUEST_FAILED")

        XCTAssertTrue(result.isFallback)
        XCTAssertEqual(result.meta.fallbackReason, "LLM_REQUEST_FAILED")
    }

    func testMapper_skipsSectionItemsWithoutMatchingGame() throws {
        let result = try decodeResult(source: "llm", selectedCount: 2, includeMissingItem: true)
        let viewModel = LibraryCuratorViewModel(fetchLibraryCuratorUseCase: StubLibraryCuratorUseCase(result: result))

        viewModel.send(.analyzeTapped)
        waitUntil { !viewModel.state.isLoading && viewModel.state.hasLoadedOnce }

        XCTAssertEqual(viewModel.state.sections.first?.items.map(\.gameId), ["1942"])
    }

    func testFallbackSourceIsLoadedStateNotError() throws {
        let result = try decodeResult(source: "fallback", selectedCount: 1)
        let viewModel = LibraryCuratorViewModel(fetchLibraryCuratorUseCase: StubLibraryCuratorUseCase(result: result))

        viewModel.send(.analyzeTapped)
        waitUntil { !viewModel.state.isLoading && viewModel.state.hasLoadedOnce }

        XCTAssertNil(viewModel.state.errorMessage)
        XCTAssertTrue(viewModel.state.isFallback)
        XCTAssertEqual(viewModel.state.fallbackMessage, L10n.tr("Localizable", "library_curator_fallback_message"))
    }

    func testSelectedCountZeroProducesEmptyState() throws {
        let result = try decodeResult(source: "fallback", selectedCount: 0, includeGames: false)
        let viewModel = LibraryCuratorViewModel(fetchLibraryCuratorUseCase: StubLibraryCuratorUseCase(result: result))

        viewModel.send(.analyzeTapped)
        waitUntil { !viewModel.state.isLoading && viewModel.state.hasLoadedOnce }

        XCTAssertTrue(viewModel.state.showsEmptyState)
        XCTAssertEqual(viewModel.state.emptyMessage, L10n.tr("Localizable", "library_curator_empty_message"))
    }

    func testModeMappingAndLocaleRequest() async throws {
        let useCase = CapturingLibraryCuratorUseCase(result: try decodeResult(source: "llm", selectedCount: 1))
        let viewModel = LibraryCuratorViewModel(fetchLibraryCuratorUseCase: useCase)

        viewModel.send(.modeSelected(.shortSession))
        viewModel.send(.queryChanged("30 minutes"))
        viewModel.send(.analyzeTapped)
        await useCase.waitForRequest()

        XCTAssertEqual(useCase.capturedRequest?.mode, .shortSession)
        XCTAssertEqual(useCase.capturedRequest?.locale, DefaultLanguageProvider.shared.currentLanguageCode)
        XCTAssertEqual(useCase.capturedRequest?.candidateScope, .mixed)
        XCTAssertEqual(useCase.capturedRequest?.limit, 5)
    }

    func testPromptChipTapUpdatesSelectedPromptAndQuery() {
        let viewModel = LibraryCuratorViewModel(fetchLibraryCuratorUseCase: StubLibraryCuratorUseCase(result: try! decodeResult(source: "llm", selectedCount: 1)))

        viewModel.send(.modeSelected(.today))

        XCTAssertEqual(viewModel.state.selectedMode, .today)
        XCTAssertEqual(viewModel.state.selectedPromptChipID, LibraryCuratorMode.today.promptChipID)
        XCTAssertEqual(viewModel.state.queryText, LibraryCuratorMode.today.localizedTitle)
    }

    func testPromptChipRetapKeepsSelection() {
        let viewModel = LibraryCuratorViewModel(fetchLibraryCuratorUseCase: StubLibraryCuratorUseCase(result: try! decodeResult(source: "llm", selectedCount: 1)))

        viewModel.send(.modeSelected(.rediscover))
        viewModel.send(.modeSelected(.rediscover))

        XCTAssertEqual(viewModel.state.selectedPromptChipID, LibraryCuratorMode.rediscover.promptChipID)
        XCTAssertEqual(viewModel.state.selectedMode, .rediscover)
    }

    func testOverviewPromptClearsQueryAndRequestIgnoresUserInput() async throws {
        let useCase = CapturingLibraryCuratorUseCase(result: try decodeResult(source: "llm", selectedCount: 1))
        let viewModel = LibraryCuratorViewModel(fetchLibraryCuratorUseCase: useCase)

        viewModel.send(.queryChanged("오늘 뭐 하지"))
        viewModel.send(.modeSelected(.overview))
        viewModel.send(.analyzeTapped)
        await useCase.waitForRequest()

        XCTAssertEqual(viewModel.state.selectedPromptChipID, LibraryCuratorMode.overview.promptChipID)
        XCTAssertEqual(viewModel.state.queryText, "")
        XCTAssertEqual(useCase.capturedRequest?.mode, .overview)
        XCTAssertNil(useCase.capturedRequest?.query)
    }

    func testInitialLoadDoesNotAutomaticallyRequestOverview() throws {
        let useCase = CapturingLibraryCuratorUseCase(result: try decodeResult(source: "llm", selectedCount: 1))
        let viewModel = LibraryCuratorViewModel(fetchLibraryCuratorUseCase: useCase)

        viewModel.send(.viewDidLoad)
        viewModel.send(.viewDidLoad)

        XCTAssertEqual(useCase.capturedRequests.count, 0)
    }

    func testUserQueryInputClearsSelectedPrompt() {
        let viewModel = LibraryCuratorViewModel(fetchLibraryCuratorUseCase: StubLibraryCuratorUseCase(result: try! decodeResult(source: "llm", selectedCount: 1)))

        viewModel.send(.modeSelected(.shortSession))
        viewModel.send(.queryChanged("직접 입력한 요청"))

        XCTAssertNil(viewModel.state.selectedPromptChipID)
        XCTAssertEqual(viewModel.state.queryText, "직접 입력한 요청")
        XCTAssertEqual(viewModel.state.selectedMode, .shortSession)
    }

    func testSelectedTagsAreIncludedInRequestQuery() async throws {
        let useCase = CapturingLibraryCuratorUseCase(result: try decodeResult(source: "llm", selectedCount: 1))
        let viewModel = LibraryCuratorViewModel(fetchLibraryCuratorUseCase: useCase)
        viewModel.send(.analyzeTapped)
        await useCase.waitForRequest()
        waitUntil { !viewModel.state.isLoading && viewModel.state.hasLoadedOnce }

        let tasteID = LibraryCuratorViewModel.tagID(for: "RPG", section: "taste")
        let selectedDisplayTag = try XCTUnwrap(viewModel.state.sections.first?.items.first?.displayTags.first)
        let genreID = LibraryCuratorViewModel.tagID(for: selectedDisplayTag, section: "genre")
        viewModel.send(.modeSelected(.today))
        viewModel.send(.tasteTagTapped(tasteID))
        viewModel.send(.genreTagTapped(genreID))
        viewModel.send(.analyzeTapped)
        await useCase.waitForRequestCount(2)

        XCTAssertTrue(useCase.capturedRequests.last?.query?.contains("Selected tags:") == true)
        XCTAssertTrue(useCase.capturedRequests.last?.query?.contains("RPG") == true)
        XCTAssertTrue(useCase.capturedRequests.last?.query?.contains(selectedDisplayTag) == true)
    }

    func testUnknownTagLocalizationFallbackAndRequiredLanguages() {
        XCTAssertEqual(localized("unknown_library_tag", language: .english), ["Unknown Library Tag"])
        XCTAssertEqual(localized("high_rating_preference", language: .korean), ["고평점 취향"])
        XCTAssertEqual(localized("high_rating_preference", language: .english), ["High-rated picks"])
        XCTAssertEqual(localized("short_session", language: .japanese), ["短時間プレイ"])
        XCTAssertEqual(localized("rediscover", language: .chinese), ["重新发现"])
        XCTAssertEqual(localized("match", language: .chinese), ["匹配"])
        XCTAssertEqual(localized("long", language: .korean), ["긴 세션"])
        XCTAssertEqual(localized("average", language: .korean), ["보통 난이도"])
    }

    func testLibraryCuratorSpecificTagMappings() {
        XCTAssertEqual(localized("competitive", language: .korean), ["경쟁"])
        XCTAssertEqual(localized("reviewed", language: .korean), ["리뷰 작성"])
        XCTAssertEqual(localized("high_user_rating", language: .korean), ["높은 내 평점"])
        XCTAssertEqual(localized("played", language: .korean), ["플레이 기록"])
        XCTAssertEqual(localized("review_driven", language: .korean), ["리뷰 기반"])
        XCTAssertEqual(localized("avg_user_rating_4.8", language: .korean), ["평균 평점 4.8"])
        XCTAssertEqual(localized("avg_user_rating_4_8", language: .korean), ["평균 평점 4.8"])
        XCTAssertEqual(localized("avg user rating 4 8", language: .korean), ["평균 평점 4.8"])
    }

    func testOverviewRequestIgnoresSelectedTags() async throws {
        let useCase = CapturingLibraryCuratorUseCase(result: try decodeResult(source: "llm", selectedCount: 1))
        let viewModel = LibraryCuratorViewModel(fetchLibraryCuratorUseCase: useCase)

        viewModel.send(.analyzeTapped)
        await useCase.waitForRequest()
        waitUntil { !viewModel.state.isLoading && viewModel.state.hasLoadedOnce }

        let tasteID = LibraryCuratorViewModel.tagID(for: "RPG", section: "taste")
        let selectedDisplayTag = try XCTUnwrap(viewModel.state.sections.first?.items.first?.displayTags.first)
        let genreID = LibraryCuratorViewModel.tagID(for: selectedDisplayTag, section: "genre")
        viewModel.send(.tasteTagTapped(tasteID))
        viewModel.send(.genreTagTapped(genreID))
        viewModel.send(.modeSelected(.overview))
        viewModel.send(.analyzeTapped)

        XCTAssertEqual(useCase.capturedRequests.count, 1)
        XCTAssertNil(useCase.capturedRequests.last?.query)
    }

    func testRepeatedAnalyzeUsesRecentSuccessfulCache() async throws {
        let useCase = CapturingLibraryCuratorUseCase(result: try decodeResult(source: "llm", selectedCount: 1))
        let viewModel = LibraryCuratorViewModel(fetchLibraryCuratorUseCase: useCase)

        viewModel.send(.analyzeTapped)
        await useCase.waitForRequest()
        waitUntil { !viewModel.state.isLoading && viewModel.state.hasLoadedOnce }
        viewModel.send(.analyzeTapped)

        XCTAssertEqual(useCase.capturedRequests.count, 1)
        XCTAssertTrue(viewModel.state.hasLoadedOnce)
    }

    func testDuplicateInFlightAnalyzeDoesNotStartSecondRequest() async throws {
        let useCase = DelayedLibraryCuratorUseCase(result: try decodeResult(source: "llm", selectedCount: 1))
        let viewModel = LibraryCuratorViewModel(fetchLibraryCuratorUseCase: useCase)

        viewModel.send(.analyzeTapped)
        viewModel.send(.analyzeTapped)
        await useCase.waitForRequest()

        XCTAssertEqual(useCase.capturedRequests.count, 1)
        useCase.finish()
        waitUntil { !viewModel.state.isLoading && viewModel.state.hasLoadedOnce }
    }

    func testDailyLimitPreservesExistingResultsAndBlocksSessionRequests() async throws {
        let useCase = SequencedLibraryCuratorUseCase(results: [
            .success(try decodeResult(source: "llm", selectedCount: 1)),
            .failure(LibraryCuratorError.dailyLimitExceeded(message: L10n.tr("Localizable", "library_curator_daily_limit_message")))
        ])
        let viewModel = LibraryCuratorViewModel(fetchLibraryCuratorUseCase: useCase)

        viewModel.send(.analyzeTapped)
        await useCase.waitForRequestCount(1)
        waitUntil { !viewModel.state.isLoading && viewModel.state.hasLoadedOnce }
        viewModel.send(.modeSelected(.today))
        viewModel.send(.analyzeTapped)
        await useCase.waitForRequestCount(2)
        waitUntil { viewModel.state.isDailyLimitExceeded && !viewModel.state.isLoading }

        XCTAssertEqual(useCase.capturedRequests.count, 2)
        XCTAssertTrue(viewModel.state.isDailyLimitExceeded)
        XCTAssertNil(viewModel.state.errorMessage)
        XCTAssertFalse(viewModel.state.sections.isEmpty)
        XCTAssertEqual(viewModel.state.analyzeButtonTitle, L10n.tr("Localizable", "library_curator_daily_limit_button"))
        XCTAssertEqual(viewModel.state.analyzeButtonStyle, .dailyLimitExceeded)
        XCTAssertEqual(viewModel.state.dailyLimitPresentation, .banner(message: L10n.tr("Localizable", "library_curator_daily_limit_message")))

        viewModel.send(.modeSelected(.rediscover))
        viewModel.send(.analyzeTapped)

        XCTAssertEqual(useCase.capturedRequests.count, 2)
    }

    func testDailyLimitWithoutExistingResultShowsOnlyDailyLimitEmptyPresentation() async throws {
        let useCase = SequencedLibraryCuratorUseCase(results: [
            .failure(LibraryCuratorError.dailyLimitExceeded(message: L10n.tr("Localizable", "library_curator_daily_limit_message")))
        ])
        let viewModel = LibraryCuratorViewModel(fetchLibraryCuratorUseCase: useCase)

        viewModel.send(.analyzeTapped)
        await useCase.waitForRequestCount(1)
        waitUntil { viewModel.state.isDailyLimitExceeded && !viewModel.state.isLoading }

        XCTAssertEqual(useCase.capturedRequests.count, 1)
        XCTAssertTrue(viewModel.state.isDailyLimitExceeded)
        XCTAssertNil(viewModel.state.errorMessage)
        XCTAssertNil(viewModel.state.visibleSummary)
        XCTAssertTrue(viewModel.state.visibleTasteProfile.isEmpty)
        XCTAssertTrue(viewModel.state.visibleRecommendations.isEmpty)
        XCTAssertFalse(viewModel.state.showsEmptyState)
        XCTAssertEqual(viewModel.state.analyzeButtonTitle, L10n.tr("Localizable", "library_curator_daily_limit_button"))
        XCTAssertEqual(viewModel.state.analyzeButtonStyle, .dailyLimitExceeded)
        XCTAssertEqual(
            viewModel.state.dailyLimitExceededMessage,
            L10n.tr("Localizable", "library_curator_daily_limit_message_no_result")
        )
        XCTAssertEqual(
            viewModel.state.dailyLimitPresentation,
            .empty(
                title: L10n.tr("Localizable", "library_curator_daily_limit_empty_title"),
                message: L10n.tr("Localizable", "library_curator_daily_limit_empty_message")
            )
        )

        viewModel.send(.analyzeTapped)

        XCTAssertEqual(useCase.capturedRequests.count, 1)
    }

    func testTagNormalizationMapsMOBAAndFiltersUserTag() {
        XCTAssertEqual(localized("MOBA", language: .english), ["MOBA"])
        XCTAssertEqual(localized("moba", language: .korean), ["MOBA"])
        XCTAssertEqual(localized("Multiplayer Online Battle Arena", language: .english), ["MOBA"])
        XCTAssertEqual(localized("user", language: .english), [])
    }

    func testTagFlowViewLimitsHeightToTwoRowsForLongTags() {
        let view = TagFlowView()
        view.maximumRows = 2
        view.maximumChipWidth = 96
        view.configure(items: [
            TagFlowItem(title: "relaxing visual novel"),
            TagFlowItem(title: "short interactive story"),
            TagFlowItem(title: "another extremely long tag"),
            TagFlowItem(title: "cozy")
        ])

        let size = view.sizeThatFits(CGSize(width: 180, height: CGFloat.greatestFiniteMagnitude))

        XCTAssertLessThanOrEqual(size.height, 64)
        XCTAssertGreaterThan(size.height, 0)
    }

    private func decodeResult(
        source: String,
        selectedCount: Int,
        fallbackReason: String? = nil,
        includeMissingItem: Bool = false,
        includeGames: Bool = true
    ) throws -> LibraryCuratorResult {
        let fallbackReasonLine = fallbackReason.map { #""fallbackReason": "\#($0)","# } ?? ""
        let missingItem = includeMissingItem
            ? #",{ "gameId": "9999", "reason": "Missing", "matchTags": ["unknown_tag"], "confidence": 0.4 }"#
            : ""
        let games = includeGames
            ? """
            [
              {
                "gameId": "1942",
                "title": "Stardew Valley",
                "coverUrl": "https://example.com/cover.jpg",
                "genres": ["RPG"],
                "platforms": ["PC"],
                "rating": 89.5,
                "source": "owned",
                "playtimeMinutes": 120,
                "lastPlayedAt": "2026-04-30T10:00:00Z",
                "isFavorite": true,
                "hasReview": true,
                "userRating": 4.5
              }
            ]
            """
            : "[]"
        let json = """
        {
          "success": true,
          "data": {
            "mode": "today",
            "source": "\(source)",
            "summary": {
              "title": "Today",
              "body": "Pick this next.",
              "bullets": ["Short", "Owned"]
            },
            "tasteProfile": {
              "topGenres": ["RPG"],
              "topThemes": ["story"],
              "preferredSession": "short_session",
              "playStyleTags": ["rediscover"],
              "ratingStyle": "high_rating_preference"
            },
            "sections": [
              {
                "id": "today",
                "title": "Today",
                "description": "For now",
                "items": [
                  { "gameId": "1942", "reason": "Good match", "matchTags": ["match", "short_session"], "confidence": 0.91 }
                  \(missingItem)
                ]
              }
            ],
            "games": \(games),
            "meta": {
              "candidateCount": 10,
              "selectedCount": \(selectedCount),
              \(fallbackReasonLine)
              "generatedAt": "2026-04-30T10:00:00Z",
              "locale": "ko"
            }
          }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(LibraryCuratorResponseEnvelopeDTO.self, from: json)
        return LibraryCuratorMapper.toEntity(try XCTUnwrap(envelope.data))
    }

    private func localized(_ rawTag: String, language: AppLanguage) -> [String] {
        RecommendationTagLocalizer.localizedDisplayTags(
            rawTags: [rawTag],
            language: language,
            maxCount: 4,
            screen: "LibraryCuratorTests"
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        predicate: @escaping () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = expectation(description: "wait until predicate")
        let deadline = Date().addingTimeInterval(timeout)

        func poll() {
            if predicate() {
                expectation.fulfill()
            } else if Date() > deadline {
                expectation.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: poll)
            }
        }

        poll()
        wait(for: [expectation], timeout: timeout + 0.2)
        XCTAssertTrue(predicate(), file: file, line: line)
    }
}

private final class StubLibraryCuratorUseCase: FetchLibraryCuratorUseCase {
    let result: LibraryCuratorResult

    init(result: LibraryCuratorResult) {
        self.result = result
    }

    func execute(request: LibraryCuratorRequest) async throws -> LibraryCuratorResult {
        result
    }
}

private final class CapturingLibraryCuratorUseCase: FetchLibraryCuratorUseCase {
    let result: LibraryCuratorResult
    private(set) var capturedRequest: LibraryCuratorRequest?
    private(set) var capturedRequests: [LibraryCuratorRequest] = []
    private var waitTargetCount = 1
    private var continuation: CheckedContinuation<Void, Never>?

    init(result: LibraryCuratorResult) {
        self.result = result
    }

    func execute(request: LibraryCuratorRequest) async throws -> LibraryCuratorResult {
        capturedRequest = request
        capturedRequests.append(request)
        if capturedRequests.count >= waitTargetCount {
            continuation?.resume()
            continuation = nil
        }
        return result
    }

    func waitForRequest() async {
        await waitForRequestCount(1)
    }

    func waitForRequestCount(_ count: Int) async {
        if capturedRequests.count >= count { return }
        waitTargetCount = count
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}

private final class SequencedLibraryCuratorUseCase: FetchLibraryCuratorUseCase {
    private var results: [Result<LibraryCuratorResult, Error>]
    private(set) var capturedRequests: [LibraryCuratorRequest] = []
    private var waitTargetCount = 1
    private var continuation: CheckedContinuation<Void, Never>?

    init(results: [Result<LibraryCuratorResult, Error>]) {
        self.results = results
    }

    func execute(request: LibraryCuratorRequest) async throws -> LibraryCuratorResult {
        capturedRequests.append(request)
        if capturedRequests.count >= waitTargetCount {
            continuation?.resume()
            continuation = nil
        }
        let result = results.isEmpty ? nil : results.removeFirst()
        switch result {
        case .success(let curatorResult):
            return curatorResult
        case .failure(let error):
            throw error
        case .none:
            throw LibraryCuratorError.invalidResponse
        }
    }

    func waitForRequestCount(_ count: Int) async {
        if capturedRequests.count >= count { return }
        waitTargetCount = count
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}

private final class DelayedLibraryCuratorUseCase: FetchLibraryCuratorUseCase {
    let result: LibraryCuratorResult
    private(set) var capturedRequests: [LibraryCuratorRequest] = []
    private var requestContinuation: CheckedContinuation<Void, Never>?
    private var finishContinuation: CheckedContinuation<Void, Never>?
    private var shouldFinish = false

    init(result: LibraryCuratorResult) {
        self.result = result
    }

    func execute(request: LibraryCuratorRequest) async throws -> LibraryCuratorResult {
        capturedRequests.append(request)
        if shouldFinish {
            requestContinuation?.resume()
            requestContinuation = nil
            return result
        }
        await withCheckedContinuation { continuation in
            finishContinuation = continuation
            requestContinuation?.resume()
            requestContinuation = nil
        }
        return result
    }

    func waitForRequest() async {
        if !capturedRequests.isEmpty { return }
        await withCheckedContinuation { continuation in
            requestContinuation = continuation
        }
    }

    func finish() {
        shouldFinish = true
        finishContinuation?.resume()
        finishContinuation = nil
    }
}
