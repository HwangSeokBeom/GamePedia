import Foundation
import GamePediaProduct22API
import OpenAPIRuntime

// MARK: - QuickAddMapper

enum QuickAddMapper {

    // MARK: Domain → request

    static func previewRequest(
        from input: QuickAddInput
    ) -> Components.Schemas.SubmissionPreviewRequest {
        Components.Schemas.SubmissionPreviewRequest(
            inputType: Components.Schemas.SubmissionPreviewRequest.inputTypePayload(
                rawValue: input.kind.rawValue
            ) ?? .TEXT,
            // The raw input crosses the network exactly once, here. The server
            // keeps only its SHA-256 fingerprint and the fields the user
            // confirms; the client keeps nothing.
            input: input.rawInput,
            locale: input.locale,
            regionCode: input.regionCode,
            platformHint: input.platformHint
        )
    }

    static func confirmRequest(
        from confirmation: QuickAddConfirmation
    ) -> Components.Schemas.SubmissionConfirmRequest {
        switch confirmation {
        case .linkExisting(let id, let requestPublicReview):
            // selectedCatalogGameId and confirmedFields are mutually
            // exclusive, so linking sends only the id.
            return Components.Schemas.SubmissionConfirmRequest(
                selectedCatalogGameId: id.wireValue,
                confirmedFields: nil,
                requestPublicReview: requestPublicReview
            )

        case .confirmNewGame(let fields, let requestPublicReview):
            return Components.Schemas.SubmissionConfirmRequest(
                selectedCatalogGameId: nil,
                confirmedFields: try? confirmedFields(fields),
                requestPublicReview: requestPublicReview
            )
        }
    }

    private static func confirmedFields(
        _ fields: QuickAddConfirmedFields
    ) throws -> OpenAPIObjectContainer {
        var raw: [String: (any Sendable)?] = [:]
        if let title = fields.originalTitle { raw["originalTitle"] = title }
        if let developer = fields.developerName { raw["developerName"] = developer }
        if let publisher = fields.publisherName { raw["publisherName"] = publisher }
        if !fields.platforms.isEmpty { raw["platforms"] = fields.platforms }
        return try OpenAPIObjectContainer(unvalidatedValue: raw)
    }

    // MARK: Response → domain

    static func preview(
        from dto: Components.Schemas.SubmissionPreviewResponse
    ) -> QuickAddPreview {
        QuickAddPreview(
            submissionID: CatalogSubmissionID(uuidString: dto.submissionId)
                ?? CatalogSubmissionID(uuid: UUID()),
            createdAt: dto.createdAt,
            expiresAt: dto.expiresAt,
            existingCandidates: dto.existingCandidates.compactMap(candidate(from:)),
            newGameDraft: QuickAddPreview.NewGameDraft(
                originalTitle: dto.newGameDraft.originalTitle,
                requiresTitleConfirmation: dto.newGameDraft.requiresTitleConfirmation
            ),
            fieldProvenance: dto.fieldProvenance.map(evidence(from:)),
            clarifyingQuestion: dto.clarifyingQuestions.first,
            resolution: QuickAddPreview.Resolution(
                stage: QuickAddPreview.Resolution.Stage(rawValue: dto.resolution.stage.rawValue)
                    ?? .manualDraft,
                aiUsed: dto.resolution.aiUsed,
                aiFallbackUsed: dto.resolution.aiFallbackUsed,
                degradeReason: dto.resolution.degradeReason
            ),
            personalRegistrationAvailable: dto.personalRegistrationAvailable
        )
    }

    private static func candidate(
        from dto: Components.Schemas.SubmissionPreviewResponse.existingCandidatesPayloadPayload
    ) -> QuickAddCandidate? {
        guard let summary = CatalogMapper.summary(from: dto.value1) else { return nil }
        return QuickAddCandidate(
            game: summary,
            matchReasons: dto.value2.matchReasonCodes.compactMap {
                QuickAddCandidate.MatchReason(rawValue: $0.rawValue)
            },
            matchConfidence: dto.value2.matchConfidence
        )
    }

    private static func evidence(
        from dto: Components.Schemas.GameFieldEvidence
    ) -> CatalogFieldEvidence {
        CatalogFieldEvidence(
            fieldPath: dto.fieldPath,
            provenance: Product22CommonMapper.provenance(dto.provenance),
            confidence: dto.confidence,
            sourceType: dto.sourceType,
            sourceURL: Product22CommonMapper.httpsURL(dto.sourceUrl),
            observedAt: dto.observedAt
        )
    }
}
