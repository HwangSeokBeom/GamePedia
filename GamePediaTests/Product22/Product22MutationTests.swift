import Foundation
import GamePediaProduct22API
import XCTest
@testable import GamePedia

// MARK: - Product22MutationTests
//
// Required areas 13, 14, 21, 22: mutation idempotency and ordering for
// Playlog, and the Quick Add confirmation contract including its failure
// states.

final class Product22MutationTests: XCTestCase {

    private var service: Product22MockService!
    private var authority: SessionCredentialAuthority!

    override func setUp() {
        super.setUp()
        service = Product22MockService()
        authority = Product22TestFactory.makeAuthority()
        APIClient.shared.credentialAuthority.adoptAuthenticatedSession(
            accountID: "account-a", accessToken: "token-a"
        )
    }

    override func tearDown() {
        APIClient.shared.credentialAuthority.clearSession()
        service = nil
        authority = nil
        super.tearDown()
    }

    // MARK: 13 — a retry reuses the key; a new action does not

    func testRetryingTheSameSubmissionReusesItsMutationKey() async throws {
        // The create re-reads through the typed list endpoint.
        service.playSessionsResult = .success(try Product22SubmissionFixture.playSessionListDTO())
        let repository = PlaylogRepository(service: service)
        let draft = PlaySessionDraft(
            catalogGameID: CatalogGameID(uuidString: Product22Fixture.gameA)!,
            playedAt: Date(timeIntervalSince1970: 1_785_402_000),
            durationMinutes: 60,
            outcome: .completed
        )

        // First attempt fails at the network.
        service.mutationResult = .failure(Product22Error.transport(message: "offline"))
        do {
            _ = try await repository.create(draft)
            XCTFail("expected the create to fail")
        } catch {}

        // The user taps save again. Same draft, therefore same key: the server
        // returns the original record instead of writing a duplicate.
        service.mutationResult = .success(())
        _ = try await repository.create(draft)

        let keys = service.calls.compactMap { call -> String? in
            if case .createPlaySession(let key) = call { return key }
            return nil
        }
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(keys[0], keys[1], "a retry of the same submission must reuse its key")
        XCTAssertTrue(PlayMutationKey.isValid(keys[0]), "the key must satisfy the server's pattern")
    }

    func testADifferentUserActionGetsADifferentMutationKey() async throws {
        service.playSessionsResult = .success(try Product22SubmissionFixture.playSessionListDTO())
        let repository = PlaylogRepository(service: service)
        let gameID = CatalogGameID(uuidString: Product22Fixture.gameA)!

        // Two separate sessions the user logged — not a retry of one.
        _ = try await repository.create(PlaySessionDraft(catalogGameID: gameID))
        _ = try await repository.create(PlaySessionDraft(catalogGameID: gameID))

        let keys = service.calls.compactMap { call -> String? in
            if case .createPlaySession(let key) = call { return key }
            return nil
        }
        XCTAssertEqual(keys.count, 2)
        XCTAssertNotEqual(keys[0], keys[1], "two distinct actions must not share an idempotency key")
    }

    func testMutationKeysAlwaysSatisfyTheServersPattern() {
        // ^[A-Za-z0-9._:-]+$, 8...120. A raw UUID qualifies.
        for _ in 0..<50 {
            XCTAssertTrue(PlayMutationKey.isValid(PlayMutationKey.make()))
        }
        let derived = PlayMutationKey.derived(from: PlayMutationKey.make(), suffix: "del")
        XCTAssertTrue(PlayMutationKey.isValid(derived))
        XCTAssertLessThanOrEqual(derived.count, 120)

        XCTAssertFalse(PlayMutationKey.isValid("short"))
        XCTAssertFalse(PlayMutationKey.isValid("has spaces in it"))
        XCTAssertFalse(PlayMutationKey.isValid("한글이라서안됨"))
        XCTAssertFalse(PlayMutationKey.isValid(String(repeating: "a", count: 121)))
    }

    // MARK: 14 — create / update / delete ordering

    func testCreateUpdateDeleteIssueTheirRequestsInOrderWithDistinctKeys() async throws {
        let gameID = CatalogGameID(uuidString: Product22Fixture.gameA)!
        let sessionJSON = Product22Fixture.playSession(mutationID: "create-key-0001")
        service.playSessionsResult = .success(
            try Product22SubmissionFixture.playSessionListDTO(sessions: "[\(sessionJSON)]")
        )

        let repository = PlaylogRepository(service: service)

        // 1. create — then re-read through the typed list endpoint, because
        //    the create response body is untyped in the contract.
        let draft = PlaySessionDraft(
            catalogGameID: gameID,
            durationMinutes: 60,
            outcome: .resume,
            clientMutationID: "create-key-0001"
        )
        let created = try await repository.create(draft)
        let session = try XCTUnwrap(created, "the created row should be found by its mutation id")
        XCTAssertEqual(session.clientMutationID, "create-key-0001")
        XCTAssertEqual(session.visibility, .privateOnly, "a new session defaults to private")

        // 2. update
        var edited = draft
        edited.outcome = .completed
        _ = try await repository.update(edited, existing: session)

        // 3. delete — its own key derived from the record's, so retrying the
        //    delete cannot collide with the create that wrote the row.
        try await repository.delete(session)

        let ordered = service.calls.compactMap { call -> String? in
            switch call {
            case .createPlaySession: return "create"
            case .listPlaySessions: return "list"
            case .updatePlaySession: return "update"
            case .deletePlaySession: return "delete"
            default: return nil
            }
        }
        XCTAssertEqual(ordered, ["create", "list", "update", "list", "delete"])

        guard case .deletePlaySession(_, let deleteKey)? = service.calls.last else {
            return XCTFail("expected a delete, got \(service.calls)")
        }
        XCTAssertNotEqual(deleteKey, "create-key-0001", "delete must not reuse the create's key")
        XCTAssertTrue(deleteKey.hasPrefix("create-key-0001"))
        XCTAssertTrue(PlayMutationKey.isValid(deleteKey))
    }

    func testAnEditOnlySendsTheFieldsThatActuallyChanged() throws {
        let session = try XCTUnwrap(
            PlaylogMapper.session(
                from: try Product22Decode.decode(
                    Components.Schemas.PlaySession.self,
                    from: Product22Fixture.playSession(mutationID: "key-00000001", note: "원래 메모")
                )
            )
        )

        // Only the outcome moved.
        var draft = PlaySessionDraft(
            catalogGameID: session.catalogGameID,
            playedAt: session.playedAt,
            durationMinutes: session.durationMinutes,
            progressPercent: session.progressPercent,
            mood: session.mood,
            note: session.note,
            outcome: .completed,
            visibility: session.visibility,
            clientMutationID: session.clientMutationID
        )
        var patch = PlaylogMapper.patch(from: draft, against: session)
        XCTAssertNotNil(patch.outcome)
        XCTAssertNil(patch.playedAt, "an untouched field must not be sent")
        XCTAssertNil(patch.durationMinutes)
        XCTAssertNil(patch.note)
        XCTAssertNil(patch.visibility)

        // Clearing the note sends an empty string, because the generated body
        // cannot express an explicit null.
        draft.note = "   "
        patch = PlaylogMapper.patch(from: draft, against: session)
        XCTAssertEqual(patch.note, "")
    }

    func testNoteAndMoodStayOnTheRecordAndOutOfAnalytics() throws {
        let session = try XCTUnwrap(
            PlaylogMapper.session(
                from: try Product22Decode.decode(
                    Components.Schemas.PlaySession.self,
                    from: Product22Fixture.playSession(mutationID: "key-00000001", note: "비밀 메모")
                )
            )
        )
        XCTAssertEqual(session.note, "비밀 메모")
        XCTAssertEqual(session.mood, .focused)
        XCTAssertTrue(session.hasNote)

        // What analytics is allowed to know is only that a note exists.
        var properties = ProductEventProperties()
        properties.set("has_note", flag: session.hasNote)
        properties.set("mood", code: session.mood?.rawValue ?? "")
        properties.set("note", code: session.note ?? "")
        let filtered = properties.filtered(for: .playSessionCreate)

        XCTAssertEqual(filtered.storage["has_note"], .flag(true))
        XCTAssertNil(filtered.storage["mood"])
        XCTAssertNil(filtered.storage["note"])
    }

    // MARK: 21 — Quick Add confirmation

    func testLinkingAnExistingCandidateSendsOnlyTheSelectedID() async throws {
        let repository = QuickAddRepository(service: service)
        let gameID = CatalogGameID(uuidString: Product22Fixture.gameA)!

        service.confirmResult = .success(try Product22SubmissionFixture.confirmDTO())
        let result = try await repository.confirm(
            submissionID: CatalogSubmissionID(uuid: UUID()),
            selection: .linkExisting(gameID, requestPublicReview: false)
        )
        XCTAssertEqual(result.catalogGameID?.wireValue, Product22Fixture.gameA)

        let request = try XCTUnwrap(service.lastConfirmRequest)
        XCTAssertEqual(request.selectedCatalogGameId, gameID.wireValue)
        XCTAssertNil(
            request.confirmedFields,
            "selectedCatalogGameId and confirmedFields are mutually exclusive"
        )
        XCTAssertEqual(request.requestPublicReview, false)
    }

    func testConfirmingANewGameSendsOnlyFieldsTheUserActuallyConfirmed() async throws {
        let repository = QuickAddRepository(service: service)
        let fields = QuickAddConfirmedFields(
            originalTitle: "원신",
            developerName: nil,       // never confirmed, so never sent
            publisherName: nil,
            platforms: ["iOS", "Android"]
        )

        service.confirmResult = .success(
            try Product22SubmissionFixture.confirmDTO(publicReviewStatus: "PENDING_REVIEW")
        )
        _ = try await repository.confirm(
            submissionID: CatalogSubmissionID(uuid: UUID()),
            selection: .confirmNewGame(fields: fields, requestPublicReview: true)
        )

        let request = try XCTUnwrap(service.lastConfirmRequest)
        XCTAssertNil(request.selectedCatalogGameId)
        let confirmed = try XCTUnwrap(request.confirmedFields)
        XCTAssertEqual(Product22JSON.stringArray(confirmed, key: "platforms"), ["iOS", "Android"])
        let sentKeys = Product22JSON.keys(confirmed)
        XCTAssertEqual(
            sentKeys, ["originalTitle", "platforms"],
            "an unconfirmed field must not be sent"
        )
        XCTAssertEqual(request.requestPublicReview, true)
    }

    func testPrivateRegistrationAndPublicReviewAreDistinctOutcomes() {
        let gameID = CatalogGameID(uuidString: Product22Fixture.gameA)!

        // Personal registration is immediate and private.
        let personal = QuickAddConfirmation.linkExisting(gameID, requestPublicReview: false)
        XCTAssertEqual(personal.outcome, .privateRegistration)
        XCTAssertFalse(personal.requestsPublicReview)

        // Asking for a public listing produces a REVIEW REQUEST, never a
        // publication: the submitter's own confirmation is not approval.
        let review = QuickAddConfirmation.confirmNewGame(
            fields: QuickAddConfirmedFields(
                originalTitle: "T", developerName: nil, publisherName: nil, platforms: []
            ),
            requestPublicReview: true
        )
        XCTAssertEqual(review.outcome, .pendingPublicReview)
        XCTAssertNotEqual(review.outcome, .privateRegistration)
    }

    func testProvenanceTiersKeepInferenceApartFromVerification() {
        // The distinction the UI must never blur.
        XCTAssertEqual(CatalogProvenance.providerVerified.tier, .verified)
        XCTAssertEqual(CatalogProvenance.officialSource.tier, .verified)
        XCTAssertEqual(CatalogProvenance.editorVerified.tier, .verified)

        XCTAssertEqual(CatalogProvenance.userConfirmed.tier, .asserted)
        XCTAssertEqual(CatalogProvenance.communityConfirmed.tier, .asserted)

        XCTAssertEqual(CatalogProvenance.aiInferred.tier, .unconfirmed)
        XCTAssertEqual(CatalogProvenance.disputed.tier, .unconfirmed)
        XCTAssertEqual(CatalogProvenance.unknown.tier, .unconfirmed)

        XCTAssertFalse(CatalogProvenance.aiInferred.isVerified, "AI inference is never verification")
        XCTAssertFalse(CatalogProvenance.userConfirmed.isVerified)
        XCTAssertTrue(CatalogProvenance.providerVerified.isVerified)

        // A candidate match on an unverified provider row is not an exact
        // identity match: parsing a store URL is not verification.
        XCTAssertTrue(QuickAddCandidate.MatchReason.providerIdentityExact.isVerifiedIdentity)
        XCTAssertFalse(QuickAddCandidate.MatchReason.providerIdentityUnverified.isVerifiedIdentity)
        XCTAssertFalse(QuickAddCandidate.MatchReason.fuzzyTitleSimilar.isVerifiedIdentity)
    }

    // MARK: 22 — preview expiry, quota and identity conflict

    func testAnExpiredPreviewIsRecognisedBeforeAnythingIsConfirmed() {
        let expiry = Date(timeIntervalSince1970: 1_785_402_000)
        let preview = QuickAddPreview(
            submissionID: CatalogSubmissionID(uuid: UUID()),
            createdAt: expiry.addingTimeInterval(-600),
            expiresAt: expiry,
            existingCandidates: [],
            newGameDraft: .init(originalTitle: nil, requiresTitleConfirmation: true),
            fieldProvenance: [],
            clarifyingQuestion: nil,
            resolution: .init(stage: .manualDraft, aiUsed: false, aiFallbackUsed: false, degradeReason: nil),
            personalRegistrationAvailable: true
        )

        XCTAssertFalse(preview.isExpired(at: expiry.addingTimeInterval(-1)))
        XCTAssertTrue(preview.isExpired(at: expiry))
        XCTAssertTrue(preview.isExpired(at: expiry.addingTimeInterval(1)))

        // With no structured title, the user must supply one: the raw
        // natural-language input is never persisted as a fallback title.
        XCTAssertNil(preview.newGameDraft.originalTitle)
        XCTAssertTrue(preview.newGameDraft.requiresTitleConfirmation)
    }

    func testQuotaAndConflictArriveAsDistinctRecoverableStates() async throws {
        Product22StubURLProtocol.reset()
        defer { Product22StubURLProtocol.reset() }
        let wireService = Product22TestFactory.makeService(authority: authority)

        // 429 — over quota.
        Product22StubURLProtocol.stub(
            pathContains: "/catalog/submissions/preview",
            json: Product22TestFactory.errorEnvelope(code: "SUBMISSION_QUOTA_EXCEEDED"),
            statusCode: 429
        )
        do {
            _ = try await wireService.previewSubmission(
                QuickAddMapper.previewRequest(
                    from: QuickAddInput(kind: .text, rawInput: "무언가", locale: "ko", regionCode: "KR")
                ),
                authorization: .currentSession
            )
            XCTFail("expected a rate-limit error")
        } catch let error as Product22Error {
            guard case .rateLimited(let code, _) = error else {
                return XCTFail("expected rateLimited, got \(error)")
            }
            XCTAssertEqual(code, Product22ErrorCode.submissionQuotaExceeded)
        }

        // 409 — an identity conflict, which must never be auto-merged.
        Product22StubURLProtocol.reset()
        Product22StubURLProtocol.stub(
            pathContains: "/confirm",
            json: Product22TestFactory.errorEnvelope(
                code: "CATALOG_IDENTITY_CONFLICT", message: "identity already claimed"
            ),
            statusCode: 409
        )
        do {
            _ = try await wireService.confirmSubmission(
                id: CatalogSubmissionID(uuid: UUID()),
                request: QuickAddMapper.confirmRequest(
                    from: .confirmNewGame(
                        fields: QuickAddConfirmedFields(
                            originalTitle: "T", developerName: nil, publisherName: nil, platforms: []
                        ),
                        requestPublicReview: false
                    )
                ),
                authorization: .currentSession
            )
            XCTFail("expected a conflict")
        } catch let error as Product22Error {
            guard case .conflict(let code, _) = error else {
                return XCTFail("expected conflict, got \(error)")
            }
            XCTAssertEqual(code, Product22ErrorCode.identityConflict)
        }
    }

    func testValidationErrorsAreMappedPerFieldRatherThanShownRaw() async throws {
        Product22StubURLProtocol.reset()
        defer { Product22StubURLProtocol.reset() }
        let wireService = Product22TestFactory.makeService(authority: authority)

        // The server's own message leaks implementation detail; the app keeps
        // it for diagnostics and never shows it.
        Product22StubURLProtocol.stub(
            pathContains: "/catalog/submissions/preview",
            json: Product22TestFactory.errorEnvelope(
                code: "VALIDATION_ERROR",
                message: "String contains an unpaired surrogate",
                field: "input"
            ),
            statusCode: 400
        )
        do {
            _ = try await wireService.previewSubmission(
                QuickAddMapper.previewRequest(
                    from: QuickAddInput(kind: .text, rawInput: "x", locale: "ko", regionCode: "KR")
                ),
                authorization: .currentSession
            )
            XCTFail("expected a validation error")
        } catch let error as Product22Error {
            guard case .validation(let failure) = error else {
                return XCTFail("expected validation, got \(error)")
            }
            XCTAssertEqual(failure.code, "VALIDATION_ERROR")
            XCTAssertTrue(failure.names("input"), "the failing field must be identifiable")
            // The raw text is available for diagnostics but is not the thing
            // the UI is expected to render.
            XCTAssertEqual(failure.fieldErrors.first?.field, "input")
        }
    }

    // MARK: Calendar derivation stays inside its own timezone

    func testCalendarBucketsSessionsByTheUsersLocalDay() throws {
        let seoul = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let window = try XCTUnwrap(PlayCalendarDeriver.window(monthKey: "2026-07", timeZone: seoul))

        // 2026-07-01 00:00 KST is 2026-06-30 15:00 UTC.
        XCTAssertEqual(window.start.timeIntervalSince1970, 1782831600, accuracy: 1)

        let sessions = [
            // 23:30 KST on the 15th — still the 15th locally, though it is the
            // 15th 14:30 UTC.
            makeSession(playedAt: "2026-07-15T14:30:00.000Z", minutes: 30),
            // 00:30 KST on the 16th — the next local day.
            makeSession(playedAt: "2026-07-15T15:30:00.000Z", minutes: 45),
            // no recorded duration
            makeSession(playedAt: "2026-07-15T16:00:00.000Z", minutes: nil)
        ]
        let month = PlayCalendarDeriver.month(monthKey: "2026-07", timeZone: seoul, sessions: sessions)

        XCTAssertEqual(month.day("2026-07-15")?.sessionCount, 1)
        XCTAssertEqual(month.day("2026-07-15")?.knownMinutes, 30)
        XCTAssertEqual(month.day("2026-07-16")?.sessionCount, 2)
        XCTAssertEqual(month.day("2026-07-16")?.knownMinutes, 45)
        XCTAssertEqual(month.day("2026-07-16")?.hasSessionsWithUnknownDuration, true)
        XCTAssertEqual(month.totalSessions, 3)
        XCTAssertFalse(month.isEmpty)

        XCTAssertNil(PlayCalendarDeriver.window(monthKey: "2026-13", timeZone: seoul))
        XCTAssertNil(PlayCalendarDeriver.window(monthKey: "nonsense", timeZone: seoul))
    }

    private func makeSession(playedAt: String, minutes: Int?) -> PlaySession {
        PlaySession(
            id: PlaySessionID(uuid: UUID()),
            catalogGameID: CatalogGameID(uuidString: Product22Fixture.gameA)!,
            regionalReleaseID: nil,
            playedAt: (try? RFC3339DateTranscoder().decode(playedAt)) ?? Date(),
            durationMinutes: minutes,
            progressPercent: nil,
            mood: nil,
            note: nil,
            outcome: .resume,
            visibility: .privateOnly,
            provenance: .userConfirmed,
            clientMutationID: PlayMutationKey.make(),
            createdAt: nil,
            updatedAt: nil
        )
    }
}
