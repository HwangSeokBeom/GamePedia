import Foundation
import GamePediaProduct22API

// MARK: - Product22APIServicing
//
// The seam repositories depend on. It speaks generated contract types: those
// are the only DTOs at the network boundary, and translating them into domain
// entities is the repositories' job.
//
// Everything named here stays inside `Data/Product22`. Nothing above that
// directory ever sees a `Components.Schemas.…`.

protocol Product22APIServicing: Sendable {

    // Product control plane
    func fetchProductConfig() async throws -> Components.Schemas.ProductConfig
    func submitProductEvents(_ events: [ProductEventPayload]) async throws

    // Today + magazine
    func fetchTodayFeed(locale: String?, timezone: String, limit: Int?) async throws -> Components.Schemas.TodayFeed
    func fetchArticle(slug: String) async throws -> Components.Schemas.PublicArticle

    // Canonical catalog
    func searchCatalogGames(
        query: String, locale: String?, regionCode: String?,
        platform: String?, limit: Int?, cursor: String?
    ) async throws -> CatalogSearchPage
    func fetchCatalogGame(id: CatalogGameID) async throws -> Components.Schemas.CatalogGameDetail
    func followCatalogGame(
        id: CatalogGameID, regionalReleaseID: RegionalReleaseID?, authorization: Product22Authorization
    ) async throws
    func unfollowCatalogGame(id: CatalogGameID, authorization: Product22Authorization) async throws
    func submitCorrections(
        gameID: CatalogGameID, corrections: [CatalogCorrectionInput], authorization: Product22Authorization
    ) async throws

    // AI quick add
    func previewSubmission(
        _ request: Components.Schemas.SubmissionPreviewRequest, authorization: Product22Authorization
    ) async throws -> Components.Schemas.SubmissionPreviewResponse
    /// Returns whether the server created a new canonical game (201) or linked
    /// an existing one / replayed an earlier confirmation (200). The response
    /// body is untyped in the contract and is deliberately not read; see
    /// docs/product-2.2-contract-gaps.md.
    func confirmSubmission(
        id: CatalogSubmissionID,
        request: Components.Schemas.SubmissionConfirmRequest,
        authorization: Product22Authorization
    ) async throws -> SubmissionConfirmOutcome

    // Playlog
    func listPlaySessions(
        catalogGameID: CatalogGameID?, from: Date?, to: Date?,
        outcome: Components.Schemas.PlaySessionOutcome?, limit: Int?, cursor: String?
    ) async throws -> PlaySessionPage
    func createPlaySession(
        _ request: Components.Schemas.CreatePlaySessionRequest, authorization: Product22Authorization
    ) async throws
    func updatePlaySession(
        id: PlaySessionID, patch: PlaySessionPatch, authorization: Product22Authorization
    ) async throws
    func deletePlaySession(
        id: PlaySessionID, clientMutationID: String, authorization: Product22Authorization
    ) async throws

    // Play intelligence
    func fetchGameDNA() async throws -> Components.Schemas.GameDna
    func recommendPlayCompass(
        _ request: Components.Schemas.PlayCompassRequest, authorization: Product22Authorization
    ) async throws -> Components.Schemas.PlayCompassResponse
    func recordPlayCompassEvent(
        _ request: Components.Schemas.PlayCompassEventRequest, authorization: Product22Authorization
    ) async throws
    func fetchMonthlyReplay(month: String, timezone: String) async throws -> Components.Schemas.MonthlyReplay
}

// MARK: - Supporting types

typealias ProductEventPayload = Components.Schemas.ProductEventBatchRequest.eventsPayloadPayload

/// Both list endpoints declare their `meta` as an untyped object, so the
/// pagination cursor inside it cannot be read without guessing a key name.
/// The app therefore asks for a single page at the contract's maximum `limit`
/// and does not paginate. See docs/product-2.2-contract-gaps.md.
struct CatalogSearchPage: Sendable {
    let games: [Components.Schemas.CatalogGameSummary]
}

struct PlaySessionPage: Sendable {
    let sessions: [Components.Schemas.PlaySession]
}

struct CatalogCorrectionInput: Sendable, Equatable {
    let fieldPath: String
    let proposedValue: String
    let sourceURL: String?
}

enum SubmissionConfirmOutcome: Sendable, Equatable {
    /// 201 — a new PRIVATE canonical game was created.
    case created
    /// 200 — an existing candidate was linked, or an earlier confirmation was
    /// replayed idempotently.
    case linkedOrReplayed
}

/// Only the fields the app edits. A member left nil is omitted from the
/// request, so a PATCH never touches something the user did not edit.
///
/// The generated body types every nullable field as a plain `Optional` and
/// encodes with `encodeIfPresent`, so "send explicit null" is not expressible
/// through the client — nil means "omit". Clearing an optional text field is
/// therefore done by sending an empty string, which the contract permits
/// (`note` has a maxLength and no minLength) and which the UI presents as
/// "no note".
struct PlaySessionPatch: Sendable {
    var playedAt: Date?
    var durationMinutes: Int?
    var progressPercent: Int?
    var mood: String?
    var note: String?
    var outcome: Components.Schemas.PlaySessionOutcome?
    var visibility: PlaySessionVisibility?
    var clientMutationID: String
}

/// The three visibility values, shared by create and update. Declared once here
/// rather than passing one operation's generated enum into another's API.
enum PlaySessionVisibility: String, Sendable, CaseIterable {
    case privateOnly = "PRIVATE"
    case friends = "FRIENDS"
    case publicallyVisible = "PUBLIC"
}

// MARK: - DefaultProduct22APIService

/// Wraps the generated client. One client instance, one authorization
/// middleware; the per-call credential rule travels through a task local.
final class DefaultProduct22APIService: Product22APIServicing {

    // Stored as the generated protocol rather than the concrete `Client`
    // struct. Holding the struct by value would drag OpenAPIRuntime's internal
    // `UniversalClient` metadata into this module's link, which is exactly the
    // transport dependency the API package exists to contain.
    private let client: any APIProtocol

    init(
        baseURL: URL = AppConfig.coreBaseURL,
        authority: SessionCredentialAuthority = APIClient.shared.credentialAuthority,
        session: URLSession = .shared
    ) {
        self.client = Product22ClientFactory.makeClient(
            baseURL: baseURL,
            middlewares: [Product22AuthorizationPolicy.makeMiddleware(authority: authority)],
            session: session
        )
    }

    /// Test seam: inject a fully deterministic transport.
    init(client: any APIProtocol) {
        self.client = client
    }

    // MARK: Product control plane

    func fetchProductConfig() async throws -> Components.Schemas.ProductConfig {
        try await perform(.currentSession) {
            switch try await client.getProductConfig(.init()) {
            case .ok(let ok):
                return try require(try ok.body.json.value2.data, "product-config")
            case .unauthorized:
                throw Product22Error.unauthorized
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    func submitProductEvents(_ events: [ProductEventPayload]) async throws {
        guard !events.isEmpty else { return }
        try await perform(.currentSession) {
            switch try await client.submitProductEvents(
                .init(body: .json(.init(events: events)))
            ) {
            case .accepted:
                return
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    // MARK: Today + magazine

    func fetchTodayFeed(
        locale: String?, timezone: String, limit: Int?
    ) async throws -> Components.Schemas.TodayFeed {
        try await perform(.currentSession) {
            switch try await client.getTodayFeed(
                .init(query: .init(locale: locale, timezone: timezone, limit: limit))
            ) {
            case .ok(let ok):
                return try require(try ok.body.json.value2.data, "today")
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    func fetchArticle(slug: String) async throws -> Components.Schemas.PublicArticle {
        try await perform(.currentSession) {
            switch try await client.getArticle(.init(path: .init(slug: slug))) {
            case .ok(let ok):
                return try require(try ok.body.json.value2.data, "article").article
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .notFound:
                throw Product22Error.notFound
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    // MARK: Canonical catalog

    func searchCatalogGames(
        query: String, locale: String?, regionCode: String?,
        platform: String?, limit: Int?, cursor: String?
    ) async throws -> CatalogSearchPage {
        try await perform(.currentSession) {
            switch try await client.searchCatalogGames(
                .init(query: .init(
                    query: query, locale: locale, regionCode: regionCode,
                    platform: platform, limit: limit, cursor: cursor
                ))
            ) {
            case .ok(let ok):
                let data = try require(try ok.body.json.value2.data, "catalog search")
                return CatalogSearchPage(games: data.games)
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    func fetchCatalogGame(id: CatalogGameID) async throws -> Components.Schemas.CatalogGameDetail {
        try await perform(.currentSession) {
            switch try await client.getCatalogGame(
                .init(path: .init(catalogGameId: id.wireValue))
            ) {
            case .ok(let ok):
                return try require(try ok.body.json.value2.data, "catalog game")
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .notFound:
                throw Product22Error.notFound
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    func followCatalogGame(
        id: CatalogGameID, regionalReleaseID: RegionalReleaseID?, authorization: Product22Authorization
    ) async throws {
        try await perform(authorization) {
            switch try await client.followCatalogGame(
                .init(
                    path: .init(catalogGameId: id.wireValue),
                    body: .json(.init(regionalReleaseId: regionalReleaseID?.wireValue))
                )
            ) {
            case .ok:
                return
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .notFound:
                throw Product22Error.notFound
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    func unfollowCatalogGame(id: CatalogGameID, authorization: Product22Authorization) async throws {
        try await perform(authorization) {
            switch try await client.unfollowCatalogGame(
                .init(path: .init(catalogGameId: id.wireValue))
            ) {
            case .ok:
                return
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .notFound:
                throw Product22Error.notFound
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    func submitCorrections(
        gameID: CatalogGameID, corrections: [CatalogCorrectionInput], authorization: Product22Authorization
    ) async throws {
        try await perform(authorization) {
            switch try await client.submitCatalogCorrections(
                .init(
                    path: .init(catalogGameId: gameID.wireValue),
                    body: .json(.init(corrections: corrections.map {
                        .init(
                            fieldPath: $0.fieldPath,
                            proposedValue: try Product22JSON.value($0.proposedValue),
                            sourceUrl: $0.sourceURL
                        )
                    }))
                )
            ) {
            case .accepted:
                return
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .notFound:
                throw Product22Error.notFound
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    // MARK: AI quick add

    func previewSubmission(
        _ request: Components.Schemas.SubmissionPreviewRequest, authorization: Product22Authorization
    ) async throws -> Components.Schemas.SubmissionPreviewResponse {
        try await perform(authorization) {
            switch try await client.previewCatalogSubmission(.init(body: .json(request))) {
            case .ok(let ok):
                return try require(try ok.body.json.value2.data, "submission preview")
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .tooManyRequests(let response):
                throw Product22ErrorMapper.rateLimited(try response.body.json)
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    func confirmSubmission(
        id: CatalogSubmissionID,
        request: Components.Schemas.SubmissionConfirmRequest,
        authorization: Product22Authorization
    ) async throws -> SubmissionConfirmOutcome {
        try await perform(authorization) {
            switch try await client.confirmCatalogSubmission(
                .init(path: .init(submissionId: id.wireValue), body: .json(request))
            ) {
            case .created:
                return .created
            case .ok:
                return .linkedOrReplayed
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .notFound:
                throw Product22Error.notFound
            case .conflict(let response):
                throw Product22ErrorMapper.conflict(try response.body.json)
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    // MARK: Playlog

    func listPlaySessions(
        catalogGameID: CatalogGameID?, from: Date?, to: Date?,
        outcome: Components.Schemas.PlaySessionOutcome?, limit: Int?, cursor: String?
    ) async throws -> PlaySessionPage {
        try await perform(.currentSession) {
            switch try await client.listPlaySessions(
                .init(query: .init(
                    catalogGameId: catalogGameID?.wireValue,
                    from: from, to: to, outcome: outcome, limit: limit, cursor: cursor
                ))
            ) {
            case .ok(let ok):
                let data = try require(try ok.body.json.value2.data, "play sessions")
                return PlaySessionPage(sessions: data.playSessions)
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    func createPlaySession(
        _ request: Components.Schemas.CreatePlaySessionRequest, authorization: Product22Authorization
    ) async throws {
        try await perform(authorization) {
            switch try await client.createPlaySession(.init(body: .json(request))) {
            case .ok, .created:
                // 200 means a retried clientMutationId returned the original
                // record: identical outcome, so both are success.
                return
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    func updatePlaySession(
        id: PlaySessionID, patch: PlaySessionPatch, authorization: Product22Authorization
    ) async throws {
        try await perform(authorization) {
            switch try await client.updatePlaySession(
                .init(path: .init(id: id.wireValue), body: .json(patch.requestBody))
            ) {
            case .ok:
                return
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .notFound:
                throw Product22Error.notFound
            case .conflict(let response):
                throw Product22ErrorMapper.conflict(try response.body.json)
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    func deletePlaySession(
        id: PlaySessionID, clientMutationID: String, authorization: Product22Authorization
    ) async throws {
        try await perform(authorization) {
            switch try await client.deletePlaySession(
                .init(
                    path: .init(id: id.wireValue),
                    body: .json(.init(clientMutationId: clientMutationID))
                )
            ) {
            case .ok:
                return
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .notFound:
                // Already gone is the outcome the user asked for.
                throw Product22Error.notFound
            case .conflict(let response):
                throw Product22ErrorMapper.conflict(try response.body.json)
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    // MARK: Play intelligence

    func fetchGameDNA() async throws -> Components.Schemas.GameDna {
        try await perform(.currentSession) {
            switch try await client.getGameDna(.init()) {
            case .ok(let ok):
                return try require(try ok.body.json.value2.data, "game DNA")
            case .unauthorized:
                throw Product22Error.unauthorized
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    func recommendPlayCompass(
        _ request: Components.Schemas.PlayCompassRequest, authorization: Product22Authorization
    ) async throws -> Components.Schemas.PlayCompassResponse {
        try await perform(authorization) {
            switch try await client.recommendPlayCompass(.init(body: .json(request))) {
            case .ok(let ok):
                return try require(try ok.body.json.value2.data, "play compass")
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    func recordPlayCompassEvent(
        _ request: Components.Schemas.PlayCompassEventRequest, authorization: Product22Authorization
    ) async throws {
        try await perform(authorization) {
            switch try await client.recordPlayCompassEvent(.init(body: .json(request))) {
            case .created:
                return
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    func fetchMonthlyReplay(month: String, timezone: String) async throws -> Components.Schemas.MonthlyReplay {
        try await perform(.currentSession) {
            switch try await client.getMonthlyReplay(
                .init(query: .init(month: month, timezone: timezone))
            ) {
            case .ok(let ok):
                return try require(try ok.body.json.value2.data, "monthly replay")
            case .badRequest(let response):
                throw Product22ErrorMapper.validation(try response.body.json)
            case .unauthorized:
                throw Product22Error.unauthorized
            case .serviceUnavailable(let response):
                throw Product22ErrorMapper.featureUnavailable(try response.body.json)
            case .undocumented(let statusCode, _):
                throw Product22ErrorMapper.undocumented(statusCode: statusCode)
            }
        }
    }

    // MARK: Plumbing

    /// Runs `body` with the call's authorization mode installed, and converts
    /// anything thrown into `Product22Error`.
    private func perform<T>(
        _ authorization: Product22Authorization,
        _ body: () async throws -> T
    ) async throws -> T {
        do {
            return try await Product22AuthorizationContext.withAuthorization(authorization, operation: body)
        } catch {
            throw Product22ErrorMapper.map(error)
        }
    }

    /// The contract marks `data` required on these envelopes, but the generated
    /// `allOf` member is optional. A missing payload is a contract violation,
    /// not an empty result.
    private func require<T>(_ value: T?, _ what: String) throws -> T {
        guard let value else {
            throw Product22Error.decoding(message: "\(what) response carried no data")
        }
        return value
    }
}

// MARK: - PlaySessionPatch → request body

private extension PlaySessionPatch {
    var requestBody: Operations.updatePlaySession.Input.Body.jsonPayload {
        .init(
            playedAt: playedAt,
            durationMinutes: durationMinutes,
            progressPercent: progressPercent,
            mood: mood,
            note: note,
            outcome: outcome,
            visibility: visibility.flatMap {
                Operations.updatePlaySession.Input.Body.jsonPayload.visibilityPayload(rawValue: $0.rawValue)
            },
            clientMutationId: clientMutationID
        )
    }
}
