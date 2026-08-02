import Foundation
import OpenAPIRuntime
import XCTest
@testable import GamePediaProduct22API

// MARK: - DateTranscoderTests
//
// Regression cover for a defect that would have broken every Product 2.2
// screen at once.
//
// GamePediaCoreServer serialises timestamps with JavaScript's
// `Date.prototype.toISOString()`, which always emits milliseconds. The
// swift-openapi-runtime default `.iso8601` transcoder does not enable
// `.withFractionalSeconds`, so a client built on the runtime defaults throws
// `dataCorrupted - Expected date string to be ISO8601-formatted` on every
// response carrying a date — Today, Game DNA, Playlog, Replay, articles, all
// of them. `Product22ClientFactory.configuration` installs a transcoder that
// accepts both RFC 3339 forms; these tests keep it that way.

final class DateTranscoderTests: XCTestCase {

    private let transcoder = RFC3339DateTranscoder()

    func testDecodesTimestampWithFractionalSeconds() throws {
        // Exactly what `new Date().toISOString()` produces.
        let date = try transcoder.decode("2026-07-30T09:00:00.000Z")
        XCTAssertEqual(date.timeIntervalSince1970, 1785402000, accuracy: 0.001)
    }

    func testDecodesTimestampWithoutFractionalSeconds() throws {
        // Still valid RFC 3339, so the contract permits it.
        let date = try transcoder.decode("2026-07-30T09:00:00Z")
        XCTAssertEqual(date.timeIntervalSince1970, 1785402000, accuracy: 0.001)
    }

    func testDecodesTimestampWithNumericOffset() throws {
        let date = try transcoder.decode("2026-07-30T18:00:00+09:00")
        XCTAssertEqual(date.timeIntervalSince1970, 1785402000, accuracy: 0.001)
    }

    func testRejectsNonRFC3339Input() {
        XCTAssertThrowsError(try transcoder.decode("2026-07-30")) { error in
            guard case DecodingError.dataCorrupted = error else {
                return XCTFail("expected dataCorrupted, got \(error)")
            }
        }
        XCTAssertThrowsError(try transcoder.decode(""))
        XCTAssertThrowsError(try transcoder.decode("not a date"))
    }

    func testEncodesInTheFormTheServerItselfUses() throws {
        let encoded = try transcoder.encode(Date(timeIntervalSince1970: 1785402000))
        XCTAssertEqual(encoded, "2026-07-30T09:00:00.000Z")
        // and it must round-trip through our own decoder
        XCTAssertEqual(
            try transcoder.decode(encoded).timeIntervalSince1970,
            1785402000,
            accuracy: 0.001
        )
    }

    /// The factory must actually install the transcoder — a correct transcoder
    /// that nothing uses is worth nothing.
    func testFactoryConfigurationUsesTheLenientTranscoder() throws {
        let decoded = try Product22ClientFactory.configuration
            .dateTranscoder
            .decode("2026-07-30T09:00:00.000Z")
        XCTAssertEqual(decoded.timeIntervalSince1970, 1785402000, accuracy: 0.001)
    }

    /// End-to-end proof through a real generated operation: the millisecond
    /// form decodes into `Foundation.Date` fields on the generated types.
    func testMillisecondTimestampsDecodeThroughGeneratedOperation() async throws {
        let transport = FixtureTransport(
            operationID: "getTodayFeed",
            json: try Fixture.data("today_all_sections_ok.json")
        )
        let client = Product22ClientFactory.makeClient(
            baseURL: URL(string: "https://core.gamepedia.example")!,
            transport: transport
        )
        let output = try await client.getTodayFeed(.init(query: .init()))
        let feed = try XCTUnwrap(try output.ok.body.json.value2.data)

        XCTAssertEqual(
            feed.generatedAt.timeIntervalSince1970,
            1785402000,
            accuracy: 0.001
        )
        guard case .editorialCuration(.case1(let curation)) = feed.sections[5] else {
            return XCTFail("expected editorialCuration at index 5")
        }
        XCTAssertNotNil(curation.data.articles[0].publishedAt)
        XCTAssertNotNil(curation.data.articles[1].correctedAt)
    }
}
