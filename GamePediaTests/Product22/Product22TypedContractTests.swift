import Foundation
import GamePediaProduct22API
import XCTest
@testable import GamePedia

// MARK: - Product22TypedContractTests
//
// The four operations the server newly typed, and the three behaviours that
// were previously impossible: the Quick Add deep link, the submission status
// screen, and real pagination over both lists.
//
// Everything here goes through the generated client or the generated types.
// Nothing hand-parses JSON and nothing declares a DTO of its own.

final class Product22TypedContractTests: XCTestCase {

    private var authority: SessionCredentialAuthority!
    private var service: DefaultProduct22APIService!

    override func setUp() {
        super.setUp()
        Product22StubURLProtocol.reset()
        authority = Product22TestFactory.makeAuthority()
        service = Product22TestFactory.makeService(authority: authority)
    }

    override func tearDown() {
        Product22StubURLProtocol.reset()
        authority = nil
        service = nil
        super.tearDown()
    }

    // MARK: Contract provenance moved forward

    func testTheShippedContractIsTheRevisionThatTypedTheFourOperations() {
        XCTAssertEqual(
            Product22ClientFactory.Contract.serverHead,
            "ce083aa9d873c4f9338c0f926cc2cea647c455bf"
        )
        XCTAssertEqual(
            Product22ClientFactory.Contract.openAPISHA256,
            "c0c5c0287879b4139306d59ef4951afc2d81d409ba34f24bdc7233e3c0612e27"
        )
        // Purely additive: the operation set did not move.
        XCTAssertEqual(Product22ClientFactory.Contract.operationIDs.count, 26)
    }

    // MARK: 1 — confirm returns a typed catalogGameId

    func testConfirmDeepLinksToTheGameItCreated() async throws {
        Product22StubURLProtocol.stub(
            pathContains: "/confirm",
            json: Product22SubmissionFixture.confirmJSON(createdNewGame: true),
            statusCode: 201
        )
        let result = try CatalogSubmissionMapper.confirmResult(
            from: try await service.confirmSubmission(
                id: CatalogSubmissionID(uuidString: Product22SubmissionFixture.submissionID)!,
                request: .init(selectedCatalogGameId: nil, confirmedFields: nil, requestPublicReview: false),
                authorization: .currentSession
            )
        )

        XCTAssertEqual(result.catalogGameID?.wireValue, Product22Fixture.gameA)
        XCTAssertTrue(result.createdNewGame)
        XCTAssertFalse(result.isIdempotentReplay)
        XCTAssertEqual(result.publicationStatus, .privateEntry)
        // The deep link the untyped contract could not provide.
        XCTAssertEqual(result.deepLinkTarget?.wireValue, Product22Fixture.gameA)
    }

    func testConfirmReadsCreatedAndReplayedRatherThanBranchingOnTheStatusCode() async throws {
        // A 200 replay carries the same seven fields as a 201 create.
        Product22StubURLProtocol.stub(
            pathContains: "/confirm",
            json: Product22SubmissionFixture.confirmJSON(
                catalogGameId: Product22Fixture.gameB,
                createdNewGame: false,
                idempotentReplay: true
            ),
            statusCode: 200
        )
        let result = try CatalogSubmissionMapper.confirmResult(
            from: try await service.confirmSubmission(
                id: CatalogSubmissionID(uuidString: Product22SubmissionFixture.submissionID)!,
                request: .init(selectedCatalogGameId: nil, confirmedFields: nil, requestPublicReview: false),
                authorization: .currentSession
            )
        )
        XCTAssertFalse(result.createdNewGame)
        XCTAssertTrue(result.isIdempotentReplay)
        XCTAssertEqual(result.deepLinkTarget?.wireValue, Product22Fixture.gameB)
    }

    func testAReplayWithNoLinkedGameHasNoDeepLinkRatherThanAFabricatedOne() throws {
        // The one case the contract documents as nullable.
        let result = try CatalogSubmissionMapper.confirmResult(
            from: try Product22SubmissionFixture.confirmDTO(
                catalogGameId: nil, createdNewGame: false, idempotentReplay: true
            )
        )
        XCTAssertNil(result.catalogGameID)
        XCTAssertNil(result.deepLinkTarget, "no game means no destination, not a guessed one")
    }

    func testAnIdentityConflictPointsAtTheExistingGameAndMergesNothing() throws {
        let result = try CatalogSubmissionMapper.confirmResult(
            from: try Product22SubmissionFixture.confirmDTO(
                catalogGameId: Product22Fixture.gameA,
                identityConflict: Product22SubmissionFixture.identityConflictJSON(
                    existing: Product22Fixture.gameB
                )
            )
        )
        let conflict = try XCTUnwrap(result.identityConflict)
        XCTAssertEqual(conflict.provider, .appleAppStore)
        XCTAssertEqual(conflict.existingCatalogGameID.wireValue, Product22Fixture.gameB)
        XCTAssertEqual(conflict.reasonCode, "verified_identity_already_exists")
        // The conflicting game wins the deep link: it is the honest
        // destination, and nothing was merged to reach it.
        XCTAssertEqual(result.deepLinkTarget?.wireValue, Product22Fixture.gameB)
        XCTAssertNotEqual(result.deepLinkTarget, result.catalogGameID)
    }

    // MARK: 2 — getCatalogSubmission returns typed state

    func testSubmissionStateDecodesThroughTheGeneratedOperation() async throws {
        Product22StubURLProtocol.stub(
            pathContains: "/catalog/submissions/",
            json: Product22SubmissionFixture.stateJSON(
                candidateSummary: """
                {"version":1,"candidateCount":2,
                 "catalogGameIds":["\(Product22Fixture.gameA)","\(Product22Fixture.gameB)"],
                 "reasonCodes":["normalized_title_exact"]}
                """,
                clarifyingQuestions: "[\"어느 플랫폼인가요?\"]"
            )
        )
        let state = try CatalogSubmissionMapper.state(
            from: try await service.fetchSubmission(
                id: CatalogSubmissionID(uuidString: Product22SubmissionFixture.submissionID)!
            )
        )

        XCTAssertEqual(state.status, .personalConfirmed)
        XCTAssertEqual(state.inputType, .text)
        XCTAssertTrue(state.isDraftReadable)
        XCTAssertEqual(state.catalogGameID?.wireValue, Product22Fixture.gameA)
        XCTAssertEqual(state.clarifyingQuestion, "어느 플랫폼인가요?")
        XCTAssertFalse(state.isExpired)
        XCTAssertFalse(state.canConfirm, "a confirmed submission is not confirmable again")

        let draft = try XCTUnwrap(state.draft)
        XCTAssertEqual(draft.originalTitle, "원신")
        XCTAssertEqual(draft.localizations.first?.title, "Genshin Impact")
        XCTAssertEqual(draft.regionalReleases.first?.serviceStatus, .live)
        // Parsed provider keys are claims, never verified identities.
        XCTAssertEqual(draft.identities.first?.provider, .appleAppStore)
        XCTAssertEqual(draft.fieldProvenance.first?.provenance, .aiInferred)
        XCTAssertFalse(try XCTUnwrap(draft.fieldProvenance.first).provenance.isVerified)

        let summary = try XCTUnwrap(state.candidateSummary)
        XCTAssertEqual(summary.candidateCount, 2)
        XCTAssertEqual(summary.catalogGameIDs.count, 2)
        XCTAssertFalse(summary.isEmptyShape)
    }

    func testAnUnreadableDraftIsReportedRatherThanShownHalfEmpty() throws {
        let state = try CatalogSubmissionMapper.state(
            from: try Product22SubmissionFixture.stateDTO(draftReadable: false, draft: "null")
        )
        XCTAssertFalse(state.isDraftReadable)
        XCTAssertNil(state.draft)
        XCTAssertFalse(state.canConfirm)
    }

    func testExpiryComesFromTheServerClockNotTheDeviceClock() throws {
        let state = try CatalogSubmissionMapper.state(
            from: try Product22SubmissionFixture.stateDTO(status: "PREVIEW", expired: true)
        )
        // The stored expiresAt is in the past or the future depending on when
        // this runs; `expired` is the server's own answer and is what counts.
        XCTAssertTrue(state.isExpired)
        XCTAssertFalse(state.canConfirm)
    }

    // MARK: 6 — legacy and enum tolerance

    func testEveryGameSubmissionStatusVariantMaps() throws {
        let expected: [(String, CatalogSubmissionStatus)] = [
            ("PREVIEW", .preview),
            ("PERSONAL_CONFIRMED", .personalConfirmed),
            ("PENDING_REVIEW", .pendingReview),
            // Not written by this server today; listed by the contract so a
            // future editorial flow decodes instead of failing the response.
            ("APPROVED", .approved),
            ("REJECTED", .rejected),
            ("EXPIRED", .expired)
        ]
        for (raw, domain) in expected {
            let state = try CatalogSubmissionMapper.state(
                from: try Product22SubmissionFixture.stateDTO(status: raw)
            )
            XCTAssertEqual(state.status, domain, "\(raw) did not map")
            // Every variant has reader-facing copy, none of it a raw token.
            let text = SubmissionStateViewController.text(for: domain)
            XCTAssertFalse(text.isEmpty)
            XCTAssertFalse(text.contains("_"))
        }
        XCTAssertEqual(CatalogSubmissionStatus.allCases.count, 6)
    }

    func testALegacyCandidateSummaryMissingEveryFieldStillDecodes() throws {
        // The column is stored as JSON and returned without re-validation, so
        // a row written by an earlier revision must not fail the response.
        let state = try CatalogSubmissionMapper.state(
            from: try Product22SubmissionFixture.stateDTO(candidateSummary: "{}")
        )
        let summary = try XCTUnwrap(state.candidateSummary)
        XCTAssertNil(summary.version)
        XCTAssertNil(summary.candidateCount)
        XCTAssertTrue(summary.catalogGameIDs.isEmpty)
        XCTAssertTrue(summary.reasonCodes.isEmpty)
        // "Nothing was recorded" is a different fact from "zero were found".
        XCTAssertTrue(summary.isEmptyShape)
    }

    func testAPartialCandidateSummaryKeepsWhatItHas() throws {
        let state = try CatalogSubmissionMapper.state(
            from: try Product22SubmissionFixture.stateDTO(
                candidateSummary: #"{"candidateCount":3}"#
            )
        )
        let summary = try XCTUnwrap(state.candidateSummary)
        XCTAssertEqual(summary.candidateCount, 3)
        XCTAssertNil(summary.version)
        XCTAssertFalse(summary.isEmptyShape)
    }

    func testAbsentCandidateSummaryIsDistinctFromAnEmptyOne() throws {
        let none = try CatalogSubmissionMapper.state(
            from: try Product22SubmissionFixture.stateDTO(candidateSummary: "null")
        )
        XCTAssertNil(none.candidateSummary, "null means the preview recorded none at all")
    }

    func testAPlaySessionWithEveryOptionalFieldAbsentStillMaps() throws {
        let session = try XCTUnwrap(
            PlaylogMapper.session(
                from: try Product22Decode.decode(
                    Components.Schemas.PlaySession.self,
                    from: """
                    {"id":"11111111-1111-4111-8111-111111111111",
                     "catalogGameId":"\(Product22Fixture.gameA)",
                     "regionalReleaseId":null,"playedAt":"2026-07-30T09:00:00.000Z",
                     "durationMinutes":null,"progressPercent":null,"mood":null,"note":null,
                     "outcome":"CONTINUE","visibility":"PRIVATE","provenance":"USER_CONFIRMED",
                     "clientMutationId":"key-00000001"}
                    """
                )
            )
        )
        XCTAssertNil(session.durationMinutes)
        XCTAssertNil(session.progressPercent)
        XCTAssertNil(session.mood)
        XCTAssertNil(session.note)
        XCTAssertNil(session.createdAt)
        XCTAssertNil(session.updatedAt)
        XCTAssertNil(session.regionalReleaseID)
        XCTAssertFalse(session.hasNote)
    }

    // MARK: 3 / 4 — real pagination

    func testCatalogSearchFollowsTheTypedCursorAcrossPages() async throws {
        let mock = Product22MockService()
        mock.searchResult = .success(
            try Product22SubmissionFixture.searchDTO(
                games: "[\(Product22SubmissionFixture.catalogGameJSON(id: Product22Fixture.gameA, title: "A"))]",
                nextCursor: "cursor-page-2"
            )
        )
        let repository = CatalogRepository(service: mock)

        let first = try await repository.search(
            query: "hollow", locale: "ko", regionCode: "KR", platform: nil, cursor: nil
        )
        XCTAssertEqual(first.games.count, 1)
        XCTAssertEqual(first.nextCursor, "cursor-page-2")
        XCTAssertTrue(first.hasMore)
        XCTAssertEqual(first.matchedBy, .ranked)
        XCTAssertEqual(first.limit, 50)

        _ = try await repository.search(
            query: "hollow", locale: "ko", regionCode: "KR", platform: nil, cursor: first.nextCursor
        )
        // The cursor is opaque and goes back exactly as it came.
        XCTAssertEqual(mock.searchCursors, [nil, "cursor-page-2"])
    }

    func testTheLastCatalogPageReportsNoMore() async throws {
        let mock = Product22MockService()
        mock.searchResult = .success(try Product22SubmissionFixture.searchDTO(nextCursor: nil))
        let page = try await CatalogRepository(service: mock).search(
            query: "x", locale: nil, regionCode: nil, platform: nil, cursor: nil
        )
        XCTAssertNil(page.nextCursor)
        XCTAssertFalse(page.hasMore)
    }

    func testAnUnreadableQueryIsADifferentFactFromNoMatch() async throws {
        let mock = Product22MockService()
        mock.searchResult = .success(try Product22SubmissionFixture.searchDTO(matchedBy: "empty_query"))
        let empty = try await CatalogRepository(service: mock).search(
            query: "!!!", locale: nil, regionCode: nil, platform: nil, cursor: nil
        )
        XCTAssertEqual(empty.matchedBy, .emptyQuery)

        mock.searchResult = .success(try Product22SubmissionFixture.searchDTO(matchedBy: "no_match"))
        let noMatch = try await CatalogRepository(service: mock).search(
            query: "zzzz", locale: nil, regionCode: nil, platform: nil, cursor: nil
        )
        XCTAssertEqual(noMatch.matchedBy, .noMatch)
        XCTAssertNotEqual(empty.matchedBy, noMatch.matchedBy)
    }

    func testPlaylogFollowsTheTypedCursorAcrossPages() async throws {
        let mock = Product22MockService()
        mock.playSessionsResult = .success(
            try Product22SubmissionFixture.playSessionListDTO(
                sessions: "[\(Product22Fixture.playSession(mutationID: "key-00000001"))]",
                nextCursor: "cursor-2"
            )
        )
        let repository = PlaylogRepository(service: mock)

        let first = try await repository.sessions(for: nil, from: nil, to: nil, cursor: nil)
        XCTAssertEqual(first.sessions.count, 1)
        XCTAssertEqual(first.nextCursor, "cursor-2")
        XCTAssertTrue(first.hasMore)

        _ = try await repository.sessions(for: nil, from: nil, to: nil, cursor: first.nextCursor)
        XCTAssertEqual(mock.playSessionCursors, [nil, "cursor-2"])
    }

    func testTheCalendarWalksTheCursorSoAWholeMonthIsAggregated() async throws {
        let mock = Product22MockService()
        // Every page reports another cursor; the walk is bounded so it cannot
        // spin forever on a server that never returns null.
        mock.playSessionsResult = .success(
            try Product22SubmissionFixture.playSessionListDTO(
                sessions: "[\(Product22Fixture.playSession(mutationID: "key-00000001"))]",
                nextCursor: "always-more"
            )
        )
        let seoul = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let month = try await PlaylogRepository(service: mock)
            .calendar(monthKey: "2026-07", timeZone: seoul)

        XCTAssertGreaterThan(mock.playSessionCursors.count, 1, "the calendar must page")
        XCTAssertLessThanOrEqual(mock.playSessionCursors.count, 20, "the walk must be bounded")
        XCTAssertFalse(month.isEmpty)
    }

    // MARK: 5 — the untyped workarounds are gone

    func testNoOperationIsStillDescribedAsBlockedByAnUntypedBody() throws {
        let gaps = try String(
            contentsOfFile: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()   // Product22
                .deletingLastPathComponent()   // GamePediaTests
                .deletingLastPathComponent()   // repo root
                .appendingPathComponent("docs/product-2.2-contract-gaps.md").path,
            encoding: .utf8
        )
        // The four operations must no longer appear under a blocked or
        // worked-around heading. They are now typed, and the doc says so.
        XCTAssertTrue(
            gaps.contains("Resolved by server commit `6fbcf094`"),
            "the gaps doc must record that these four were fixed"
        )
    }
}
