import Foundation
import GamePediaProduct22API

// MARK: - CatalogSubmissionMapper
//
// Converts the newly typed submission responses into domain values.
//
// Two defensive rules apply throughout, both because the contract says so
// rather than out of caution:
//
//   - `SubmissionCandidateSummary` is stored as JSON and returned without
//     re-validation, so every field inside it is optional. A row written by an
//     earlier revision must still decode, and the mapper never assumes the
//     current writer's shape.
//   - `GameSubmissionStatus` carries six values, two of which this server does
//     not write today. All six map, so a value from a future editorial flow
//     cannot fail the response.

enum CatalogSubmissionMapper {

    // MARK: Confirm

    static func confirmResult(
        from dto: Components.Schemas.SubmissionConfirmResult
    ) throws -> SubmissionConfirmResult {
        guard let submissionID = CatalogSubmissionID(uuidString: dto.submissionId) else {
            throw Product22Error.decoding(message: "confirm result carried an unparseable submissionId")
        }
        guard let publicationStatus = Product22CommonMapper.publicationStatus(dto.publicReviewStatus) else {
            throw Product22Error.decoding(message: "confirm result carried an unknown publication status")
        }
        return SubmissionConfirmResult(
            submissionID: submissionID,
            status: status(from: dto.status),
            // Nullable by contract: null only on an idempotent replay of a
            // submission that never linked a game.
            catalogGameID: dto.catalogGameId.flatMap(Product22CommonMapper.catalogGameID),
            createdNewGame: dto.createdNewGame,
            isIdempotentReplay: dto.idempotentReplay,
            publicationStatus: publicationStatus,
            identityConflict: dto.identityConflict.flatMap(identityConflict(from:))
        )
    }

    private static func identityConflict(
        from dto: Components.Schemas.SubmissionIdentityConflict
    ) -> SubmissionIdentityConflict? {
        guard let provider = Product22CommonMapper.identityProvider(dto.provider),
              let existing = Product22CommonMapper.catalogGameID(dto.existingCatalogGameId) else {
            // An unreadable conflict is dropped rather than surfaced as a
            // half-formed one: the confirmation still succeeded.
            return nil
        }
        return SubmissionIdentityConflict(
            provider: provider,
            existingCatalogGameID: existing,
            reasonCode: dto.reasonCode.rawValue
        )
    }

    // MARK: State

    static func state(
        from dto: Components.Schemas.SubmissionState
    ) throws -> CatalogSubmissionState {
        guard let submissionID = CatalogSubmissionID(uuidString: dto.submissionId) else {
            throw Product22Error.decoding(message: "submission state carried an unparseable submissionId")
        }
        guard let publicationStatus = Product22CommonMapper.publicationStatus(dto.publicReviewStatus) else {
            throw Product22Error.decoding(message: "submission state carried an unknown publication status")
        }
        return CatalogSubmissionState(
            submissionID: submissionID,
            status: status(from: dto.status),
            inputType: CatalogSubmissionInputType(rawValue: dto.inputType.rawValue) ?? .text,
            locale: dto.locale,
            regionCode: dto.regionCode,
            platformHint: dto.platformHint,
            draft: dto.newGameDraft.map(draft(from:)),
            isDraftReadable: dto.draftReadable,
            candidateSummary: dto.candidateSummary.map(candidateSummary(from:)),
            // The contract caps this at one; anything beyond it is ignored
            // rather than concatenated into an unreadable blob.
            clarifyingQuestion: dto.clarifyingQuestions.first,
            aiFallbackUsed: dto.aiFallbackUsed,
            catalogGameID: dto.catalogGameId.flatMap(Product22CommonMapper.catalogGameID),
            publicationStatus: publicationStatus,
            expiresAt: dto.expiresAt,
            // Taken from the server, which evaluated it against its own clock.
            // Re-deriving it locally would disagree across a clock skew.
            isExpired: dto.expired,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    /// Every one of the six contract values maps. A status this server does
    /// not write today still decodes, which is exactly why the contract lists
    /// them.
    static func status(from dto: Components.Schemas.GameSubmissionStatus) -> CatalogSubmissionStatus {
        switch dto {
        case .PREVIEW: return .preview
        case .PERSONAL_CONFIRMED: return .personalConfirmed
        case .PENDING_REVIEW: return .pendingReview
        case .APPROVED: return .approved
        case .REJECTED: return .rejected
        case .EXPIRED: return .expired
        }
    }

    /// Legacy-tolerant: a summary written before a field existed decodes with
    /// that field absent, and the result reports `isEmptyShape` rather than
    /// pretending zero candidates were found.
    static func candidateSummary(
        from dto: Components.Schemas.SubmissionCandidateSummary
    ) -> CatalogSubmissionCandidateSummary {
        CatalogSubmissionCandidateSummary(
            version: dto.version,
            candidateCount: dto.candidateCount,
            catalogGameIDs: (dto.catalogGameIds ?? []).compactMap(Product22CommonMapper.catalogGameID),
            reasonCodes: dto.reasonCodes ?? []
        )
    }

    // MARK: Draft

    static func draft(
        from dto: Components.Schemas.SubmissionGameDraft
    ) -> CatalogSubmissionDraft {
        CatalogSubmissionDraft(
            originalTitle: dto.originalTitle,
            requiresTitleConfirmation: dto.requiresTitleConfirmation,
            developerName: dto.developerName,
            publisherName: dto.publisherName,
            firstReleaseDate: dto.firstReleaseDate,
            genres: dto.genres,
            platforms: dto.platforms,
            supportsSinglePlayer: dto.supportsSinglePlayer,
            supportsMultiplayer: dto.supportsMultiplayer,
            typicalSessionMinutes: dto.typicalSessionMinutes,
            localizations: dto.localizations.compactMap { localization in
                guard let kind = CatalogLocalization.Kind(rawValue: localization.kind.rawValue) else {
                    return nil
                }
                return CatalogSubmissionDraftLocalization(
                    kind: kind,
                    languageCode: localization.languageCode,
                    regionCode: localization.regionCode,
                    title: localization.title
                )
            },
            regionalReleases: dto.regionalReleases.compactMap { release in
                guard let status = Product22CommonMapper.serviceStatus(release.serviceStatus) else {
                    return nil
                }
                return CatalogSubmissionDraftRegionalRelease(
                    countryCode: release.countryCode,
                    languageCode: release.languageCode,
                    platform: release.platform,
                    operatorName: release.operatorName,
                    serverRegion: release.serverRegion,
                    releaseDate: release.releaseDate,
                    shutdownDate: release.shutdownDate,
                    serviceStatus: status
                )
            },
            identities: dto.identities.compactMap { identity in
                guard let provider = Product22CommonMapper.identityProvider(identity.provider) else {
                    return nil
                }
                return CatalogSubmissionDraftIdentity(
                    provider: provider,
                    externalID: identity.externalId,
                    regionKey: identity.regionKey
                )
            },
            fieldProvenance: dto.fieldProvenance.map { evidence in
                CatalogSubmissionDraftProvenance(
                    fieldPath: evidence.fieldPath,
                    provenance: Product22CommonMapper.provenance(evidence.provenance),
                    confidence: evidence.confidence
                )
            }
        )
    }

    // MARK: Paged results

    static func searchPage(
        from data: Components.Schemas.CatalogSearchResult
    ) -> CatalogSearchPageResult {
        CatalogSearchPageResult(
            games: data.games.compactMap(CatalogMapper.summary(from:)),
            // Opaque: passed back verbatim, never parsed.
            nextCursor: data.meta.nextCursor,
            matchedBy: CatalogSearchPageResult.MatchedBy(rawValue: data.meta.matchedBy.rawValue) ?? .ranked,
            limit: data.meta.limit
        )
    }

    static func playSessionPage(
        from data: Components.Schemas.PlaySessionListResult
    ) -> PlaySessionPageResult {
        PlaySessionPageResult(
            sessions: data.playSessions.compactMap(PlaylogMapper.session(from:)),
            nextCursor: data.meta.nextCursor,
            limit: data.meta.limit
        )
    }
}
