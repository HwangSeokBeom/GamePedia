import XCTest
@testable import GamePedia

// H-IOS-2 — atomic widget generation ownership.
//
// A producer captures its expected widget-generation token while it still
// owns the authenticated session and passes that exact token into the save.
// The store compares the token against the stored generation, stamps the
// payload with the SAME token, and persists — all inside one lock. A stale
// producer that captured generation GA and lost the CPU to an account
// transition can never have its payload stamped with the new session's GB;
// its save is rejected, and the caller must treat that rejection as a
// refusal, never as success.
final class SocialWidgetGenerationOwnershipTests: XCTestCase {

    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var store: SocialWidgetSnapshotStore!

    private let friendActivityKey = "gamepedia.social.widget.friend_activity"
    private let recommendedGameKey = "gamepedia.social.widget.recommended_game"
    private let sessionGenerationKey = "gamepedia.social.widget.session_generation"

    override func setUp() {
        super.setUp()
        suiteName = "social-widget-generation-tests-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        store = SocialWidgetSnapshotStore(userDefaults: userDefaults)
    }

    override func tearDown() {
        if let suiteName {
            userDefaults?.removePersistentDomain(forName: suiteName)
        }
        super.tearDown()
    }

    private func makeSummary(id: String = "item-1", title: String = "Friend") -> FriendActivitySummaryWidgetData {
        FriendActivitySummaryWidgetData(
            generatedAt: Date(timeIntervalSince1970: 9_000),
            title: title,
            summary: "played something",
            items: [
                FriendActivitySummaryWidgetData.Item(
                    id: id,
                    title: title,
                    subtitle: "played something",
                    actorAvatarURL: nil,
                    gameCoverURL: nil,
                    timestampText: "now"
                )
            ]
        )
    }

    /// The persisted wrapper's stamp, decoded straight from the raw blob.
    private struct StampProbe: Decodable {
        let sessionGeneration: String
    }

    private func persistedStamp(forKey key: String) -> String? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StampProbe.self, from: data).sessionGeneration
    }

    // MARK: 1–8. The core stale-producer race, end to end

    func test_staleProducerCapturedTokenIsRejectedAtomicallyAndNeverStampedWithNewGeneration() throws {
        // 1. Account A's producer captures generation GA while it still
        //    owns the session.
        let generationA = try XCTUnwrap(store.captureGenerationToken())

        // 2–3. A passes its session validation and is suspended immediately
        //    before the atomic store operation (modeled by running the
        //    transition between capture and save — the exact interleaving).
        // 4. Account B's transition rotates the current generation to GB.
        store.handleSessionTransition()
        let generationB = try XCTUnwrap(store.captureGenerationToken())
        XCTAssertNotEqual(generationA, generationB)

        // 5–6. A resumes with expected generation GA: the store rejects it.
        let result = store.saveFriendActivitySummary(
            makeSummary(title: "friend-of-a"),
            expectedGeneration: generationA
        )
        XCTAssertEqual(result, .rejectedStaleGeneration)

        // 7. No A payload exists stamped with GB — nothing was written.
        XCTAssertNil(userDefaults.data(forKey: friendActivityKey))
        XCTAssertNil(store.loadFriendActivitySummary())

        // 8. A valid B payload with GB succeeds and is stamped with GB.
        let saved = store.saveFriendActivitySummary(
            makeSummary(title: "friend-of-b"),
            expectedGeneration: generationB
        )
        XCTAssertEqual(saved, .saved)
        XCTAssertEqual(persistedStamp(forKey: friendActivityKey), generationB)
        XCTAssertEqual(store.loadFriendActivitySummary()?.items.first?.title, "friend-of-b")
    }

    // MARK: 9. Repeated stale saves stay rejected

    func test_repeatedStaleSavesRemainRejectedAndNeverDisturbTheValidPayload() throws {
        let generationA = try XCTUnwrap(store.captureGenerationToken())
        store.handleSessionTransition()
        let generationB = try XCTUnwrap(store.captureGenerationToken())
        XCTAssertEqual(
            store.saveFriendActivitySummary(makeSummary(title: "friend-of-b"), expectedGeneration: generationB),
            .saved
        )

        for attempt in 0..<10 {
            let result = store.saveFriendActivitySummary(
                makeSummary(title: "friend-of-a"),
                expectedGeneration: generationA
            )
            XCTAssertEqual(result, .rejectedStaleGeneration, "attempt \(attempt)")
            XCTAssertEqual(persistedStamp(forKey: friendActivityKey), generationB, "attempt \(attempt)")
            XCTAssertEqual(
                store.loadFriendActivitySummary()?.items.first?.title,
                "friend-of-b",
                "attempt \(attempt): the valid payload must survive every stale attempt"
            )
        }
    }

    // MARK: 10 + 11. Logout and account deletion invalidate captured tokens

    private func makeRuntime(center: NotificationCenter = NotificationCenter()) -> LiveServiceRuntime {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-generation-runtime-\(UUID().uuidString)", isDirectory: true)
        return LiveServiceRuntime(
            featureFlags: AppConfig.featureFlags,
            notificationCenter: center,
            breadcrumbs: OperationBreadcrumbRecorder(),
            readStateStore: ActivityReadStateStore(directoryURL: directory),
            snapshotStore: FileActivityCenterSnapshotStore(directoryURL: directory),
            socialWidgetStore: store
        )
    }

    func test_logoutInvalidatesAPreviouslyCapturedToken() throws {
        let runtime = makeRuntime()
        runtime.handleSessionChange(isAuthenticated: true, userID: "acct-a")
        let captured = try XCTUnwrap(store.captureGenerationToken())

        runtime.handleSessionChange(isAuthenticated: false, userID: nil)

        XCTAssertEqual(
            store.saveFriendActivitySummary(makeSummary(), expectedGeneration: captured),
            .rejectedStaleGeneration
        )
        XCTAssertNil(userDefaults.data(forKey: friendActivityKey))
    }

    func test_accountDeletionInvalidatesAPreviouslyCapturedToken() throws {
        let runtime = makeRuntime()
        runtime.handleSessionChange(isAuthenticated: true, userID: "acct-a")
        let captured = try XCTUnwrap(store.captureGenerationToken())

        runtime.handleAccountDeletionMarker(userID: "acct-a")

        XCTAssertEqual(
            store.saveFriendActivitySummary(makeSummary(), expectedGeneration: captured),
            .rejectedStaleGeneration
        )
        XCTAssertNil(userDefaults.data(forKey: friendActivityKey))
    }

    // MARK: 12. Restart preserves the state needed to reject old blobs

    func test_appRestartPreservesGenerationStateAndRejectsOldBlobsAndTokens() throws {
        let generationA = try XCTUnwrap(store.captureGenerationToken())
        XCTAssertEqual(
            store.saveFriendActivitySummary(makeSummary(title: "friend-of-a"), expectedGeneration: generationA),
            .saved
        )
        let oldBlob = try XCTUnwrap(userDefaults.data(forKey: friendActivityKey))
        store.handleSessionTransition()

        // "Restart": a fresh store instance over the same persisted defaults.
        let restarted = SocialWidgetSnapshotStore(userDefaults: userDefaults)

        // A straggler old-generation blob landing after restart is rejected
        // and deleted by the reader.
        userDefaults.set(oldBlob, forKey: friendActivityKey)
        XCTAssertNil(restarted.loadFriendActivitySummary())
        XCTAssertNil(userDefaults.data(forKey: friendActivityKey))

        // The pre-restart captured token stays invalid across the restart.
        XCTAssertEqual(
            restarted.saveFriendActivitySummary(makeSummary(), expectedGeneration: generationA),
            .rejectedStaleGeneration
        )
    }

    // MARK: 13 + 14. Legacy, malformed, and missing generations

    func test_legacyUnstampedPayloadRemainsRejectedAndDeleted() throws {
        let legacy = try JSONEncoder().encode(makeSummary())
        userDefaults.set(legacy, forKey: friendActivityKey)

        XCTAssertNil(store.loadFriendActivitySummary())
        XCTAssertNil(userDefaults.data(forKey: friendActivityKey))
    }

    func test_malformedBlobAndMissingOrEmptyGenerationAreRejected() {
        // Reader side: undecodable garbage never surfaces and is deleted.
        userDefaults.set(Data("not-json".utf8), forKey: friendActivityKey)
        XCTAssertNil(store.loadFriendActivitySummary())
        XCTAssertNil(userDefaults.data(forKey: friendActivityKey))

        // Writer side: a producer with no captured token (or an empty one)
        // has no proof of session ownership — refused, nothing written.
        XCTAssertEqual(
            store.saveFriendActivitySummary(makeSummary(), expectedGeneration: nil),
            .rejectedStaleGeneration
        )
        XCTAssertEqual(
            store.saveFriendActivitySummary(makeSummary(), expectedGeneration: ""),
            .rejectedStaleGeneration
        )
        XCTAssertNil(userDefaults.data(forKey: friendActivityKey))
    }

    // MARK: 15. Concurrent valid saves for the same generation

    func test_concurrentValidSavesForTheSameGenerationAreDeterministic() throws {
        let generation = try XCTUnwrap(store.captureGenerationToken())
        let resultsLock = NSLock()
        var results: [SocialWidgetSaveResult] = []
        let localStore = store!

        DispatchQueue.concurrentPerform(iterations: 8) { index in
            let result = localStore.saveFriendActivitySummary(
                self.makeSummary(id: "item-\(index)", title: "writer-\(index)"),
                expectedGeneration: generation
            )
            resultsLock.lock()
            results.append(result)
            resultsLock.unlock()
        }

        XCTAssertEqual(results.count, 8)
        XCTAssertTrue(results.allSatisfy { $0 == .saved }, "every same-generation save must succeed")
        // The surviving payload is exactly one whole writer's payload,
        // stamped with the shared generation — never an interleaved blend.
        XCTAssertEqual(persistedStamp(forKey: friendActivityKey), generation)
        let survivor = try XCTUnwrap(store.loadFriendActivitySummary())
        let writerIndex = try XCTUnwrap(survivor.items.first?.id.split(separator: "-").last.flatMap { Int($0) })
        XCTAssertEqual(survivor.items.first?.title, "writer-\(writerIndex)")
    }

    // MARK: 16. Storage failure is distinct from stale rejection

    func test_storageWriteFailureIsReportedDistinctlyFromStaleRejection() throws {
        let failingStore = SocialWidgetSnapshotStore(
            userDefaults: userDefaults,
            persistData: { _, _, _ in false }
        )
        let generation = try XCTUnwrap(failingStore.captureGenerationToken())

        XCTAssertEqual(
            failingStore.saveFriendActivitySummary(makeSummary(), expectedGeneration: generation),
            .storageFailure,
            "a failed write with a VALID generation must not masquerade as a stale rejection"
        )
        XCTAssertNil(userDefaults.data(forKey: friendActivityKey))

        // A store without any backing defaults is also a storage failure.
        let storelessStore = SocialWidgetSnapshotStore(userDefaults: nil)
        XCTAssertEqual(
            storelessStore.saveFriendActivitySummary(makeSummary(), expectedGeneration: "any"),
            .storageFailure
        )
    }

    // MARK: 17. No raw account identifier in keys or encoded payloads

    func test_noRawAccountIdentifierInKeysOrEncodedPayload() throws {
        let accountID = "acct-raw-identifier-1234"
        let runtime = makeRuntime()
        runtime.handleSessionChange(isAuthenticated: true, userID: accountID)
        let generation = try XCTUnwrap(store.captureGenerationToken())
        XCTAssertEqual(
            store.saveFriendActivitySummary(makeSummary(), expectedGeneration: generation),
            .saved
        )

        for key in [friendActivityKey, recommendedGameKey, sessionGenerationKey] {
            XCTAssertFalse(key.contains(accountID))
        }
        let blob = try XCTUnwrap(userDefaults.data(forKey: friendActivityKey))
        let text = String(decoding: blob, as: UTF8.self).lowercased()
        XCTAssertFalse(text.contains(accountID.lowercased()))
        for forbidden in ["acct-raw", "bearer", "authorization", "refreshtoken", "accesstoken", "@"] {
            XCTAssertFalse(text.contains(forbidden), "persisted widget payload must not contain: \(forbidden)")
        }
        XCTAssertNotNil(UUID(uuidString: generation), "the generation must be a random, non-identifying token")
        XCTAssertFalse(generation.contains(accountID))
    }

    // MARK: 18. Reader rejects a foreign embedded generation

    func test_widgetReaderRejectsPayloadWhoseEmbeddedGenerationDiffersFromCurrent() throws {
        _ = try XCTUnwrap(store.captureGenerationToken())
        // Hand-craft a wrapper stamped with a generation that was never the
        // stored one (e.g. produced by a compromised or ancient writer).
        let payloadJSON = try JSONEncoder().encode(makeSummary(title: "foreign"))
        var wrapped = Data("{\"sessionGeneration\":\"foreign-generation\",\"payload\":".utf8)
        wrapped.append(payloadJSON)
        wrapped.append(Data("}".utf8))
        userDefaults.set(wrapped, forKey: friendActivityKey)

        XCTAssertNil(store.loadFriendActivitySummary(), "a foreign-generation payload must never surface")
        XCTAssertNil(userDefaults.data(forKey: friendActivityKey), "the rejected payload must be deleted")
    }

    // MARK: 19. Fifty deterministic transition repetitions

    func test_fiftyRepeatedTransitionsAlwaysRejectStaleTokensAndAcceptFreshOnes() throws {
        for iteration in 0..<50 {
            let stale = try XCTUnwrap(store.captureGenerationToken())
            store.handleSessionTransition()

            XCTAssertEqual(
                store.saveFriendActivitySummary(
                    makeSummary(title: "stale-\(iteration)"),
                    expectedGeneration: stale
                ),
                .rejectedStaleGeneration,
                "iteration \(iteration)"
            )
            XCTAssertNil(userDefaults.data(forKey: friendActivityKey), "iteration \(iteration)")

            let fresh = try XCTUnwrap(store.captureGenerationToken())
            XCTAssertEqual(
                store.saveFriendActivitySummary(
                    makeSummary(title: "fresh-\(iteration)"),
                    expectedGeneration: fresh
                ),
                .saved,
                "iteration \(iteration)"
            )
            XCTAssertEqual(persistedStamp(forKey: friendActivityKey), fresh, "iteration \(iteration)")
            XCTAssertEqual(
                store.loadFriendActivitySummary()?.items.first?.title,
                "fresh-\(iteration)",
                "iteration \(iteration)"
            )
        }
    }
}
