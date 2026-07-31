import Foundation
import GamePediaProduct22API
@testable import GamePedia

// MARK: - Product22MockService
//
// A recording stand-in for `Product22APIServicing`, used by the suites that
// exercise app-side policy — cache isolation, fail-closed config, mutation
// ordering — rather than the wire format. Suites that care about the wire go
// through `Product22StubURLProtocol` and the real generated client instead.

final class Product22MockService: Product22APIServicing, @unchecked Sendable {

    // MARK: Recording

    enum Call: Equatable {
        case productConfig
        case productEvents(eventIDs: [String])
        case today(locale: String?, timezone: String)
        case article(slug: String)
        case catalogSearch(query: String)
        case catalogDetail(id: String)
        case follow(id: String)
        case unfollow(id: String)
        case corrections(id: String, count: Int)
        case previewSubmission
        case confirmSubmission(id: String)
        case fetchSubmission(id: String)
        case listPlaySessions(gameID: String?)
        case createPlaySession(clientMutationID: String)
        case updatePlaySession(id: String, clientMutationID: String)
        case deletePlaySession(id: String, clientMutationID: String)
        case gameDNA
        case playCompass
        case playCompassEvent
        case monthlyReplay(month: String)
    }

    private let lock = NSLock()
    private var _calls: [Call] = []

    var calls: [Call] {
        lock.lock(); defer { lock.unlock() }
        return _calls
    }

    private func record(_ call: Call) {
        lock.lock(); defer { lock.unlock() }
        _calls.append(call)
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        _calls = []
    }

    // MARK: Programmable responses

    var productConfigResult: Result<Components.Schemas.ProductConfig, any Error> =
        .failure(Product22Error.transport(message: "not stubbed"))
    var todayResult: Result<Components.Schemas.TodayFeed, any Error> =
        .failure(Product22Error.transport(message: "not stubbed"))
    var playSessionsResult: Result<Components.Schemas.PlaySessionListResult, any Error> =
        .failure(Product22Error.transport(message: "not stubbed"))
    var productEventsResult: Result<Void, any Error> = .success(())
    var previewResult: Result<Components.Schemas.SubmissionPreviewResponse, any Error> =
        .failure(Product22Error.transport(message: "not stubbed"))
    var confirmResult: Result<Components.Schemas.SubmissionConfirmResult, any Error> =
        .failure(Product22Error.transport(message: "not stubbed"))
    var submissionStateResult: Result<Components.Schemas.SubmissionState, any Error> =
        .failure(Product22Error.transport(message: "not stubbed"))
    var searchResult: Result<Components.Schemas.CatalogSearchResult, any Error> =
        .failure(Product22Error.transport(message: "not stubbed"))
    var mutationResult: Result<Void, any Error> = .success(())

    /// Delays every Today response, so a test can change the account or fire a
    /// second load while the first is still in flight.
    var todayDelay: Duration = .zero

    // MARK: Product control plane

    func fetchProductConfig() async throws -> Components.Schemas.ProductConfig {
        record(.productConfig)
        return try productConfigResult.get()
    }

    func submitProductEvents(_ events: [ProductEventPayload]) async throws {
        record(.productEvents(eventIDs: events.map(\.eventId)))
        try productEventsResult.get()
    }

    // MARK: Today + magazine

    func fetchTodayFeed(
        locale: String?, timezone: String, limit: Int?
    ) async throws -> Components.Schemas.TodayFeed {
        record(.today(locale: locale, timezone: timezone))
        if todayDelay > .zero { try? await Task.sleep(for: todayDelay) }
        return try todayResult.get()
    }

    func fetchArticle(slug: String) async throws -> Components.Schemas.PublicArticle {
        record(.article(slug: slug))
        throw Product22Error.notFound
    }

    // MARK: Catalog

    private(set) var searchCursors: [String?] = []

    func searchCatalogGames(
        query: String, locale: String?, regionCode: String?,
        platform: String?, limit: Int?, cursor: String?
    ) async throws -> Components.Schemas.CatalogSearchResult {
        record(.catalogSearch(query: query))
        searchCursors.append(cursor)
        return try searchResult.get()
    }

    func fetchCatalogGame(id: CatalogGameID) async throws -> Components.Schemas.CatalogGameDetail {
        record(.catalogDetail(id: id.wireValue))
        throw Product22Error.notFound
    }

    func followCatalogGame(
        id: CatalogGameID, regionalReleaseID: RegionalReleaseID?, authorization: Product22Authorization
    ) async throws {
        record(.follow(id: id.wireValue))
        try mutationResult.get()
    }

    func unfollowCatalogGame(id: CatalogGameID, authorization: Product22Authorization) async throws {
        record(.unfollow(id: id.wireValue))
        try mutationResult.get()
    }

    func submitCorrections(
        gameID: CatalogGameID, corrections: [CatalogCorrectionInput], authorization: Product22Authorization
    ) async throws {
        record(.corrections(id: gameID.wireValue, count: corrections.count))
        try mutationResult.get()
    }

    // MARK: Quick add

    func previewSubmission(
        _ request: Components.Schemas.SubmissionPreviewRequest, authorization: Product22Authorization
    ) async throws -> Components.Schemas.SubmissionPreviewResponse {
        record(.previewSubmission)
        return try previewResult.get()
    }

    private(set) var lastConfirmRequest: Components.Schemas.SubmissionConfirmRequest?

    func confirmSubmission(
        id: CatalogSubmissionID,
        request: Components.Schemas.SubmissionConfirmRequest,
        authorization: Product22Authorization
    ) async throws -> Components.Schemas.SubmissionConfirmResult {
        lastConfirmRequest = request
        record(.confirmSubmission(id: id.wireValue))
        return try confirmResult.get()
    }

    func fetchSubmission(id: CatalogSubmissionID) async throws -> Components.Schemas.SubmissionState {
        record(.fetchSubmission(id: id.wireValue))
        return try submissionStateResult.get()
    }

    // MARK: Playlog

    private(set) var playSessionCursors: [String?] = []

    func listPlaySessions(
        catalogGameID: CatalogGameID?, from: Date?, to: Date?,
        outcome: Components.Schemas.PlaySessionOutcome?, limit: Int?, cursor: String?
    ) async throws -> Components.Schemas.PlaySessionListResult {
        record(.listPlaySessions(gameID: catalogGameID?.wireValue))
        playSessionCursors.append(cursor)
        return try playSessionsResult.get()
    }

    func createPlaySession(
        _ request: Components.Schemas.CreatePlaySessionRequest, authorization: Product22Authorization
    ) async throws {
        record(.createPlaySession(clientMutationID: request.clientMutationId))
        try mutationResult.get()
    }

    func updatePlaySession(
        id: PlaySessionID, patch: PlaySessionPatch, authorization: Product22Authorization
    ) async throws {
        record(.updatePlaySession(id: id.wireValue, clientMutationID: patch.clientMutationID))
        try mutationResult.get()
    }

    func deletePlaySession(
        id: PlaySessionID, clientMutationID: String, authorization: Product22Authorization
    ) async throws {
        record(.deletePlaySession(id: id.wireValue, clientMutationID: clientMutationID))
        try mutationResult.get()
    }

    // MARK: Play intelligence

    func fetchGameDNA() async throws -> Components.Schemas.GameDna {
        record(.gameDNA)
        throw Product22Error.notFound
    }

    func recommendPlayCompass(
        _ request: Components.Schemas.PlayCompassRequest, authorization: Product22Authorization
    ) async throws -> Components.Schemas.PlayCompassResponse {
        record(.playCompass)
        throw Product22Error.notFound
    }

    func recordPlayCompassEvent(
        _ request: Components.Schemas.PlayCompassEventRequest, authorization: Product22Authorization
    ) async throws {
        record(.playCompassEvent)
        try mutationResult.get()
    }

    func fetchMonthlyReplay(month: String, timezone: String) async throws -> Components.Schemas.MonthlyReplay {
        record(.monthlyReplay(month: month))
        throw Product22Error.notFound
    }
}

// MARK: - Decoding helpers
//
// The mock hands back generated types, and the only supported way to build one
// is to decode it — hand-constructing a contract type in a test would be the
// same guesswork the generated client exists to prevent.

enum Product22Decode {

    static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            return try RFC3339DateTranscoder().decode(raw)
        }
        return try decoder.decode(type, from: Data(json.utf8))
    }

    /// Unwraps the `{"success":true,"data":…}` envelope the contract uses.
    static func envelopeData<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try decode(Envelope<T>.self, from: json).data
    }

    private struct Envelope<Payload: Decodable>: Decodable {
        let data: Payload
    }
}
