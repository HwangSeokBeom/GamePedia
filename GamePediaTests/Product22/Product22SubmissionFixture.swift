import Foundation
import GamePediaProduct22API
@testable import GamePedia

// MARK: - Product22SubmissionFixture
//
// Wire-shaped JSON for the four operations the contract newly typed, decoded
// through the generated types. Nothing here hand-builds a contract value.

enum Product22SubmissionFixture {

    static let submissionID = "c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f"

    // MARK: Confirm

    static func confirmJSON(
        status: String = "PERSONAL_CONFIRMED",
        catalogGameId: String? = Product22Fixture.gameA,
        createdNewGame: Bool = true,
        idempotentReplay: Bool = false,
        publicReviewStatus: String = "PRIVATE",
        identityConflict: String = "null"
    ) -> String {
        let gameJSON = catalogGameId.map { "\"\($0)\"" } ?? "null"
        return """
        {"success":true,"data":{
          "submissionId":"\(submissionID)",
          "status":"\(status)",
          "catalogGameId":\(gameJSON),
          "createdNewGame":\(createdNewGame),
          "idempotentReplay":\(idempotentReplay),
          "publicReviewStatus":"\(publicReviewStatus)",
          "identityConflict":\(identityConflict)}}
        """
    }

    static func identityConflictJSON(existing: String = Product22Fixture.gameB) -> String {
        """
        {"provider":"APPLE_APP_STORE","existingCatalogGameId":"\(existing)",
         "reasonCode":"verified_identity_already_exists"}
        """
    }

    static func confirmDTO(
        status: String = "PERSONAL_CONFIRMED",
        catalogGameId: String? = Product22Fixture.gameA,
        createdNewGame: Bool = true,
        idempotentReplay: Bool = false,
        publicReviewStatus: String = "PRIVATE",
        identityConflict: String = "null"
    ) throws -> Components.Schemas.SubmissionConfirmResult {
        try Product22Decode.envelopeData(
            Components.Schemas.SubmissionConfirmResult.self,
            from: confirmJSON(
                status: status,
                catalogGameId: catalogGameId,
                createdNewGame: createdNewGame,
                idempotentReplay: idempotentReplay,
                publicReviewStatus: publicReviewStatus,
                identityConflict: identityConflict
            )
        )
    }

    /// A domain-level default for stubs that do not care about the details.
    static func confirmResult(
        catalogGameID: String? = Product22Fixture.gameA,
        createdNewGame: Bool = true,
        idempotentReplay: Bool = false,
        publicationStatus: CatalogPublicationStatus = .privateEntry,
        identityConflict: SubmissionIdentityConflict? = nil
    ) -> SubmissionConfirmResult {
        SubmissionConfirmResult(
            submissionID: CatalogSubmissionID(uuidString: submissionID)!,
            status: .personalConfirmed,
            catalogGameID: catalogGameID.flatMap { CatalogGameID(uuidString: $0) },
            createdNewGame: createdNewGame,
            isIdempotentReplay: idempotentReplay,
            publicationStatus: publicationStatus,
            identityConflict: identityConflict
        )
    }

    // MARK: State

    /// `draft` and `candidateSummary` are injected raw so a test can exercise
    /// a legacy row that predates a field.
    static func stateJSON(
        status: String = "PERSONAL_CONFIRMED",
        draftReadable: Bool = true,
        draft: String? = nil,
        candidateSummary: String = "null",
        catalogGameId: String? = Product22Fixture.gameA,
        expired: Bool = false,
        clarifyingQuestions: String = "[]"
    ) -> String {
        let gameJSON = catalogGameId.map { "\"\($0)\"" } ?? "null"
        return """
        {"success":true,"data":{
          "submissionId":"\(submissionID)",
          "status":"\(status)",
          "inputType":"TEXT",
          "locale":"ko",
          "regionCode":"KR",
          "platformHint":null,
          "newGameDraft":\(draft ?? defaultDraftJSON),
          "draftReadable":\(draftReadable),
          "candidateSummary":\(candidateSummary),
          "clarifyingQuestions":\(clarifyingQuestions),
          "aiFallbackUsed":false,
          "catalogGameId":\(gameJSON),
          "publicReviewStatus":"PRIVATE",
          "expiresAt":"2026-07-31T10:00:00.000Z",
          "expired":\(expired),
          "createdAt":"2026-07-31T09:00:00.000Z",
          "updatedAt":"2026-07-31T09:05:00.000Z"}}
        """
    }

    static let defaultDraftJSON = """
    {"originalTitle":"원신","requiresTitleConfirmation":false,
     "developerName":"miHoYo","publisherName":null,"firstReleaseDate":"2020-09-28",
     "genres":["RPG"],"platforms":["iOS","Android"],
     "supportsSinglePlayer":true,"supportsMultiplayer":true,"typicalSessionMinutes":45,
     "localizations":[{"kind":"ALIAS","languageCode":"en","regionCode":null,"title":"Genshin Impact"}],
     "regionalReleases":[{"countryCode":"KR","languageCode":"ko","platform":"iOS",
                          "operatorName":null,"serverRegion":null,"releaseDate":null,
                          "shutdownDate":null,"serviceStatus":"LIVE"}],
     "identities":[{"provider":"APPLE_APP_STORE","externalId":"1517783697","regionKey":"GLOBAL"}],
     "fieldProvenance":[{"fieldPath":"originalTitle","provenance":"AI_INFERRED","confidence":0.7}]}
    """

    static func stateDTO(
        status: String = "PERSONAL_CONFIRMED",
        draftReadable: Bool = true,
        draft: String? = nil,
        candidateSummary: String = "null",
        catalogGameId: String? = Product22Fixture.gameA,
        expired: Bool = false,
        clarifyingQuestions: String = "[]"
    ) throws -> Components.Schemas.SubmissionState {
        try Product22Decode.envelopeData(
            Components.Schemas.SubmissionState.self,
            from: stateJSON(
                status: status,
                draftReadable: draftReadable,
                draft: draft,
                candidateSummary: candidateSummary,
                catalogGameId: catalogGameId,
                expired: expired,
                clarifyingQuestions: clarifyingQuestions
            )
        )
    }

    // MARK: Paged lists

    static func searchJSON(
        games: String = "[]",
        nextCursor: String? = nil,
        matchedBy: String = "ranked",
        limit: Int = 50,
        totalScanned: Int = 0
    ) -> String {
        let cursorJSON = nextCursor.map { "\"\($0)\"" } ?? "null"
        return """
        {"success":true,"data":{"games":\(games),
          "meta":{"limit":\(limit),"nextCursor":\(cursorJSON),
                  "matchedBy":"\(matchedBy)","totalScanned":\(totalScanned)}}}
        """
    }

    static func catalogGameJSON(id: String, title: String) -> String {
        """
        {"catalogGameId":"\(id)","originalTitle":"\(title)","slug":null,
         "developerName":null,"publisherName":null,"firstReleaseDate":null,
         "genres":[],"platforms":["PC"],"publicationStatus":"PUBLISHED",
         "titleProvenance":"PROVIDER_VERIFIED","identities":[]}
        """
    }

    static func searchDTO(
        games: String = "[]",
        nextCursor: String? = nil,
        matchedBy: String = "ranked"
    ) throws -> Components.Schemas.CatalogSearchResult {
        try Product22Decode.envelopeData(
            Components.Schemas.CatalogSearchResult.self,
            from: searchJSON(games: games, nextCursor: nextCursor, matchedBy: matchedBy)
        )
    }

    static func playSessionListJSON(sessions: String = "[]", nextCursor: String? = nil) -> String {
        let cursorJSON = nextCursor.map { "\"\($0)\"" } ?? "null"
        return """
        {"success":true,"data":{"playSessions":\(sessions),
          "meta":{"limit":50,"nextCursor":\(cursorJSON)}}}
        """
    }

    static func playSessionListDTO(
        sessions: String = "[]", nextCursor: String? = nil
    ) throws -> Components.Schemas.PlaySessionListResult {
        try Product22Decode.envelopeData(
            Components.Schemas.PlaySessionListResult.self,
            from: playSessionListJSON(sessions: sessions, nextCursor: nextCursor)
        )
    }
}
