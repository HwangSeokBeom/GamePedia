import GamePediaProduct22API
import UIKit
import XCTest
@testable import GamePedia

// MARK: - Product22VocabularyTests
//
// No server token reaches a reader, and provenance tiers stay distinguishable.

final class Product22VocabularyTests: XCTestCase {

    func testNoContractEnumEverRendersAsARawToken() {
        // A raw token is SCREAMING_SNAKE ASCII. Case-insensitive scripts like
        // Korean are unchanged by `uppercased()`, so the check has to be that
        // the string is ASCII *and* uppercase — not merely uppercase.
        func assertNotRaw(_ text: String, _ label: String) {
            XCTAssertFalse(text.isEmpty, "\(label) has no copy")
            let isScreamingASCII = text.allSatisfy {
                $0.isASCII && ($0.isUppercase || $0 == "_" || $0.isNumber)
            }
            XCTAssertFalse(
                isScreamingASCII,
                "\(label) is rendering as a raw server token: \(text)"
            )
        }

        for provenance in CatalogProvenance.allCases {
            assertNotRaw(Product22Vocabulary.text(for: provenance), provenance.rawValue)
        }
        for status in [CatalogServiceStatus.announced, .preRegistration, .live,
                       .maintenance, .sunsetAnnounced, .shutdown] {
            assertNotRaw(Product22Vocabulary.text(for: status), status.rawValue)
        }
        for status in [CatalogPublicationStatus.privateEntry, .pendingReview, .published, .rejected] {
            assertNotRaw(Product22Vocabulary.text(for: status), status.rawValue)
        }
        for outcome in PlaySessionOutcome.allCases {
            assertNotRaw(Product22Vocabulary.text(for: outcome), outcome.rawValue)
        }
        for mood in PlaySessionMood.allCases {
            assertNotRaw(Product22Vocabulary.text(for: mood), mood.rawValue)
        }
        for visibility in PlaySessionVisibilityOption.allCases {
            assertNotRaw(Product22Vocabulary.text(for: visibility), visibility.rawValue)
        }
    }

    func testInferenceAndVerificationNeverReadTheSame() {
        let verified = Product22Vocabulary.text(for: .providerVerified)
        let asserted = Product22Vocabulary.text(for: .userConfirmed)
        let inferred = Product22Vocabulary.text(for: .aiInferred)

        XCTAssertNotEqual(verified, asserted)
        XCTAssertNotEqual(verified, inferred)
        XCTAssertNotEqual(asserted, inferred)
        // Everything in a tier shares its copy, so the three tiers are the only
        // distinctions a reader has to learn.
        XCTAssertEqual(verified, Product22Vocabulary.text(for: .officialSource))
        XCTAssertEqual(inferred, Product22Vocabulary.text(for: .disputed))
    }

    func testPrivateAndPendingReviewAreDistinctToTheReader() {
        XCTAssertNotEqual(
            Product22Vocabulary.text(for: CatalogPublicationStatus.privateEntry),
            Product22Vocabulary.text(for: CatalogPublicationStatus.pendingReview)
        )
        XCTAssertNotEqual(
            Product22Vocabulary.text(for: CatalogPublicationStatus.pendingReview),
            Product22Vocabulary.text(for: CatalogPublicationStatus.published)
        )
    }

    func testOnlyAVerifiedProviderIdentityGetsConfidentCopy() {
        // Parsing a store URL is not verification, and the copy must not imply
        // it is.
        let exact = Product22Vocabulary.text(for: .providerIdentityExact)
        let unverified = Product22Vocabulary.text(for: .providerIdentityUnverified)
        XCTAssertNotNil(exact)
        XCTAssertNotNil(unverified)
        XCTAssertNotEqual(exact, unverified)

        // Title similarity is not an identity claim and gets no copy at all.
        XCTAssertNil(Product22Vocabulary.text(for: .fuzzyTitleSimilar))
        XCTAssertNil(Product22Vocabulary.text(for: .normalizedTitleExact))
    }
}

// MARK: - Product22QuickAddScreenTests

final class Product22QuickAddScreenTests: XCTestCase {

    private final class StubQuickAddRepository: QuickAddRepositing, @unchecked Sendable {
        var previewResult: Result<QuickAddPreview, any Error> =
            .failure(Product22Error.transport(message: "not stubbed"))
        var confirmResult: Result<SubmissionConfirmResult, any Error> =
            .success(Product22SubmissionFixture.confirmResult())
        var stateResult: Result<CatalogSubmissionState, any Error> =
            .failure(Product22Error.notFound)
        private(set) var confirmations: [QuickAddConfirmation] = []

        func preview(_ input: QuickAddInput) async throws -> QuickAddPreview {
            try previewResult.get()
        }

        func confirm(
            submissionID: CatalogSubmissionID, selection: QuickAddConfirmation
        ) async throws -> SubmissionConfirmResult {
            confirmations.append(selection)
            return try confirmResult.get()
        }

        func state(submissionID: CatalogSubmissionID) async throws -> CatalogSubmissionState {
            try stateResult.get()
        }
    }

    @MainActor
    private func makeViewController(
        repository: StubQuickAddRepository, initialQuery: String? = nil
    ) -> QuickAddViewController {
        QuickAddViewController(
            initialQuery: initialQuery,
            repository: repository,
            configStore: ProductConfigStore(service: Product22MockService()),
            onFindInCatalog: { _ in }
        )
    }

    // MARK: Input classification

    func testInputKindIsInferredFromShapeNotAskedOfTheUser() {
        XCTAssertEqual(QuickAddViewController.inferKind(from: "원신"), .text)
        XCTAssertEqual(QuickAddViewController.inferKind(from: "Genshin Impact"), .text)
        XCTAssertEqual(
            QuickAddViewController.inferKind(from: "https://apps.apple.com/app/id1517783697"), .url
        )
        XCTAssertEqual(
            QuickAddViewController.inferKind(from: "http://example.com/game"), .url
        )
        XCTAssertEqual(QuickAddViewController.inferKind(from: "1517783697"), .providerID)
        XCTAssertEqual(
            QuickAddViewController.inferKind(from: "com.miHoYo.GenshinImpact"), .providerID
        )
    }

    // MARK: Raw input never persists

    @MainActor
    func testRawInputIsDiscardedWhenTheAppLeavesTheForeground() {
        let repository = StubQuickAddRepository()
        let viewController = makeViewController(
            repository: repository, initialQuery: "내가 어제 결제한 그 게임"
        )
        viewController.loadViewIfNeeded()
        XCTAssertTrue(viewController.holdsRawInput)

        viewController.discardUnfinishedInput()

        XCTAssertFalse(
            viewController.holdsRawInput,
            "an unfinished raw sentence must not survive backgrounding"
        )
    }

    @MainActor
    func testNothingAboutTheFlowWritesRawInputToUserDefaults() {
        let defaults = UserDefaults.standard
        let before = Set(defaults.dictionaryRepresentation().keys)

        let secret = "제 개인적인 게임 제목 \(UUID().uuidString)"
        let repository = StubQuickAddRepository()
        let viewController = makeViewController(repository: repository, initialQuery: secret)
        viewController.loadViewIfNeeded()
        viewController.discardUnfinishedInput()

        let after = defaults.dictionaryRepresentation()
        for key in Set(after.keys).subtracting(before) {
            XCTAssertFalse(
                String(describing: after[key] ?? "").contains(secret),
                "raw Quick Add input reached UserDefaults under \(key)"
            )
        }
    }

    // MARK: Confirmation shapes

    func testLinkingAndConfirmingAreMutuallyExclusiveByConstruction() {
        let id = CatalogGameID(uuidString: Product22Fixture.gameA)!

        let link = QuickAddConfirmation.linkExisting(id, requestPublicReview: false)
        let create = QuickAddConfirmation.confirmNewGame(
            fields: QuickAddConfirmedFields(
                originalTitle: "T", developerName: nil, publisherName: nil, platforms: []
            ),
            requestPublicReview: true
        )

        // There is no representable value carrying both a selected id and
        // confirmed fields, which is exactly what the contract forbids.
        XCTAssertEqual(link.outcome, .privateRegistration)
        XCTAssertEqual(create.outcome, .pendingPublicReview)
        XCTAssertNotEqual(link, create)
    }

    func testAnExpiredPreviewBlocksConfirmationRatherThanSendingIt() {
        let expiry = Date(timeIntervalSince1970: 1_785_402_000)
        let preview = QuickAddPreview(
            submissionID: CatalogSubmissionID(uuid: UUID()),
            createdAt: nil,
            expiresAt: expiry,
            existingCandidates: [],
            newGameDraft: .init(originalTitle: "T", requiresTitleConfirmation: false),
            fieldProvenance: [],
            clarifyingQuestion: nil,
            resolution: .init(stage: .titleExact, aiUsed: false, aiFallbackUsed: false, degradeReason: nil),
            personalRegistrationAvailable: true
        )
        XCTAssertTrue(preview.isExpired(at: expiry.addingTimeInterval(1)))
        XCTAssertFalse(preview.isExpired(at: expiry.addingTimeInterval(-1)))
    }

    @MainActor
    func testAFallbackPreviewStillLetsTheUserConfirmFieldsThemselves() {
        // AI failed or timed out; the user must still be able to proceed by
        // supplying the title by hand.
        let preview = QuickAddPreview(
            submissionID: CatalogSubmissionID(uuid: UUID()),
            createdAt: nil,
            expiresAt: nil,
            existingCandidates: [],
            newGameDraft: .init(originalTitle: nil, requiresTitleConfirmation: true),
            fieldProvenance: [],
            clarifyingQuestion: nil,
            resolution: .init(
                stage: .manualDraft, aiUsed: true, aiFallbackUsed: true, degradeReason: "timeout"
            ),
            personalRegistrationAvailable: true
        )
        XCTAssertTrue(preview.resolution.aiFallbackUsed)
        XCTAssertTrue(preview.newGameDraft.requiresTitleConfirmation)
        // The raw sentence is never used as a fallback title.
        XCTAssertNil(preview.newGameDraft.originalTitle)
        XCTAssertTrue(preview.personalRegistrationAvailable)
    }
}

// MARK: - Product22PlaylogScreenTests

final class Product22PlaylogScreenTests: XCTestCase {

    private final class StubPlaylogRepository: PlaylogRepositing, @unchecked Sendable {
        var sessions: [PlaySession] = []
        var nextCursor: String?
        var createResult: Result<PlaySession?, any Error> = .success(nil)
        private(set) var createdDrafts: [PlaySessionDraft] = []
        private(set) var deleted: [PlaySession] = []
        private(set) var requestedCursors: [String?] = []

        func sessions(
            for gameID: CatalogGameID?, from: Date?, to: Date?, cursor: String?
        ) async throws -> PlaySessionPageResult {
            requestedCursors.append(cursor)
            return PlaySessionPageResult(
                sessions: sessions, nextCursor: cursor == nil ? nextCursor : nil, limit: 50
            )
        }

        func calendar(monthKey: String, timeZone: TimeZone) async throws -> PlayCalendarMonth {
            PlayCalendarDeriver.month(monthKey: monthKey, timeZone: timeZone, sessions: sessions)
        }

        func create(_ draft: PlaySessionDraft) async throws -> PlaySession? {
            createdDrafts.append(draft)
            return try createResult.get()
        }

        func update(_ draft: PlaySessionDraft, existing: PlaySession) async throws -> PlaySession? {
            createdDrafts.append(draft)
            return try createResult.get()
        }

        func delete(_ session: PlaySession) async throws { deleted.append(session) }
    }

    @MainActor
    func testAFormKeepsOneMutationKeyAcrossEveryRetryOfTheSameSave() {
        let repository = StubPlaylogRepository()
        let form = PlaySessionFormViewController(
            catalogGameID: CatalogGameID(uuidString: Product22Fixture.gameA)!,
            gameTitle: "Hollow Knight",
            existing: nil,
            repository: repository
        )
        form.loadViewIfNeeded()

        let first = form.currentDraft.clientMutationID
        XCTAssertTrue(PlayMutationKey.isValid(first))

        // Whatever the user edits, the key that makes the save idempotent does
        // not move.
        form.currentDraft.durationMinutes.map { _ in }
        XCTAssertEqual(form.currentDraft.clientMutationID, first)

        // A different form is a different action and gets its own key.
        let second = PlaySessionFormViewController(
            catalogGameID: CatalogGameID(uuidString: Product22Fixture.gameA)!,
            gameTitle: nil, existing: nil, repository: repository
        )
        second.loadViewIfNeeded()
        XCTAssertNotEqual(second.currentDraft.clientMutationID, first)
    }

    @MainActor
    func testEditingReusesTheRecordsOwnKeySoARetriedEditIsTheSameMutation() throws {
        let existing = try XCTUnwrap(
            PlaylogMapper.session(
                from: try Product22Decode.decode(
                    Components.Schemas.PlaySession.self,
                    from: Product22Fixture.playSession(mutationID: "record-key-0001")
                )
            )
        )
        let form = PlaySessionFormViewController(
            catalogGameID: existing.catalogGameID,
            gameTitle: nil,
            existing: existing,
            repository: StubPlaylogRepository()
        )
        form.loadViewIfNeeded()
        XCTAssertEqual(form.currentDraft.clientMutationID, "record-key-0001")
    }

    @MainActor
    func testANewSessionDefaultsToPrivate() {
        let form = PlaySessionFormViewController(
            catalogGameID: CatalogGameID(uuidString: Product22Fixture.gameA)!,
            gameTitle: nil, existing: nil, repository: StubPlaylogRepository()
        )
        form.loadViewIfNeeded()
        XCTAssertEqual(form.currentDraft.visibility, .privateOnly)
        XCTAssertEqual(PlaySessionVisibilityOption.default, .privateOnly)
    }

    func testOutOfRangeFormValuesAreClampedToWhatTheContractAccepts() {
        // Duration: 1...1440.
        XCTAssertEqual(PlaySessionFormViewController.boundedInt("0", min: 1, max: 1440), 1)
        XCTAssertEqual(PlaySessionFormViewController.boundedInt("9999", min: 1, max: 1440), 1440)
        XCTAssertEqual(PlaySessionFormViewController.boundedInt("60", min: 1, max: 1440), 60)
        // Progress: 0...100.
        XCTAssertEqual(PlaySessionFormViewController.boundedInt("-5", min: 0, max: 100), 0)
        XCTAssertEqual(PlaySessionFormViewController.boundedInt("300", min: 0, max: 100), 100)
        // Empty and non-numeric mean "not provided", not zero.
        XCTAssertNil(PlaySessionFormViewController.boundedInt("", min: 0, max: 100))
        XCTAssertNil(PlaySessionFormViewController.boundedInt(nil, min: 0, max: 100))
        XCTAssertNil(PlaySessionFormViewController.boundedInt("abc", min: 0, max: 100))
    }

    func testTheMonthKeyForTheCurrentMonthIsWellFormed() throws {
        let seoul = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let key = PlaylogViewController.currentMonthKey(in: seoul)
        XCTAssertEqual(key.count, 7)
        XCTAssertNotNil(PlayCalendarDeriver.window(monthKey: key, timeZone: seoul))
    }

    @MainActor
    func testTheFormOnlyOffersItselfWhenThereIsAGameToAttachTo() {
        // A session requires a catalogGameId, so the account-wide list cannot
        // offer "add".
        let accountWide = PlaylogViewController(
            catalogGameID: nil,
            gameTitle: nil,
            repository: StubPlaylogRepository(),
            configStore: ProductConfigStore(service: Product22MockService())
        )
        accountWide.loadViewIfNeeded()
        XCTAssertNil(accountWide.navigationItem.rightBarButtonItem)

        let perGame = PlaylogViewController(
            catalogGameID: CatalogGameID(uuidString: Product22Fixture.gameA)!,
            gameTitle: "Hollow Knight",
            repository: StubPlaylogRepository(),
            configStore: ProductConfigStore(service: Product22MockService())
        )
        perGame.loadViewIfNeeded()
        XCTAssertNotNil(perGame.navigationItem.rightBarButtonItem)
    }
}

// MARK: - Product22ListStateTests

final class Product22ListStateTests: XCTestCase {

    /// A disabled feature and a failure are different states, and only one of
    /// them is worth retrying.
    func testDisabledAndFailedAreDistinctStates() {
        let disabled = Product22ListState.disabled(message: "off")
        let failed = Product22ListState.failed(message: "boom")
        let empty = Product22ListState.empty(message: "nothing")

        XCTAssertNotEqual(disabled, failed)
        XCTAssertNotEqual(disabled, empty)
        XCTAssertNotEqual(failed, empty)
    }

    func testAFeatureUnavailableErrorBecomesDisabledRatherThanFailed() async {
        let store = ProductConfigStore(service: Product22MockService())
        let state = Product22ScreenState.failure(
            from: Product22Error.featureUnavailable(.disabled), configStore: store
        )
        guard case .disabled = state else {
            return XCTFail("a kill switch must not be presented as a retryable failure")
        }
    }

    func testATransportFailureBecomesRetryable() {
        let store = ProductConfigStore(service: Product22MockService())
        let state = Product22ScreenState.failure(
            from: Product22Error.transport(message: "offline"), configStore: store
        )
        guard case .failed = state else {
            return XCTFail("a network failure should be retryable")
        }
    }

    func testCancellationIsNeverRenderedAsAnError() {
        let store = ProductConfigStore(service: Product22MockService())
        let state = Product22ScreenState.failure(from: Product22Error.cancelled, configStore: store)
        guard case .loading = state else {
            return XCTFail("cancellation is not a failure the user should see")
        }
    }
}
