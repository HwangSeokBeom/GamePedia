import Foundation
import GamePediaProduct22API
import XCTest
@testable import GamePedia

// MARK: - Product22ContractTests
//
// Required areas 1–5, 7, 10, 15–18, 20: the contract as the app consumes it,
// exercised through the real generated operations over a URLProtocol stub.

final class Product22ContractTests: XCTestCase {

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

    // MARK: 1 — contract provenance

    func testShippedContractMatchesTheServerHeadAndHashTheAppClaims() throws {
        XCTAssertEqual(
            Product22ClientFactory.Contract.serverHead,
            "ce083aa9d873c4f9338c0f926cc2cea647c455bf"
        )
        XCTAssertEqual(
            Product22ClientFactory.Contract.openAPISHA256,
            "c0c5c0287879b4139306d59ef4951afc2d81d409ba34f24bdc7233e3c0612e27"
        )
        XCTAssertEqual(Product22ClientFactory.Contract.operationIDs.count, 26)
        XCTAssertEqual(Product22ClientFactory.Contract.productVersion, "2.2.0")
    }

    // MARK: 3 — all eight success sections

    func testEightSuccessSectionsDecodeAndKeepServerOrder() async throws {
        let sections = [
            Product22Fixture.playCompassOKSection(),
            #"{"key":"gameDNA","status":"ok","reasonCode":null,"data":{"signalCount":12,"confidence":"HIGH","generatedAt":"2026-07-30T09:00:00.000Z","topGenres":[{"genre":"RPG","weight":3,"share":0.5}],"sessionLengthLabel":"LONG","socialLabel":"SINGLEPLAYER","toneLabel":"COMFORT","missingSignals":["mood"],"reasonCodes":["ok"]}}"#,
            #"{"key":"gameBriefing","status":"ok","reasonCode":null,"data":{"items":[{"catalogGameId":"\#(Product22Fixture.gameA)","title":"G","updatedAt":"2026-07-30T09:00:00.000Z","noteworthyReleases":[{"countryCode":"KR","platform":"iOS","serviceStatus":"SUNSET_ANNOUNCED","shutdownDate":"2026-12-01","provenance":"OFFICIAL_SOURCE"}]}],"emptyReason":null,"generatedAt":"2026-07-30T09:00:00.000Z"}}"#,
            #"{"key":"backlogRescue","status":"ok","reasonCode":null,"data":{"items":[{"catalogGameId":"\#(Product22Fixture.gameB)","title":"B","addedAt":"2026-07-30T09:00:00.000Z","reasonCode":"backlog_never_logged","ownershipProvenance":"PROVIDER_VERIFIED"}],"emptyReason":null}}"#,
            #"{"key":"spoilerFreeStartGuide","status":"ok","reasonCode":null,"data":{"items":[{"catalogGameId":"\#(Product22Fixture.gameA)","title":"S","libraryStatus":"BACKLOG","genres":["RPG"],"platforms":["PC"],"estimatedFirstSessionMinutes":40,"soloFriendly":true,"partyFriendly":false,"spoilerFree":true}],"emptyReason":null}}"#,
            #"{"key":"editorialCuration","status":"ok","reasonCode":null,"data":{"articles":[{"slug":"a","status":"PUBLISHED","locale":"ko","headline":"H","excerpt":"E","publishedAt":"2026-07-28T02:00:00.000Z","correctedAt":null,"heroImage":null,"heroImageWithheldReason":null,"relatedGames":[],"sourceCount":2}],"emptyReason":null}}"#,
            #"{"key":"monthlyReplay","status":"ok","reasonCode":null,"data":{"monthKey":"2026-07","timezone":"Asia/Seoul","isEmpty":false,"playedDayCount":5,"totalMinutes":300,"mostPlayedGame":null,"surpriseGame":null,"missingData":[]}}"#,
            #"{"key":"friendActivity","status":"ok","reasonCode":null,"data":{"items":[{"activityId":"cf607081-9203-44b5-9fe6-708192031425","actorUserId":"d0718192-0314-46c6-8007-819203142536","activityType":"REVIEW_CREATED","catalogGameId":null,"legacyIdentity":{"gameSource":"IGDB","externalGameId":"9","igdbGameId":"2680"},"createdAt":"2026-07-30T09:00:00.000Z"}],"emptyReason":null}}"#
        ].joined(separator: ",")

        let order = """
        "playCompass","gameDNA","gameBriefing","backlogRescue",
        "spoilerFreeStartGuide","editorialCuration","monthlyReplay","friendActivity"
        """
        Product22StubURLProtocol.stub(
            pathContains: "/api/v1/users/me/today",
            json: Product22Fixture.today(sections: sections, order: order)
        )

        let feed = TodayFeedMapper.map(
            try await service.fetchTodayFeed(locale: "ko", timezone: "Asia/Seoul", limit: 8)
        )

        XCTAssertEqual(feed.sections.count, 8)
        XCTAssertEqual(feed.okSectionCount, 8)
        XCTAssertFalse(feed.partialFailure)
        XCTAssertEqual(
            feed.sections.map(\.key),
            [.playCompass, .gameDNA, .gameBriefing, .backlogRescue,
             .spoilerFreeStartGuide, .editorialCuration, .monthlyReplay, .friendActivity]
        )
        XCTAssertTrue(feed.retryableKeys.isEmpty)
    }

    // MARK: 4 — disabled / unavailable carry null data

    func testDisabledAndUnavailableSectionsMapToDistinctStates() async throws {
        let sections = [
            Product22Fixture.degradedSection(key: "playCompass", status: "disabled", reason: "FEATURE_DISABLED"),
            Product22Fixture.degradedSection(key: "gameDNA", status: "unavailable", reason: "SECTION_TIMEOUT"),
            Product22Fixture.degradedSection(key: "gameBriefing", status: "unavailable", reason: "SECTION_FAILED"),
            Product22Fixture.degradedSection(key: "friendActivity", status: "unavailable", reason: "SECTION_FAILED")
        ].joined(separator: ",")

        Product22StubURLProtocol.stub(
            pathContains: "/api/v1/users/me/today",
            json: Product22Fixture.today(
                sections: sections,
                order: #""playCompass","gameDNA","gameBriefing","friendActivity""#,
                partialFailure: true
            )
        )

        let feed = TodayFeedMapper.map(
            try await service.fetchTodayFeed(locale: nil, timezone: "UTC", limit: 8)
        )

        XCTAssertEqual(feed.okSectionCount, 0)
        XCTAssertTrue(feed.partialFailure)

        // disabled is NOT retryable — offering a retry for a kill switch is a
        // button that cannot work.
        guard case .disabled(let reason) = feed.sections[0].state else {
            return XCTFail("playCompass should be disabled")
        }
        XCTAssertEqual(reason, "FEATURE_DISABLED")
        XCTAssertFalse(feed.retryableKeys.contains(.playCompass))

        // unavailable IS retryable, per section.
        XCTAssertEqual(feed.retryableKeys, [.gameDNA, .gameBriefing, .friendActivity])
    }

    // MARK: 7 — one failed section must not take the feed down

    func testOneFailedSectionLeavesEveryHealthySectionIntact() async throws {
        let sections = [
            Product22Fixture.playCompassOKSection(),
            Product22Fixture.degradedSection(key: "gameDNA", status: "unavailable", reason: "SECTION_TIMEOUT"),
            #"{"key":"monthlyReplay","status":"ok","reasonCode":null,"data":{"monthKey":"2026-07","timezone":"Asia/Seoul","isEmpty":true,"playedDayCount":0,"totalMinutes":0,"mostPlayedGame":null,"surpriseGame":null,"missingData":[]}}"#
        ].joined(separator: ",")

        Product22StubURLProtocol.stub(
            pathContains: "/api/v1/users/me/today",
            json: Product22Fixture.today(
                sections: sections,
                order: #""playCompass","gameDNA","monthlyReplay""#,
                partialFailure: true
            )
        )

        let feed = TodayFeedMapper.map(
            try await service.fetchTodayFeed(locale: "ko", timezone: "Asia/Seoul", limit: 8)
        )

        XCTAssertEqual(feed.sections.count, 3)
        XCTAssertEqual(feed.okSectionCount, 2, "a failed section must not disable its neighbours")
        XCTAssertEqual(feed.retryableKeys, [.gameDNA])
    }

    // MARK: 5 — ArticleSummary carries no body; the body is a separate fetch

    func testArticleCardCarriesNoBodyAndDetailIsFetchedSeparately() async throws {
        Product22StubURLProtocol.stub(
            pathContains: "/api/v1/users/me/today",
            json: Product22Fixture.today(
                sections: #"{"key":"editorialCuration","status":"ok","reasonCode":null,"data":{"articles":[{"slug":"corrected-piece","status":"CORRECTED","locale":"ko","headline":"H","excerpt":"E","publishedAt":"2026-07-20T05:30:00.000Z","correctedAt":"2026-07-26T09:15:00.000Z","heroImage":{"url":"https://cdn.example/a.jpg","rightsStatus":"CLEARED","attribution":null},"heroImageWithheldReason":null,"relatedGames":[{"catalogGameId":"\#(Product22Fixture.gameA)","relation":"SUBJECT"}],"sourceCount":2}],"emptyReason":null}}"#,
                order: #""editorialCuration""#
            )
        )
        Product22StubURLProtocol.stub(
            pathContains: "/api/v1/articles/corrected-piece",
            json: Product22TestFactory.envelope("""
            {"article":{"slug":"corrected-piece","status":"CORRECTED","locale":"ko",
              "headline":"H","excerpt":"E","bodyFormat":"commonmark-no-html",
              "bodyMarkdown":"# Body","publishedAt":"2026-07-20T05:30:00.000Z",
              "correctedAt":"2026-07-26T09:15:00.000Z",
              "revision":{"revisionNumber":3,"status":"CORRECTED",
                          "changeNote":"수치 오류를 정정했습니다","createdAt":"2026-07-26T09:15:00.000Z"},
              "heroImage":null,"heroImageWithheldReason":null,
              "sources":[{"sourceType":"OFFICIAL_SITE","publisherKey":"pub","headline":"S",
                          "excerpt":null,"sourceUrl":"https://example.com/s",
                          "publishedAt":null,"fetchedAt":"2026-07-20T00:00:00.000Z",
                          "contentHash":"\(String(repeating: "a", count: 64))",
                          "provenance":"OFFICIAL_SOURCE"}],
              "relatedGames":[]}}
            """)
        )

        let feed = TodayFeedMapper.map(
            try await service.fetchTodayFeed(locale: "ko", timezone: "Asia/Seoul", limit: 8)
        )
        guard case .content(.editorialCuration(let cards, _)) = feed.sections[0].state,
              let card = cards.first else {
            return XCTFail("expected an editorial curation card")
        }

        // Only the Today request has happened so far — the card is a card.
        XCTAssertEqual(Product22StubURLProtocol.recordedRequests.count, 1)
        XCTAssertEqual(card.slug, "corrected-piece")
        XCTAssertTrue(card.isCorrected)
        XCTAssertEqual(card.sourceCount, 2)
        XCTAssertEqual(card.relatedGames.first?.catalogGameID.wireValue, Product22Fixture.gameA)

        // 18 — a corrected article must expose its correction time and note.
        let article = try ArticleMapper.article(from: try await service.fetchArticle(slug: card.slug))
        XCTAssertEqual(Product22StubURLProtocol.recordedRequests.count, 2)
        XCTAssertTrue(article.isCorrected)
        XCTAssertNotNil(article.correctedAt)
        XCTAssertEqual(article.revision.changeNote, "수치 오류를 정정했습니다")
        XCTAssertEqual(article.revision.number, 3)

        // 20 — only https sources may be opened.
        XCTAssertTrue(try XCTUnwrap(article.sources.first).isOpenable)
    }

    func testNonHTTPSArticleSourceIsNeverOpenable() throws {
        let source = ArticleSource(
            kind: .officialSite,
            publisherKey: "pub",
            headline: "H",
            excerpt: nil,
            url: URL(string: "http://insecure.example/x")!,
            publishedAt: nil,
            fetchedAt: Date(),
            provenance: .officialSource
        )
        XCTAssertFalse(source.isOpenable, "a plaintext source link must never be opened")
    }

    // MARK: 10 — Authorization header behaviour

    func testAuthenticatedReadSendsBearerTokenOnTheGeneratedRequest() async throws {
        Product22StubURLProtocol.stub(
            pathContains: "/api/v1/product-config",
            json: Product22Fixture.productConfig()
        )
        _ = try await service.fetchProductConfig()

        let recorded = try XCTUnwrap(Product22StubURLProtocol.recordedRequests.first)
        XCTAssertEqual(recorded.authorizationHeader, "Bearer token-a")
        XCTAssertTrue(recorded.url.path.hasSuffix("/api/v1/product-config"))
    }

    func testGuestStartedMutationNeverAcquiresATokenThatAppearedLater() async throws {
        let signedOut = SessionCredentialAuthority()
        let guestService = Product22TestFactory.makeService(authority: signedOut)

        // The gesture happens while signed out.
        let authorization = Product22MutationAuthorizer.captureExpectation(authority: signedOut)
        XCTAssertEqual(authorization, .guestOnly)

        // An account signs in *after* the gesture.
        signedOut.adoptAuthenticatedSession(accountID: "late", accessToken: "late-token")

        Product22StubURLProtocol.stub(pathContains: "/follow", json: Product22TestFactory.envelope("{}"))

        do {
            try await guestService.followCatalogGame(
                id: CatalogGameID(uuidString: Product22Fixture.gameA)!,
                regionalReleaseID: nil,
                authorization: authorization
            )
            XCTFail("a guest-started mutation must not be transmitted")
        } catch let error as Product22Error {
            XCTAssertEqual(error, .unauthorized)
        }

        XCTAssertTrue(
            Product22StubURLProtocol.recordedRequests.isEmpty,
            "the request must fail before transmission, not after"
        )
    }

    func testAccountBoundMutationFailsWhenTheAccountChangedAfterTheGesture() async throws {
        let expectation = Product22MutationAuthorizer.captureExpectation(authority: authority)
        guard case .accountBound = expectation else {
            return XCTFail("a signed-in gesture must bind its account")
        }

        // The user switches accounts between the gesture and transmission.
        authority.adoptAuthenticatedSession(accountID: "account-b", accessToken: "token-b")

        Product22StubURLProtocol.stub(pathContains: "/follow", json: Product22TestFactory.envelope("{}"))

        do {
            try await service.followCatalogGame(
                id: CatalogGameID(uuidString: Product22Fixture.gameA)!,
                regionalReleaseID: nil,
                authorization: expectation
            )
            XCTFail("a stale account expectation must not transmit")
        } catch let error as Product22Error {
            XCTAssertEqual(error, .accountChanged)
        }

        XCTAssertTrue(
            Product22StubURLProtocol.recordedRequests.isEmpty,
            "account B's token must never be attached to account A's gesture"
        )
    }

    func testAnonymousAuthorizationAttachesNoHeaderEvenWithALiveSession() async throws {
        Product22StubURLProtocol.stub(
            pathContains: "/api/v1/product-config",
            json: Product22Fixture.productConfig()
        )
        try await Product22AuthorizationContext.withAuthorization(.anonymous) {
            let client = Product22ClientFactory.makeClient(
                baseURL: Product22TestFactory.baseURL,
                middlewares: [Product22AuthorizationPolicy.makeMiddleware(authority: authority)],
                session: Product22StubURLProtocol.makeSession()
            )
            _ = try await client.getProductConfig(.init())
        }
        let recorded = try XCTUnwrap(Product22StubURLProtocol.recordedRequests.first)
        XCTAssertNil(
            recorded.authorizationHeader,
            "a public operation must not have a credential forced onto it"
        )
    }

    // MARK: 15/16 — Play Compass guarantees

    func testPlayCompassNeverShowsMoreThanThreeOwnedRecommendations() async throws {
        let recommendations = (1...3)
            .map { Product22Fixture.recommendation(rank: $0, gameID: Product22Fixture.gameA) }
            .joined(separator: ",")
        Product22StubURLProtocol.stub(
            pathContains: "/api/v1/users/me/play-compass",
            json: Product22TestFactory.envelope("""
            {"recommendations":[\(recommendations)],"confidence":"HIGH",
             "generatedAt":"2026-07-30T09:00:00.000Z",
             "dataFreshness":{"candidatePoolSize":40,"freshestLibraryUpdateAt":null,
                              "playlogSampleSize":10,"stale":false},
             "emptyReason":null,"ownedOnly":true,
             "requestHash":"\(String(repeating: "b", count: 64))"}
            """)
        )

        let result = PlayCompassMapper.result(
            from: try await service.recommendPlayCompass(
                PlayCompassMapper.request(from: PlayCompassQuery(availableMinutes: 60)),
                authorization: .currentSession
            )
        )

        XCTAssertLessThanOrEqual(result.recommendations.count, 3)
        XCTAssertTrue(result.ownedOnly, "the owned-only guarantee must reach the UI")
        for recommendation in result.recommendations {
            XCTAssertTrue(
                [.playing, .backlog].contains(recommendation.ownership.libraryStatus),
                "a recommendation must come from an owned library entry"
            )
            XCTAssertFalse(
                recommendation.ownership.installStateIsKnown,
                "install state is not tracked and must never be claimed"
            )
        }
    }

    func testLowConfidenceEmptyResultIsANormalStateNotAnError() async throws {
        Product22StubURLProtocol.stub(
            pathContains: "/api/v1/users/me/play-compass",
            json: Product22TestFactory.envelope("""
            {"recommendations":[],"confidence":"LOW",
             "generatedAt":"2026-07-30T09:00:00.000Z",
             "dataFreshness":{"candidatePoolSize":0,"freshestLibraryUpdateAt":null,
                              "playlogSampleSize":0,"stale":true},
             "emptyReason":"no_owned_playing_or_backlog_games","ownedOnly":true,
             "requestHash":"\(String(repeating: "c", count: 64))"}
            """)
        )

        let result = PlayCompassMapper.result(
            from: try await service.recommendPlayCompass(
                PlayCompassMapper.request(from: PlayCompassQuery(availableMinutes: 30)),
                authorization: .currentSession
            )
        )

        XCTAssertTrue(result.recommendations.isEmpty)
        XCTAssertEqual(result.confidence, .low)
        XCTAssertEqual(result.emptyReason, .noOwnedPlayingOrBacklogGames)
        XCTAssertTrue(result.freshness.isStale)
    }

    func testPlayCompassFeedbackCarriesTheSameRequestHashAsTheRound() async throws {
        let hash = String(repeating: "d", count: 64)
        Product22StubURLProtocol.stub(
            pathContains: "/play-compass/events",
            json: Product22TestFactory.envelope("{}"),
            statusCode: 201
        )

        try await service.recordPlayCompassEvent(
            PlayCompassMapper.eventRequest(from: PlayCompassFeedback(
                catalogGameID: CatalogGameID(uuidString: Product22Fixture.gameA)!,
                action: .playConfirmed,
                reasonCodes: [.fitsAvailableTime],
                requestHash: hash,
                occurredAt: Date(timeIntervalSince1970: 1_785_402_000)
            )),
            authorization: .currentSession
        )

        let recorded = try XCTUnwrap(Product22StubURLProtocol.recordedRequests.first)
        let body = try XCTUnwrap(recorded.bodyJSON())
        XCTAssertEqual(body["requestHash"] as? String, hash)
        XCTAssertEqual(body["action"] as? String, "PLAY_CONFIRMED")
        XCTAssertEqual(body["catalogGameId"] as? String, Product22Fixture.gameA)
    }

    // MARK: 17 — Monthly Replay empty month and missing data

    func testEmptyMonthlyReplayIsAnEmptyStateAndGapsAreNeverHidden() async throws {
        Product22StubURLProtocol.stub(
            pathContains: "/replays/monthly",
            json: Product22TestFactory.envelope("""
            {"monthKey":"2026-02","timezone":"Asia/Seoul",
             "window":{"startUtc":"2026-01-31T15:00:00.000Z",
                       "endUtc":"2026-02-28T15:00:00.000Z","localDayCount":28},
             "generatedAt":"2026-07-30T09:00:00.000Z",
             "isEmpty":true,"emptyReason":"no_sessions_recorded",
             "playedDates":[],"totals":{},"startedGames":[],"completedGames":[],
             "droppedGames":[],"mostPlayedGame":null,"surpriseGame":null,
             "genreDistribution":{},"moodDistribution":{},"provenance":{},
             "missingData":[{"code":"duration_missing","affectedSessionCount":2,
                             "effect":"총 시간에서 제외"}]}
            """)
        )

        let replay = PlayIntelligenceMapper.monthlyReplay(
            from: try await service.fetchMonthlyReplay(month: "2026-02", timezone: "Asia/Seoul")
        )

        XCTAssertTrue(replay.isEmpty)
        XCTAssertEqual(replay.emptyReason, "no_sessions_recorded")
        // The server's month key, zone and window are rendered as given; the
        // client does not recompute a boundary, DST or otherwise.
        XCTAssertEqual(replay.monthKey, "2026-02")
        XCTAssertEqual(replay.timezone, "Asia/Seoul")
        XCTAssertEqual(replay.window.localDayCount, 28)
        // A gap is surfaced, never swallowed.
        XCTAssertTrue(replay.hasGaps)
        XCTAssertEqual(replay.missingData.first?.affectedSessionCount, 2)
    }

    // MARK: Feature kill switch propagation

    func testFeatureDisabledResponseBecomesADomainFeatureUnavailableError() async throws {
        Product22StubURLProtocol.stub(
            pathContains: "/api/v1/users/me/today",
            json: Product22TestFactory.errorEnvelope(code: "FEATURE_DISABLED"),
            statusCode: 503
        )
        do {
            _ = try await service.fetchTodayFeed(locale: nil, timezone: "UTC", limit: 8)
            XCTFail("expected a feature-unavailable error")
        } catch let error as Product22Error {
            XCTAssertEqual(error, .featureUnavailable(.disabled))
        }
    }

    func testFeatureStateUnavailableIsDistinguishedFromAPlainDisable() async throws {
        Product22StubURLProtocol.stub(
            pathContains: "/api/v1/users/me/game-dna",
            json: Product22TestFactory.errorEnvelope(code: "FEATURE_STATE_UNAVAILABLE"),
            statusCode: 503
        )
        do {
            _ = try await service.fetchGameDNA()
            XCTFail("expected a feature-unavailable error")
        } catch let error as Product22Error {
            XCTAssertEqual(error, .featureUnavailable(.stateUnavailable))
        }
    }

    func testUnauthorizedIsSurfacedForTheSessionLayerRatherThanRetried() async throws {
        Product22StubURLProtocol.stub(
            pathContains: "/api/v1/users/me/today",
            json: Product22TestFactory.errorEnvelope(code: "UNAUTHORIZED"),
            statusCode: 401
        )
        do {
            _ = try await service.fetchTodayFeed(locale: nil, timezone: "UTC", limit: 8)
            XCTFail("expected unauthorized")
        } catch let error as Product22Error {
            XCTAssertEqual(error, .unauthorized)
        }
        XCTAssertEqual(
            Product22StubURLProtocol.recordedRequests.count, 1,
            "a 401 must not be retried by this layer"
        )
    }
}
