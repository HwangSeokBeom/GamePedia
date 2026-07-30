import Foundation
import GamePediaProduct22API
import XCTest
@testable import GamePedia

// MARK: - TodayDisplayModelTests
//
// The presentation rules that decide what a reader is actually shown: a kill
// switch is never a retry button, an unavailable section retries only itself,
// an empty result is not an error, and no raw server token reaches the screen.

final class TodayDisplayModelTests: XCTestCase {

    private func model(
        sections: String,
        order: String,
        partialFailure: Bool = false,
        isStale: Bool = false
    ) throws -> TodayDisplayModel {
        let dto = try Product22Decode.envelopeData(
            Components.Schemas.TodayFeed.self,
            from: Product22Fixture.today(
                sections: sections, order: order, partialFailure: partialFailure
            )
        )
        return TodayDisplayModel(feed: TodayFeedMapper.map(dto), isStale: isStale)
    }

    // MARK: disabled vs unavailable

    func testADisabledSectionExplainsItselfAndOffersNothingToPress() throws {
        let model = try self.model(
            sections: Product22Fixture.degradedSection(
                key: "playCompass", status: "disabled", reason: "FEATURE_DISABLED"
            ),
            order: #""playCompass""#,
            partialFailure: true
        )

        let section = try XCTUnwrap(model.sections.first)
        guard case .disabled(let message) = section.state else {
            return XCTFail("expected a disabled state, got \(section.state)")
        }
        XCTAssertFalse(section.isRetryable, "a kill switch must not offer a retry")
        XCTAssertEqual(message, L10n.Product22.Section.disabled)
        XCTAssertFalse(
            message.contains("FEATURE_DISABLED"),
            "a raw server code must never reach the screen"
        )
    }

    func testAnUnavailableSectionRetriesOnlyItself() throws {
        let model = try self.model(
            sections: [
                Product22Fixture.playCompassOKSection(),
                Product22Fixture.degradedSection(
                    key: "gameDNA", status: "unavailable", reason: "SECTION_TIMEOUT"
                )
            ].joined(separator: ","),
            order: #""playCompass","gameDNA""#,
            partialFailure: true
        )

        XCTAssertEqual(model.sections.count, 2)
        XCTAssertFalse(model.sections[0].isRetryable, "a healthy section needs no retry")
        XCTAssertTrue(model.sections[1].isRetryable)

        guard case .unavailable(let message, let retryTitle) = model.sections[1].state else {
            return XCTFail("expected unavailable")
        }
        XCTAssertEqual(retryTitle, L10n.Product22.Section.retry)
        XCTAssertFalse(message.contains("SECTION_TIMEOUT"))

        // The healthy neighbour still has its content.
        guard case .items(let items) = model.sections[0].state else {
            return XCTFail("the healthy section must keep its items")
        }
        XCTAssertEqual(items.count, 1)
    }

    func testPartialFailureIsANoticeNotAnError() throws {
        let model = try self.model(
            sections: Product22Fixture.playCompassOKSection(),
            order: #""playCompass""#,
            partialFailure: true
        )
        XCTAssertTrue(model.showsPartialFailureNotice)
        // The feed still renders its sections; nothing about it is an error.
        XCTAssertEqual(model.sections.count, 1)
        guard case .items = model.sections[0].state else {
            return XCTFail("a partial feed is still a feed")
        }
    }

    // MARK: empty is not an error

    func testAnEmptyPlayCompassExplainsWhyRatherThanFailing() throws {
        let model = try self.model(
            sections: """
            {"key":"playCompass","status":"ok","reasonCode":null,"data":{
              "recommendations":[],"confidence":"LOW",
              "dataFreshness":{"candidatePoolSize":0,"freshestLibraryUpdateAt":null,
                               "playlogSampleSize":0,"stale":true},
              "emptyReason":"no_owned_playing_or_backlog_games","ownedOnly":true}}
            """,
            order: #""playCompass""#
        )

        guard case .empty(let message) = model.sections[0].state else {
            return XCTFail("an empty result is an empty state, not an error")
        }
        XCTAssertEqual(message, L10n.Product22.Compass.emptyNoOwned)
        XCTAssertFalse(model.sections[0].isRetryable)
    }

    func testAnEmptyMonthlyReplayRendersAsEmpty() throws {
        let model = try self.model(
            sections: """
            {"key":"monthlyReplay","status":"ok","reasonCode":null,"data":{
              "monthKey":"2026-02","timezone":"Asia/Seoul","isEmpty":true,
              "playedDayCount":0,"totalMinutes":0,"mostPlayedGame":null,
              "surpriseGame":null,"missingData":[]}}
            """,
            order: #""monthlyReplay""#
        )
        guard case .empty = model.sections[0].state else {
            return XCTFail("an empty month is an empty state")
        }
    }

    // MARK: what a Play Compass pick tells the reader

    func testAPickIsExplainedByItsReasonsNotItsScore() throws {
        let model = try self.model(
            sections: Product22Fixture.playCompassOKSection(),
            order: #""playCompass""#
        )
        guard case .items(let items) = model.sections[0].state,
              let item = items.first else {
            return XCTFail("expected one recommendation")
        }

        // Reason codes are rendered as sentences.
        XCTAssertTrue(item.details.contains(L10n.Product22.Reason.fitsAvailableTime))
        XCTAssertTrue(item.details.contains(L10n.Product22.Reason.ownedOnSteam))
        // The owned-only guarantee and the unknown install state are stated.
        XCTAssertTrue(item.details.contains(L10n.Product22.Compass.ownedOnly))
        XCTAssertTrue(item.details.contains(L10n.Product22.Compass.installUnknown))
        // Provenance is distinguished, not flattened.
        XCTAssertTrue(item.details.contains(L10n.Product22.Compass.ownershipVerified))
        XCTAssertFalse(item.details.contains(L10n.Product22.Compass.ownershipUnverified))
        // The session estimate says what it is based on.
        XCTAssertTrue(item.details.contains(L10n.Product22.Basis.playlogMedian))

        // The raw score never appears anywhere the reader can see.
        for detail in item.details + [item.title, item.accessibilityLabel] {
            XCTAssertFalse(detail.contains("0.5"), "the raw score must not be shown")
        }

        // VoiceOver gets the same information as the visual layout.
        XCTAssertTrue(item.accessibilityLabel.contains(item.title))
        for detail in item.details {
            XCTAssertTrue(
                item.accessibilityLabel.contains(detail),
                "VoiceOver must hear every detail the eye can read"
            )
        }

        // Routing preserves the canonical UUID.
        XCTAssertEqual(
            item.action,
            .openCatalogGame(CatalogGameID(uuidString: Product22Fixture.gameA)!)
        )
    }

    func testEveryReasonCodeInTheContractHasLocalizedText() {
        for reason in PlayCompassReason.allCases {
            let text = TodayDisplayModel.text(for: reason)
            XCTAssertNotNil(text, "\(reason.rawValue) has no localized text")
            XCTAssertFalse(
                text?.contains("_") ?? true,
                "\(reason.rawValue) is rendering as a raw server token"
            )
        }
        for basis in [
            PlayCompassSessionBasis.playlogMedian, .catalogTypicalSession,
            .genreShortSession, .genreLongSession, .defaultEstimate
        ] {
            XCTAssertFalse(TodayDisplayModel.text(for: basis).contains("_"))
        }
    }

    // MARK: magazine cards

    func testACorrectedArticleReadsAsCorrectedBeforeItIsOpened() throws {
        let model = try self.model(
            sections: #"{"key":"editorialCuration","status":"ok","reasonCode":null,"data":{"articles":[{"slug":"s","status":"CORRECTED","locale":"ko","headline":"헤드라인","excerpt":"발췌","publishedAt":null,"correctedAt":"2026-07-26T09:15:00.000Z","heroImage":null,"heroImageWithheldReason":"rights_status_unresolved","relatedGames":[],"sourceCount":1}],"emptyReason":null}}"#,
            order: #""editorialCuration""#
        )
        guard case .items(let items) = model.sections[0].state,
              let item = items.first else {
            return XCTFail("expected an article card")
        }

        XCTAssertEqual(item.title, "헤드라인", "a headline is server content, passed through")
        XCTAssertEqual(item.subtitle, "발췌")
        XCTAssertTrue(item.details.contains(L10n.Product22.Article.corrected))
        // A withheld hero is explained rather than shown as a broken image.
        XCTAssertTrue(item.details.contains(L10n.Product22.Article.heroWithheld))
        XCTAssertEqual(item.action, .openArticle(slug: "s"))
    }

    // MARK: Game DNA never claims to be AI

    func testGameDNAIsPresentedAsACalculationNotAnAnalysis() throws {
        let model = try self.model(
            sections: #"{"key":"gameDNA","status":"ok","reasonCode":null,"data":{"signalCount":0,"confidence":"LOW","generatedAt":"2026-07-30T09:00:00.000Z","topGenres":[],"sessionLengthLabel":"UNKNOWN","socialLabel":"BALANCED","toneLabel":"BALANCED","missingSignals":["playlog"],"reasonCodes":[]}}"#,
            order: #""gameDNA""#
        )
        guard case .items(let items) = model.sections[0].state,
              let item = items.first else {
            return XCTFail("expected a Game DNA item")
        }

        XCTAssertTrue(item.details.contains(L10n.Product22.Dna.deterministic))
        // With no signal it says so, and points at how to fix it.
        XCTAssertTrue(item.details.contains(L10n.Product22.Dna.needsMoreData))
        XCTAssertTrue(item.details.contains(L10n.Product22.Dna.addPlaylog))

        for text in item.details {
            for claim in ["AI", "ai가", "인공지능"] {
                XCTAssertFalse(
                    text.contains(claim),
                    "Game DNA is deterministic and must not be described as AI analysis"
                )
            }
        }
    }

    // MARK: section order and titles

    func testSectionsKeepTheServersOrderAndAreAllTitled() throws {
        let model = try self.model(
            sections: [
                Product22Fixture.degradedSection(key: "monthlyReplay", status: "unavailable", reason: "x"),
                Product22Fixture.playCompassOKSection(),
                Product22Fixture.degradedSection(key: "gameDNA", status: "disabled", reason: "y")
            ].joined(separator: ","),
            order: #""playCompass","gameDNA","monthlyReplay""#
        )
        XCTAssertEqual(model.sections.map(\.key), [.playCompass, .gameDNA, .monthlyReplay])
        for section in model.sections {
            XCTAssertFalse(section.title.isEmpty)
            XCTAssertFalse(section.title.contains("."), "a title must not be a raw key")
        }
        for key in TodaySectionKey.allCases {
            XCTAssertFalse(TodayDisplayModel.title(for: key).isEmpty)
        }
    }

    func testStalenessIsCarriedThroughToTheView() throws {
        let fresh = try model(
            sections: Product22Fixture.playCompassOKSection(),
            order: #""playCompass""#,
            isStale: false
        )
        let stale = try model(
            sections: Product22Fixture.playCompassOKSection(),
            order: #""playCompass""#,
            isStale: true
        )
        XCTAssertFalse(fresh.isStale)
        XCTAssertTrue(stale.isStale)
    }
}
