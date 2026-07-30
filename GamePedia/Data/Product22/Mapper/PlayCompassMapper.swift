import Foundation
import GamePediaProduct22API
import OpenAPIRuntime

// MARK: - PlayCompassMapper

enum PlayCompassMapper {

    // MARK: Response → domain

    static func result(
        from dto: Components.Schemas.PlayCompassResponse
    ) -> PlayCompassResult {
        PlayCompassResult(
            recommendations: dto.recommendations.compactMap(recommendation(from:)),
            confidence: Product22CommonMapper.confidence(dto.confidence.rawValue),
            generatedAt: dto.generatedAt,
            freshness: freshness(dto.dataFreshness),
            emptyReason: dto.emptyReason.flatMap { PlayCompassEmptyReason(rawValue: $0.rawValue) },
            ownedOnly: (dto.ownedOnly.value as? Bool) ?? true,
            requestHash: dto.requestHash
        )
    }

    static func freshness(
        _ dto: Components.Schemas.PlayCompassDataFreshness
    ) -> PlayCompassFreshness {
        PlayCompassFreshness(
            candidatePoolSize: dto.candidatePoolSize,
            freshestLibraryUpdateAt: dto.freshestLibraryUpdateAt,
            playlogSampleSize: dto.playlogSampleSize,
            isStale: dto.stale
        )
    }

    static func recommendation(
        from dto: Components.Schemas.PlayCompassRecommendation
    ) -> PlayCompassRecommendation? {
        guard let id = Product22CommonMapper.catalogGameID(dto.catalogGameId),
              let source = PlayCompassOwnership.Source(rawValue: dto.ownershipEvidence.source.rawValue),
              let libraryStatus = OwnedLibraryStatus(rawValue: dto.ownershipEvidence.libraryStatus.rawValue),
              let basis = PlayCompassSessionBasis(rawValue: dto.estimatedSessionBasis.rawValue) else {
            return nil
        }

        return PlayCompassRecommendation(
            catalogGameID: id,
            title: dto.title,
            rank: dto.rank,
            score: dto.score,
            // Unknown reason codes are dropped: an untranslated server token
            // shown to a reader is noise, not an explanation.
            reasonCodes: dto.reasonCodes.compactMap { PlayCompassReason(rawValue: $0.rawValue) },
            estimatedSessionMinutes: dto.estimatedSessionMinutes,
            estimatedSessionBasis: basis,
            ownership: PlayCompassOwnership(
                source: source,
                externalGameID: dto.ownershipEvidence.externalGameId,
                libraryStatus: libraryStatus,
                provenance: Product22CommonMapper.provenance(dto.ownershipEvidence.provenance),
                playtimeMinutes: dto.ownershipEvidence.playtimeMinutes,
                lastPlayedAt: dto.ownershipEvidence.lastPlayedAt,
                isVerified: dto.ownershipEvidence.ownershipVerified
            )
        )
    }

    // MARK: Domain → request

    static func request(
        from query: PlayCompassQuery
    ) -> Components.Schemas.PlayCompassRequest {
        Components.Schemas.PlayCompassRequest(
            availableMinutes: query.availableMinutes,
            mood: query.mood?.rawValue,
            energy: query.energy.flatMap {
                Components.Schemas.PlayCompassRequest.energyPayload(rawValue: $0.rawValue)
            },
            soloOrParty: query.soloOrParty.flatMap {
                Components.Schemas.PlayCompassRequest.soloOrPartyPayload(rawValue: $0.rawValue)
            },
            continueOrStart: query.continueOrStart.flatMap {
                Components.Schemas.PlayCompassRequest.continueOrStartPayload(rawValue: $0.rawValue)
            },
            availablePlatforms: query.availablePlatforms.isEmpty ? nil : query.availablePlatforms,
            friendUserIds: query.friendUserIDs.isEmpty
                ? nil
                : query.friendUserIDs.map { $0.uuidString.lowercased() }
        )
    }

    static func eventRequest(
        from feedback: PlayCompassFeedback
    ) -> Components.Schemas.PlayCompassEventRequest {
        Components.Schemas.PlayCompassEventRequest(
            catalogGameId: feedback.catalogGameID.wireValue,
            action: Components.Schemas.PlayCompassEventRequest.actionPayload(
                rawValue: feedback.action.rawValue
            ) ?? .SELECTED,
            // The contract caps this at 12.
            reasonCodes: Array(feedback.reasonCodes.prefix(12)).map(\.rawValue),
            // Carrying the round's hash is what lets the server attribute the
            // feedback to the recommendation that produced it.
            requestHash: feedback.requestHash,
            occurredAt: feedback.occurredAt
        )
    }
}
