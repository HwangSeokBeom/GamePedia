import Foundation
import GamePediaProduct22API
import XCTest
@testable import GamePedia

// MARK: - Product22PolicyTests
//
// Required areas 6, 8, 9, 11, 12, 24: the rules the app enforces on top of the
// contract — fail-closed configuration, account-isolated caching, stale
// response suppression, privacy of user content, identifier separation, and
// the analytics allowlist.

final class Product22PolicyTests: XCTestCase {

    private var service: Product22MockService!

    override func setUp() {
        super.setUp()
        service = Product22MockService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: 6 — ProductConfig fails closed

    func testUnknownConfigurationOffersNothingNew() async {
        // Never heard from the server: every new feature is off.
        let store = ProductConfigStore(service: service)
        let config = await store.current
        XCTAssertTrue(config.isDegraded)
        for feature in Product22Feature.allCases {
            XCTAssertFalse(
                config.isEnabled(feature),
                "\(feature) must be off before the server has said otherwise"
            )
        }
    }

    func testDegradedFlagStateDisablesEveryFeatureEvenWhenTheFlagsSayOn() async throws {
        // The server reports every switch on, but says it could not read the
        // table. The flags must not be believed.
        service.productConfigResult = .success(
            try Product22Decode.envelopeData(
                Components.Schemas.ProductConfig.self,
                from: Product22Fixture.productConfig(
                    degraded: true, source: "database_unavailable", allFeaturesOn: true
                )
            )
        )
        let store = ProductConfigStore(service: service)
        let config = await store.refresh()

        XCTAssertTrue(config.isDegraded)
        for feature in Product22Feature.allCases {
            XCTAssertFalse(config.isEnabled(feature), "\(feature) must be off while degraded")
        }
    }

    func testHealthyConfigurationEnablesExactlyWhatTheServerSaid() async throws {
        service.productConfigResult = .success(
            try Product22Decode.envelopeData(
                Components.Schemas.ProductConfig.self,
                from: Product22Fixture.productConfig(allFeaturesOn: true)
            )
        )
        let store = ProductConfigStore(service: service)
        let config = await store.refresh()

        XCTAssertFalse(config.isDegraded)
        for feature in Product22Feature.allCases {
            XCTAssertTrue(config.isEnabled(feature))
        }
    }

    func testAFailedRefreshDoesNotEraseAConfigThatIsStillFresh() async throws {
        service.productConfigResult = .success(
            try Product22Decode.envelopeData(
                Components.Schemas.ProductConfig.self,
                from: Product22Fixture.productConfig(allFeaturesOn: true)
            )
        )
        var clock = Date(timeIntervalSince1970: 1_785_402_000)
        let store = ProductConfigStore(service: service, now: { clock })
        _ = await store.refresh()

        // The network goes away. A flaky connection is not a kill switch.
        service.productConfigResult = .failure(Product22Error.transport(message: "offline"))
        clock = clock.addingTimeInterval(60)
        let config = await store.refresh()

        XCTAssertFalse(config.isDegraded, "a failed refresh must not look like a kill switch")
        XCTAssertTrue(config.isEnabled(.todayFeed))

        // Past the TTL with still no answer, it falls back to closed.
        clock = clock.addingTimeInterval(ProductConfigStore.cacheTTL + 1)
        let expired = await store.current
        XCTAssertTrue(expired.isDegraded)
        XCTAssertFalse(expired.isEnabled(.todayFeed))
    }

    func testFeatureStateUnavailableClosesTheAppDownImmediately() async throws {
        service.productConfigResult = .success(
            try Product22Decode.envelopeData(
                Components.Schemas.ProductConfig.self,
                from: Product22Fixture.productConfig(allFeaturesOn: true)
            )
        )
        let store = ProductConfigStore(service: service)
        _ = await store.refresh()
        let enabledBefore = await store.isEnabled(.playlog)
        XCTAssertTrue(enabledBefore)

        // A 503 from any call feeds back here. The app must not wait for the
        // refresh round trip before it stops offering the feature.
        service.productConfigResult = .failure(Product22Error.transport(message: "still down"))
        await store.handleFeatureUnavailable(.stateUnavailable)

        let enabledAfter = await store.isEnabled(.playlog)
        let configAfter = await store.current
        XCTAssertFalse(enabledAfter)
        XCTAssertTrue(configAfter.isDegraded)
    }

    // MARK: 8 — Today cache is isolated per account

    func testTodayCacheNeverServesAnotherAccountsFeed() async throws {
        service.todayResult = .success(try todayFeedDTO())
        let authority = Product22TestFactory.makeAuthority(accountID: "A", token: "ta")
        let repository = TodayFeedRepository(service: service, authority: authority)

        _ = try await repository.loadFeed(locale: "ko", timezone: "Asia/Seoul", forceRefresh: false)
        let cachedForA = await repository.cachedFeed()
        XCTAssertNotNil(cachedForA, "A's feed should be cached for A")

        // Switch to another account. A's feed must be unreachable — without
        // any explicit clear having run.
        authority.adoptAuthenticatedSession(accountID: "B", accessToken: "tb")
        let leaked = await repository.cachedFeed()
        XCTAssertNil(leaked, "account B must not see account A's cached Today feed")

        // And back to A: still A's own, never B's.
        authority.adoptAuthenticatedSession(accountID: "A", accessToken: "ta2")
        let cachedForAAgain = await repository.cachedFeed()
        XCTAssertNotNil(cachedForAAgain)
    }

    func testSignedOutCallerGetsNoCachedFeedAtAll() async throws {
        service.todayResult = .success(try todayFeedDTO())
        let authority = Product22TestFactory.makeAuthority(accountID: "A", token: "ta")
        let repository = TodayFeedRepository(service: service, authority: authority)
        _ = try await repository.loadFeed(locale: "ko", timezone: "Asia/Seoul", forceRefresh: false)

        authority.clearSession()

        let cachedWhileSignedOut = await repository.cachedFeed()
        XCTAssertNil(cachedWhileSignedOut)
        do {
            _ = try await repository.loadFeed(locale: "ko", timezone: "Asia/Seoul", forceRefresh: false)
            XCTFail("a signed-out load must not succeed")
        } catch let error as Product22Error {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    // MARK: 9 — responses that arrive too late are discarded

    func testResponseArrivingAfterAnAccountSwitchIsDiscarded() async throws {
        service.todayResult = .success(try todayFeedDTO())
        service.todayDelay = .milliseconds(150)

        let authority = Product22TestFactory.makeAuthority(accountID: "A", token: "ta")
        let repository = TodayFeedRepository(service: service, authority: authority)

        let load = Task { try await repository.loadFeed(locale: "ko", timezone: "Asia/Seoul", forceRefresh: true) }
        try await Task.sleep(for: .milliseconds(40))
        // The user switches accounts while A's request is still in flight.
        authority.adoptAuthenticatedSession(accountID: "B", accessToken: "tb")

        do {
            _ = try await load.value
            XCTFail("a response that outlived its account must not be delivered")
        } catch let error as Product22Error {
            XCTAssertEqual(error, .accountChanged)
        }

        // Nothing was written for either account.
        let cachedAccounts = await repository.cachedAccountIDs
        XCTAssertTrue(cachedAccounts.isEmpty)
        authority.adoptAuthenticatedSession(accountID: "A", accessToken: "ta")
        let cachedAfterSwitchBack = await repository.cachedFeed()
        XCTAssertNil(cachedAfterSwitchBack)
    }

    func testASlowEarlierLoadCannotOverwriteAFasterLaterOne() async throws {
        service.todayResult = .success(try todayFeedDTO(timezone: "Slow/Zone"))
        service.todayDelay = .milliseconds(200)

        let authority = Product22TestFactory.makeAuthority(accountID: "A", token: "ta")
        let repository = TodayFeedRepository(service: service, authority: authority)

        let slow = Task { try await repository.loadFeed(locale: "ko", timezone: "Slow/Zone", forceRefresh: true) }
        try await Task.sleep(for: .milliseconds(30))

        // A second, faster load answers first and is the one the user sees.
        service.todayDelay = .zero
        service.todayResult = .success(try todayFeedDTO(timezone: "Fast/Zone"))
        let fast = try await repository.loadFeed(locale: "ko", timezone: "Fast/Zone", forceRefresh: true)
        XCTAssertEqual(fast.timezone, "Fast/Zone")

        _ = try await slow.value   // lands afterwards

        let latestCache = await repository.cachedFeed()
        let cached = try XCTUnwrap(latestCache)
        XCTAssertEqual(
            cached.feed.timezone, "Fast/Zone",
            "the stale earlier response must not overwrite the newer one"
        )
    }

    // MARK: 11 — user content must not be able to reach a log

    func testQuickAddRawInputIsRedactedInEveryStringConversion() {
        let secret = "제가 어제 결제한 그 게임인데 제 이메일은 me@example.com 입니다"
        let input = QuickAddInput(kind: .text, rawInput: secret, locale: "ko", regionCode: "kr")

        for rendering in [
            input.description,
            input.debugDescription,
            String(describing: input),
            String(reflecting: input),
            "\(input)"
        ] {
            XCTAssertFalse(
                rendering.contains(secret),
                "raw Quick Add input must never appear in a string conversion"
            )
            XCTAssertFalse(rendering.contains("me@example.com"))
        }
        // The shape is still observable, which is all diagnostics need.
        XCTAssertTrue(input.description.contains("kind: TEXT"))
        XCTAssertTrue(input.description.contains("length: \(secret.count)"))
        XCTAssertEqual(input.regionCode, "KR", "region code is normalised for the contract")
    }

    func testAnalyticsPropertiesCannotHoldFreeText() {
        var properties = ProductEventProperties()
        // A Playlog note, an article body, a URL and a search query all fail
        // the code-shape test, so none of them can be attached.
        properties.set("note", code: "오늘 보스전이 진짜 힘들었다")
        properties.set("body", code: "# Heading\n\nsome prose")
        properties.set("url", code: "https://example.com/a?q=secret")
        properties.set("token", code: String(repeating: "x", count: 200))
        XCTAssertTrue(properties.isEmpty, "no free-text value may be stored")

        // Enumerated codes, counts and flags are what the bag is for.
        properties.set("outcome", code: "COMPLETED")
        properties.set("has_note", flag: true)
        properties.set("signal_count", count: 12)
        XCTAssertEqual(properties.storage.count, 3)
    }

    func testDecodingDiagnosticsNameTheFieldButNeverItsValue() {
        // A decoding failure can land on a field holding a note or an article
        // body, and the message reaches the logs.
        let secret = "매우 사적인 메모"
        let error = DecodingError.dataCorrupted(
            .init(codingPath: [Product22CodingKey("note")], debugDescription: secret)
        )
        let mapped = Product22ErrorMapper.map(error)
        guard case .decoding(let message) = mapped else {
            return XCTFail("expected a decoding error, got \(mapped)")
        }
        XCTAssertTrue(message.contains("note"), "the path is useful and safe")
        XCTAssertFalse(message.contains(secret), "the value must never be logged")
    }

    // MARK: 24 — Product Event allowlist

    func testDisallowedPropertiesAreStrippedBeforeAnythingIsSent() async throws {
        service.productConfigResult = .success(
            try Product22Decode.envelopeData(
                Components.Schemas.ProductConfig.self,
                from: Product22Fixture.productConfig(allFeaturesOn: true)
            )
        )
        let authority = Product22TestFactory.makeAuthority()
        let configStore = ProductConfigStore(service: service)
        _ = await configStore.refresh()

        let recorder = ProductEventRecorder(
            service: service, configStore: configStore, authority: authority
        )

        var properties = ProductEventProperties()
        properties.set("outcome", code: "COMPLETED")        // allowed
        properties.set("has_note", flag: true)              // allowed
        properties.set("mood", code: "FRUSTRATED")          // NOT allowed for this event
        properties.set("catalog_game_id", code: "abc-123")  // NOT in the allowlist
        let filtered = properties.filtered(for: .playSessionCreate)

        XCTAssertEqual(Set(filtered.storage.keys), ["outcome", "has_note"])
        XCTAssertNil(filtered.storage["mood"], "mood is private user content and never leaves the device")

        await recorder.record(.playSessionCreate, properties: properties)
        await recorder.flush()

        guard case .productEvents(let ids)? = service.calls.last else {
            return XCTFail("expected an event batch, got \(service.calls)")
        }
        XCTAssertEqual(ids.count, 1)
    }

    func testARetriedBatchKeepsTheSameEventIDsSoItCannotDoubleCount() async throws {
        service.productConfigResult = .success(
            try Product22Decode.envelopeData(
                Components.Schemas.ProductConfig.self,
                from: Product22Fixture.productConfig(allFeaturesOn: true)
            )
        )
        let authority = Product22TestFactory.makeAuthority()
        let configStore = ProductConfigStore(service: service)
        _ = await configStore.refresh()

        var clock = Date(timeIntervalSince1970: 1_785_402_000)
        let recorder = ProductEventRecorder(
            service: service, configStore: configStore, authority: authority, now: { clock }
        )

        service.productEventsResult = .failure(Product22Error.transport(message: "offline"))
        await recorder.record(.gameDNAView, properties: ProductEventProperties())
        let originalIDs = await recorder.pendingEventIDs
        await recorder.flush()
        let stillQueued = await recorder.pendingEventIDs
        XCTAssertEqual(stillQueued, originalIDs, "a failed batch stays queued")

        // Retry after the backoff window with the network restored.
        service.productEventsResult = .success(())
        clock = clock.addingTimeInterval(600)
        await recorder.flush()

        let batches = service.calls.compactMap { call -> [String]? in
            if case .productEvents(let ids) = call { return ids }
            return nil
        }
        XCTAssertEqual(batches.count, 2)
        XCTAssertEqual(batches[0], batches[1], "a retry must reuse the same eventIds")
        let drained = await recorder.pendingEventIDs
        XCTAssertTrue(drained.isEmpty)
    }

    func testEventsBelongingToAnotherAccountAreNeverSent() async throws {
        service.productConfigResult = .success(
            try Product22Decode.envelopeData(
                Components.Schemas.ProductConfig.self,
                from: Product22Fixture.productConfig(allFeaturesOn: true)
            )
        )
        let authority = Product22TestFactory.makeAuthority(accountID: "A", token: "ta")
        let configStore = ProductConfigStore(service: service)
        _ = await configStore.refresh()
        let recorder = ProductEventRecorder(
            service: service, configStore: configStore, authority: authority
        )

        await recorder.record(.gameDNAView, properties: ProductEventProperties())
        let queuedForA = await recorder.pendingCount
        XCTAssertEqual(queuedForA, 1)

        authority.adoptAuthenticatedSession(accountID: "B", accessToken: "tb")
        await recorder.flush()

        let remaining = await recorder.pendingCount
        XCTAssertEqual(remaining, 0, "A's events are dropped, not attributed to B")
        XCTAssertFalse(
            service.calls.contains { if case .productEvents = $0 { return true } else { return false } },
            "nothing may be sent for an account that did not generate it"
        )
    }

    func testAnalyticsFailureNeverPropagatesToTheCallingUserAction() async throws {
        service.productConfigResult = .success(
            try Product22Decode.envelopeData(
                Components.Schemas.ProductConfig.self,
                from: Product22Fixture.productConfig(allFeaturesOn: true)
            )
        )
        let configStore = ProductConfigStore(service: service)
        _ = await configStore.refresh()
        let recorder = ProductEventRecorder(
            service: service,
            configStore: configStore,
            authority: Product22TestFactory.makeAuthority()
        )
        service.productEventsResult = .failure(Product22Error.server(statusCode: 500, code: nil, message: nil))

        // Neither call is throwing — that is the guarantee.
        await recorder.record(.replayView, properties: ProductEventProperties())
        await recorder.flush()
    }

    // MARK: 12 — catalog UUIDs and legacy IGDB integers never mix

    func testCatalogIdentifiersOfferNoIntegerBridgeInEitherDirection() {
        let id = CatalogGameID(uuidString: Product22Fixture.gameA)
        XCTAssertNotNil(id)
        XCTAssertEqual(id?.wireValue, Product22Fixture.gameA)

        // A non-UUID never becomes a catalog id, so an IGDB integer written
        // into the wrong field fails loudly rather than addressing a wrong row.
        XCTAssertNil(CatalogGameID(uuidString: "2680"))
        XCTAssertNil(CatalogGameID(uuidString: ""))
        XCTAssertNil(CatalogGameID(uuidString: "not-a-uuid"))

        // Distinct id spaces are distinct types: a play session id and a
        // catalog id built from the same UUID are not interchangeable, and the
        // compiler enforces it.
        let uuid = UUID()
        XCTAssertEqual(CatalogGameID(uuid: uuid).wireValue, PlaySessionID(uuid: uuid).wireValue)
        XCTAssertNotEqual(CatalogGameID(uuid: uuid), CatalogGameID(uuid: UUID()))
    }

    func testTheOnlyLegacyBridgeIsTheOneTheServerSupplies() {
        // The server-supplied identity converts, in one named place.
        let linked = LegacyGameIdentity(source: .igdb, externalGameID: "9", igdbGameID: "2680")
        XCTAssertEqual(linked.legacyGameID, 2680)

        // Anything else yields nothing — the app treats the row as having no
        // legacy route rather than fabricating one.
        XCTAssertNil(LegacyGameIdentity(source: .steam, externalGameID: "367520", igdbGameID: nil).legacyGameID)
        XCTAssertNil(LegacyGameIdentity(source: nil, externalGameID: nil, igdbGameID: "abc").legacyGameID)
        XCTAssertNil(
            LegacyGameIdentity(
                source: .igdb, externalGameID: nil, igdbGameID: Product22Fixture.gameA
            ).legacyGameID,
            "a catalog UUID must never be converted into a legacy integer id"
        )
    }

    // MARK: Helpers

    private func todayFeedDTO(timezone: String = "Asia/Seoul") throws -> Components.Schemas.TodayFeed {
        try Product22Decode.envelopeData(
            Components.Schemas.TodayFeed.self,
            from: """
            {"success":true,"data":{
              "generatedAt":"2026-07-30T09:00:00.000Z",
              "timezone":"\(timezone)","locale":"ko",
              "sections":[\(Product22Fixture.playCompassOKSection())],
              "meta":{"sectionOrder":["playCompass"],"limit":8,
                      "nextCursor":null,"partialFailure":false}}}
            """
        )
    }
}

/// Minimal `CodingKey` for building a decoding error with a known path.
private struct Product22CodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ stringValue: String) { self.stringValue = stringValue }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
