import Foundation
import OpenAPIRuntime
import XCTest
@testable import GamePediaProduct22API

/// Reads a single-value `const` that the generator typed as an opaque
/// container rather than an enum.
private func constStatus(
    _ container: OpenAPIRuntime.OpenAPIValueContainer,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> String {
    try XCTUnwrap(container.value as? String, "status const is not a string", file: file, line: line)
}

// MARK: - TodayFeedContractTests
//
// Required gates 3 and 4: the eight success sections decode through the real
// generated `getTodayFeed` operation, and `disabled` / `unavailable` sections
// whose `data` is null decode as such rather than failing the whole feed.

final class TodayFeedContractTests: XCTestCase {

    private func makeClient(fixture: String) throws -> (Client, FixtureTransport) {
        let transport = FixtureTransport(
            operationID: "getTodayFeed",
            json: try Fixture.data(fixture)
        )
        let client = Product22ClientFactory.makeClient(
            baseURL: URL(string: "https://core.gamepedia.example")!,
            transport: transport
        )
        return (client, transport)
    }

    private func feed(
        _ fixture: String
    ) async throws -> Components.Schemas.TodayFeed {
        let (client, _) = try makeClient(fixture: fixture)
        let output = try await client.getTodayFeed(
            .init(query: .init(locale: "ko", timezone: "Asia/Seoul"))
        )
        let payload = try output.ok.body.json
        XCTAssertEqual(
            payload.value1.success.value as? Bool,
            true,
            "envelope success flag must be true"
        )
        return try XCTUnwrap(payload.value2.data, "Today payload missing data")
    }

    // MARK: All eight sections in the ok state

    func testAllEightSuccessSectionsDecode() async throws {
        let feed = try await feed("today_all_sections_ok.json")

        XCTAssertEqual(feed.sections.count, 8)
        XCTAssertEqual(feed.timezone, "Asia/Seoul")
        XCTAssertEqual(feed.locale, "ko")
        XCTAssertFalse(feed.meta.partialFailure)
        XCTAssertEqual(
            feed.meta.sectionOrder,
            [
                "playCompass", "gameDNA", "gameBriefing", "backlogRescue",
                "spoilerFreeStartGuide", "editorialCuration", "monthlyReplay",
                "friendActivity"
            ]
        )

        // The generator recognised `key` as a oneOf discriminator, so each
        // section must land on the case its key names — never on a neighbour.
        var seen: [String] = []
        for section in feed.sections {
            switch section {
            case .playCompass(let value):
                seen.append("playCompass")
                guard case .case1(let ok) = value else {
                    return XCTFail("playCompass should be an ok section")
                }
                XCTAssertEqual(ok.data.recommendations.count, 2)
                XCTAssertEqual(ok.data.confidence, .MEDIUM)
                XCTAssertEqual(ok.data.dataFreshness.candidatePoolSize, 42)
                XCTAssertFalse(ok.data.dataFreshness.stale)
                XCTAssertNil(ok.data.emptyReason)
                let first = ok.data.recommendations[0]
                XCTAssertEqual(first.rank, 1)
                XCTAssertEqual(first.estimatedSessionMinutes, 55)
                XCTAssertEqual(first.estimatedSessionBasis, .playlog_median)
                XCTAssertTrue(first.ownershipEvidence.ownershipVerified)
                XCTAssertEqual(first.ownershipEvidence.provenance, .PROVIDER_VERIFIED)
                XCTAssertTrue(first.reasonCodes.contains(.fits_available_time))
                // Install state is explicitly not tracked by the server; the
                // contract pins it so the client can never claim otherwise.
                XCTAssertEqual(first.ownershipEvidence.installEvidence.known, false)

            case .gameDNA(let value):
                seen.append("gameDNA")
                guard case .case1(let ok) = value else {
                    return XCTFail("gameDNA should be an ok section")
                }
                XCTAssertEqual(ok.data.signalCount, 68)
                XCTAssertEqual(ok.data.confidence, .HIGH)
                XCTAssertEqual(ok.data.topGenres.count, 3)
                XCTAssertEqual(ok.data.sessionLengthLabel, .MIXED)
                XCTAssertEqual(ok.data.socialLabel, .SINGLEPLAYER)
                XCTAssertEqual(ok.data.toneLabel, .CHALLENGE)
                XCTAssertEqual(ok.data.missingSignals.count, 2)

            case .gameBriefing(let value):
                seen.append("gameBriefing")
                guard case .case1(let ok) = value else {
                    return XCTFail("gameBriefing should be an ok section")
                }
                XCTAssertEqual(ok.data.items.count, 1)
                XCTAssertEqual(ok.data.items[0].noteworthyReleases.count, 2)
                XCTAssertEqual(
                    ok.data.items[0].noteworthyReleases[1].serviceStatus,
                    .SUNSET_ANNOUNCED
                )

            case .backlogRescue(let value):
                seen.append("backlogRescue")
                guard case .case1(let ok) = value else {
                    return XCTFail("backlogRescue should be an ok section")
                }
                XCTAssertEqual(ok.data.items.count, 1)
                XCTAssertEqual(ok.data.items[0].ownershipProvenance, .PROVIDER_VERIFIED)

            case .spoilerFreeStartGuide(let value):
                seen.append("spoilerFreeStartGuide")
                guard case .case1(let ok) = value else {
                    return XCTFail("spoilerFreeStartGuide should be an ok section")
                }
                XCTAssertEqual(ok.data.items.count, 1)
                XCTAssertEqual(ok.data.items[0].libraryStatus, .BACKLOG)
                XCTAssertEqual(ok.data.items[0].estimatedFirstSessionMinutes, 90)

            case .editorialCuration(let value):
                seen.append("editorialCuration")
                guard case .case1(let ok) = value else {
                    return XCTFail("editorialCuration should be an ok section")
                }
                XCTAssertEqual(ok.data.articles.count, 2)
                XCTAssertEqual(ok.data.articles[0].status, .PUBLISHED)
                XCTAssertEqual(ok.data.articles[1].status, .CORRECTED)
                XCTAssertNotNil(ok.data.articles[1].correctedAt)
                // Withheld hero: null image plus a reason, never a broken URL.
                XCTAssertNil(ok.data.articles[1].heroImage)
                XCTAssertEqual(
                    ok.data.articles[1].heroImageWithheldReason,
                    "rights_status_unresolved"
                )
                XCTAssertEqual(ok.data.articles[0].sourceCount, 4)

            case .monthlyReplay(let value):
                seen.append("monthlyReplay")
                guard case .case1(let ok) = value else {
                    return XCTFail("monthlyReplay should be an ok section")
                }
                XCTAssertEqual(ok.data.monthKey, "2026-07")
                XCTAssertEqual(ok.data.timezone, "Asia/Seoul")
                XCTAssertEqual(ok.data.playedDayCount, 18)
                XCTAssertEqual(ok.data.totalMinutes, 1265)
                XCTAssertEqual(ok.data.mostPlayedGame?.sessionCount, 11)
                XCTAssertEqual(ok.data.missingData.count, 1)

            case .friendActivity(let value):
                seen.append("friendActivity")
                guard case .case1(let ok) = value else {
                    return XCTFail("friendActivity should be an ok section")
                }
                XCTAssertEqual(ok.data.items.count, 2)
                XCTAssertEqual(ok.data.items[0].activityType, .REVIEW_CREATED)
                // A legacy Steam sync row carries no canonical catalog id.
                XCTAssertNil(ok.data.items[1].catalogGameId)
            }
        }

        XCTAssertEqual(seen, feed.meta.sectionOrder, "sections decoded out of order")
    }

    // MARK: disabled / unavailable with data: null

    func testDisabledAndUnavailableSectionsDecodeWithNullData() async throws {
        let feed = try await feed("today_degraded_sections.json")

        XCTAssertEqual(feed.sections.count, 8)
        XCTAssertTrue(feed.meta.partialFailure)

        // Four sections declare `status` as an enum of disabled|unavailable, so
        // the generator types them as an enum. The other four can only ever be
        // `unavailable`, so their single-value const is typed as an opaque
        // container. Both shapes have to be read, which is exactly why the app
        // normalises them into one domain status in the mapper.
        var disabled = 0
        var unavailable = 0
        func tally(status: String, reason: String, data: OpenAPIRuntime.OpenAPIObjectContainer?) {
            XCTAssertNil(data, "a degraded section must carry null data")
            XCTAssertFalse(reason.isEmpty, "a degraded section must explain itself")
            if status == "disabled" { disabled += 1 } else { unavailable += 1 }
        }

        for section in feed.sections {
            switch section {
            case .playCompass(let value):
                guard case .case2(let d) = value else {
                    return XCTFail("playCompass should be degraded")
                }
                tally(status: d.status.rawValue, reason: d.reasonCode, data: d.data)
            case .gameDNA(let value):
                guard case .case2(let d) = value else {
                    return XCTFail("gameDNA should be degraded")
                }
                tally(status: d.status.rawValue, reason: d.reasonCode, data: d.data)
            case .editorialCuration(let value):
                guard case .case2(let d) = value else {
                    return XCTFail("editorialCuration should be degraded")
                }
                tally(status: d.status.rawValue, reason: d.reasonCode, data: d.data)
            case .monthlyReplay(let value):
                guard case .case2(let d) = value else {
                    return XCTFail("monthlyReplay should be degraded")
                }
                tally(status: d.status.rawValue, reason: d.reasonCode, data: d.data)
            case .gameBriefing(let value):
                guard case .case2(let d) = value else {
                    return XCTFail("gameBriefing should be degraded")
                }
                tally(status: try constStatus(d.status), reason: d.reasonCode, data: d.data)
            case .backlogRescue(let value):
                guard case .case2(let d) = value else {
                    return XCTFail("backlogRescue should be degraded")
                }
                tally(status: try constStatus(d.status), reason: d.reasonCode, data: d.data)
            case .spoilerFreeStartGuide(let value):
                guard case .case2(let d) = value else {
                    return XCTFail("spoilerFreeStartGuide should be degraded")
                }
                tally(status: try constStatus(d.status), reason: d.reasonCode, data: d.data)
            case .friendActivity(let value):
                guard case .case2(let d) = value else {
                    return XCTFail("friendActivity should be degraded")
                }
                tally(status: try constStatus(d.status), reason: d.reasonCode, data: d.data)
            }
        }

        XCTAssertEqual(disabled, 3)
        XCTAssertEqual(unavailable, 5)
    }

    // MARK: one failed section must not take the feed down

    func testMixedFeedKeepsHealthySectionsWhenOneSectionFails() async throws {
        let feed = try await feed("today_mixed_sections.json")

        XCTAssertEqual(feed.sections.count, 4)
        XCTAssertTrue(feed.meta.partialFailure)

        guard case .gameDNA(.case2(let broken)) = feed.sections[1] else {
            return XCTFail("expected gameDNA to be the unavailable section")
        }
        XCTAssertEqual(broken.status, .unavailable)

        // An empty-but-successful Play Compass is a normal state, not an error.
        guard case .playCompass(.case1(let compass)) = feed.sections[0] else {
            return XCTFail("expected playCompass to be ok")
        }
        XCTAssertTrue(compass.data.recommendations.isEmpty)
        XCTAssertEqual(compass.data.confidence, .LOW)
        XCTAssertEqual(compass.data.emptyReason, .no_owned_playing_or_backlog_games)
        XCTAssertTrue(compass.data.dataFreshness.stale)

        guard case .editorialCuration(.case1(let curation)) = feed.sections[2] else {
            return XCTFail("expected editorialCuration to be ok")
        }
        XCTAssertTrue(curation.data.articles.isEmpty)
        XCTAssertEqual(curation.data.emptyReason, "no_published_articles")

        guard case .monthlyReplay(.case1(let replay)) = feed.sections[3] else {
            return XCTFail("expected monthlyReplay to be ok")
        }
        XCTAssertTrue(replay.data.isEmpty)
        XCTAssertNil(replay.data.mostPlayedGame)
        XCTAssertTrue(replay.data.missingData.isEmpty)
    }

    // MARK: request shape

    func testTodayRequestCarriesLocaleAndTimezoneQuery() async throws {
        let (client, transport) = try makeClient(fixture: "today_all_sections_ok.json")
        _ = try await client.getTodayFeed(
            .init(query: .init(locale: "ja", timezone: "Asia/Tokyo", limit: 8))
        )

        let entries = await transport.recorded
        let recorded = try XCTUnwrap(entries.first)
        let path = try XCTUnwrap(recorded.request.path)
        XCTAssertTrue(path.hasPrefix("/api/v1/users/me/today"), "unexpected path \(path)")
        XCTAssertTrue(path.contains("locale=ja"), "locale not sent: \(path)")
        XCTAssertTrue(path.contains("timezone=Asia/Tokyo") || path.contains("timezone=Asia%2FTokyo"),
                      "timezone not sent: \(path)")
        XCTAssertTrue(path.contains("limit=8"), "limit not sent: \(path)")
        // No middleware was installed, so nothing may have added credentials.
        XCTAssertNil(recorded.request.headerFields[.authorization])
    }
}
