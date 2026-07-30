import Foundation
import GamePediaProduct22API

// MARK: - Account-bound mutation authorization
//
// Every repository that mutates goes through here rather than choosing an
// authorization mode inline. A gesture captures its account expectation at the
// moment the user acts; the request binds that expectation atomically just
// before transmission. If the account changed in between, the request fails
// instead of being sent under the new account's credential.

enum Product22MutationAuthorizer {

    /// The authorization for a mutation the signed-in user started.
    ///
    /// A gesture made while signed out returns `.guestOnly`, which fails
    /// closed: a guest action can never acquire a token that appeared after
    /// the gesture.
    static func captureExpectation(
        authority: SessionCredentialAuthority = APIClient.shared.credentialAuthority
    ) -> Product22Authorization {
        guard let accountID = authority.currentAccountID,
              let expectation = authority.expectation(accountID: accountID) else {
            return .guestOnly
        }
        return .boundAccount(expectation)
    }
}

// MARK: - MagazineRepositing

protocol MagazineRepositing: Sendable {
    func article(slug: String) async throws -> Article
}

/// Articles are cached per slug for the session. They are public editorial
/// content with no per-account component, so the cache is not account scoped —
/// but it is still cleared on sign-out along with everything else, because a
/// shared device should not hand the next user a reading trail.
actor MagazineRepository: MagazineRepositing {

    private let service: any Product22APIServicing
    private var cache: [String: Article] = [:]

    init(service: any Product22APIServicing) {
        self.service = service
    }

    func article(slug: String) async throws -> Article {
        if let cached = cache[slug] { return cached }
        let dto = try await service.fetchArticle(slug: slug)
        let article = try ArticleMapper.article(from: dto)
        cache[slug] = article
        return article
    }

    func clear() {
        cache.removeAll()
    }
}

// MARK: - CatalogRepositing

protocol CatalogRepositing: Sendable {
    func search(query: String, locale: String?, regionCode: String?, platform: String?) async throws -> [CatalogGameSummary]
    func detail(id: CatalogGameID) async throws -> CatalogGameDetail
    func setFollowing(_ following: Bool, id: CatalogGameID, regionalReleaseID: RegionalReleaseID?) async throws
    func submitCorrections(_ corrections: [CatalogCorrection], for id: CatalogGameID) async throws
}

actor CatalogRepository: CatalogRepositing {

    /// The contract's maximum. Pagination is not available because the cursor
    /// lives in an untyped `meta`; see docs/product-2.2-contract-gaps.md.
    private static let pageLimit = 50

    private let service: any Product22APIServicing

    init(service: any Product22APIServicing) {
        self.service = service
    }

    func search(
        query: String,
        locale: String?,
        regionCode: String?,
        platform: String?
    ) async throws -> [CatalogGameSummary] {
        let page = try await service.searchCatalogGames(
            query: query,
            locale: locale,
            regionCode: regionCode,
            platform: platform,
            limit: Self.pageLimit,
            cursor: nil
        )
        return page.games.compactMap(CatalogMapper.summary(from:))
    }

    func detail(id: CatalogGameID) async throws -> CatalogGameDetail {
        let dto = try await service.fetchCatalogGame(id: id)
        guard let detail = CatalogMapper.detail(from: dto) else {
            throw Product22Error.decoding(message: "catalog detail missing required fields")
        }
        return detail
    }

    /// Follow and unfollow are account-bound: the gesture's account is
    /// captured now and validated immediately before transmission.
    func setFollowing(
        _ following: Bool,
        id: CatalogGameID,
        regionalReleaseID: RegionalReleaseID?
    ) async throws {
        let authorization = Product22MutationAuthorizer.captureExpectation()
        if following {
            try await service.followCatalogGame(
                id: id, regionalReleaseID: regionalReleaseID, authorization: authorization
            )
        } else {
            try await service.unfollowCatalogGame(id: id, authorization: authorization)
        }
    }

    /// A correction is a *proposal*. The contract accepts only fieldPath,
    /// proposedValue and sourceUrl, and this sends nothing else.
    func submitCorrections(
        _ corrections: [CatalogCorrection],
        for id: CatalogGameID
    ) async throws {
        guard !corrections.isEmpty else { return }
        try await service.submitCorrections(
            gameID: id,
            corrections: corrections.map {
                CatalogCorrectionInput(
                    fieldPath: $0.fieldPath,
                    proposedValue: $0.proposedValue,
                    sourceURL: $0.sourceURL?.absoluteString
                )
            },
            authorization: Product22MutationAuthorizer.captureExpectation()
        )
    }
}

// MARK: - PlaylogRepositing

protocol PlaylogRepositing: Sendable {
    func sessions(for gameID: CatalogGameID?, from: Date?, to: Date?) async throws -> [PlaySession]
    func calendar(monthKey: String, timeZone: TimeZone) async throws -> PlayCalendarMonth
    func create(_ draft: PlaySessionDraft) async throws -> PlaySession?
    func update(_ draft: PlaySessionDraft, existing: PlaySession) async throws -> PlaySession?
    func delete(_ session: PlaySession) async throws
}

actor PlaylogRepository: PlaylogRepositing {

    private static let pageLimit = 50

    private let service: any Product22APIServicing

    init(service: any Product22APIServicing) {
        self.service = service
    }

    func sessions(
        for gameID: CatalogGameID?,
        from: Date?,
        to: Date?
    ) async throws -> [PlaySession] {
        let page = try await service.listPlaySessions(
            catalogGameID: gameID,
            from: from,
            to: to,
            outcome: nil,
            limit: Self.pageLimit,
            cursor: nil
        )
        return page.sessions.compactMap(PlaylogMapper.session(from:))
    }

    /// Derived from the typed session list; the dedicated calendar endpoint's
    /// body is untyped. See docs/product-2.2-contract-gaps.md.
    func calendar(monthKey: String, timeZone: TimeZone) async throws -> PlayCalendarMonth {
        guard let window = PlayCalendarDeriver.window(monthKey: monthKey, timeZone: timeZone) else {
            throw Product22Error.validation(
                ValidationFailure(code: "INVALID_MONTH", fieldErrors: [])
            )
        }
        let sessions = try await sessions(for: nil, from: window.start, to: window.end)
        return PlayCalendarDeriver.month(
            monthKey: monthKey, timeZone: timeZone, sessions: sessions
        )
    }

    /// Creates, then re-reads the row through the typed list endpoint — the
    /// create response body is untyped, so the persisted record cannot be read
    /// from it. Returns nil if the re-read cannot find it, which the caller
    /// treats as "written, but not yet visible" rather than as a failure.
    func create(_ draft: PlaySessionDraft) async throws -> PlaySession? {
        try await service.createPlaySession(
            PlaylogMapper.createRequest(from: draft),
            authorization: Product22MutationAuthorizer.captureExpectation()
        )
        return try await findByMutationID(draft.clientMutationID, gameID: draft.catalogGameID)
    }

    func update(_ draft: PlaySessionDraft, existing: PlaySession) async throws -> PlaySession? {
        try await service.updatePlaySession(
            id: existing.id,
            patch: PlaylogMapper.patch(from: draft, against: existing),
            authorization: Product22MutationAuthorizer.captureExpectation()
        )
        let refreshed = try await sessions(for: existing.catalogGameID, from: nil, to: nil)
        return refreshed.first { $0.id == existing.id }
    }

    /// Delete gets its own mutation key derived from the record's own key, so
    /// retrying a delete stays idempotent without colliding with the create
    /// that wrote the row.
    func delete(_ session: PlaySession) async throws {
        try await service.deletePlaySession(
            id: session.id,
            clientMutationID: PlayMutationKey.derived(from: session.clientMutationID, suffix: "del"),
            authorization: Product22MutationAuthorizer.captureExpectation()
        )
    }

    private func findByMutationID(
        _ mutationID: String,
        gameID: CatalogGameID
    ) async throws -> PlaySession? {
        let refreshed = try await sessions(for: gameID, from: nil, to: nil)
        return refreshed.first { $0.clientMutationID == mutationID }
    }
}

// MARK: - PlayIntelligenceRepositing

protocol PlayIntelligenceRepositing: Sendable {
    func gameDNA() async throws -> GameDNAProfile
    func recommend(_ query: PlayCompassQuery) async throws -> PlayCompassResult
    func sendFeedback(_ feedback: PlayCompassFeedback) async throws
    func monthlyReplay(monthKey: String, timezone: String) async throws -> MonthlyReplay
}

actor PlayIntelligenceRepository: PlayIntelligenceRepositing {

    private let service: any Product22APIServicing

    init(service: any Product22APIServicing) {
        self.service = service
    }

    func gameDNA() async throws -> GameDNAProfile {
        PlayIntelligenceMapper.gameDNA(from: try await service.fetchGameDNA())
    }

    /// A recommendation request is a user gesture that writes feedback state
    /// server-side, so it binds the gesture's account like any other mutation.
    func recommend(_ query: PlayCompassQuery) async throws -> PlayCompassResult {
        let dto = try await service.recommendPlayCompass(
            PlayCompassMapper.request(from: query),
            authorization: Product22MutationAuthorizer.captureExpectation()
        )
        return PlayCompassMapper.result(from: dto)
    }

    func sendFeedback(_ feedback: PlayCompassFeedback) async throws {
        try await service.recordPlayCompassEvent(
            PlayCompassMapper.eventRequest(from: feedback),
            authorization: Product22MutationAuthorizer.captureExpectation()
        )
    }

    func monthlyReplay(monthKey: String, timezone: String) async throws -> MonthlyReplay {
        PlayIntelligenceMapper.monthlyReplay(
            from: try await service.fetchMonthlyReplay(month: monthKey, timezone: timezone)
        )
    }
}

// MARK: - QuickAddRepositing

protocol QuickAddRepositing: Sendable {
    func preview(_ input: QuickAddInput) async throws -> QuickAddPreview
    func confirm(
        submissionID: CatalogSubmissionID,
        selection: QuickAddConfirmation
    ) async throws -> SubmissionConfirmOutcome
}

actor QuickAddRepository: QuickAddRepositing {

    private let service: any Product22APIServicing

    init(service: any Product22APIServicing) {
        self.service = service
    }

    func preview(_ input: QuickAddInput) async throws -> QuickAddPreview {
        let dto = try await service.previewSubmission(
            QuickAddMapper.previewRequest(from: input),
            authorization: Product22MutationAuthorizer.captureExpectation()
        )
        return QuickAddMapper.preview(from: dto)
    }

    func confirm(
        submissionID: CatalogSubmissionID,
        selection: QuickAddConfirmation
    ) async throws -> SubmissionConfirmOutcome {
        try await service.confirmSubmission(
            id: submissionID,
            request: QuickAddMapper.confirmRequest(from: selection),
            authorization: Product22MutationAuthorizer.captureExpectation()
        )
    }
}
