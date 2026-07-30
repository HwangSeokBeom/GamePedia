import Foundation
import GamePediaProduct22API

// MARK: - CatalogMapper

enum CatalogMapper {

    static func summary(
        from dto: Components.Schemas.CatalogGameSummary
    ) -> CatalogGameSummary? {
        guard let id = Product22CommonMapper.catalogGameID(dto.catalogGameId),
              let status = Product22CommonMapper.publicationStatus(dto.publicationStatus) else {
            return nil
        }
        return CatalogGameSummary(
            id: id,
            originalTitle: dto.originalTitle,
            slug: dto.slug,
            developerName: dto.developerName,
            publisherName: dto.publisherName,
            firstReleaseDate: dto.firstReleaseDate,
            genres: dto.genres ?? [],
            platforms: dto.platforms ?? [],
            publicationStatus: status,
            titleProvenance: Product22CommonMapper.provenance(dto.titleProvenance),
            identities: dto.identities.compactMap(identity(from:))
        )
    }

    static func detail(
        from dto: Components.Schemas.CatalogGameDetail
    ) -> CatalogGameDetail? {
        guard let summary = summary(from: dto.value1) else { return nil }
        let extra = dto.value2
        return CatalogGameDetail(
            summary: summary,
            steamTags: extra.steamTags ?? [],
            supportsSinglePlayer: extra.supportsSinglePlayer,
            supportsMultiplayer: extra.supportsMultiplayer,
            typicalSessionMinutes: extra.typicalSessionMinutes,
            localizations: extra.localizations.compactMap(localization(from:)),
            regionalReleases: extra.regionalReleases.compactMap(regionalRelease(from:)),
            assets: extra.assets.compactMap(asset(from:)),
            fieldEvidence: extra.fieldEvidence.map(fieldEvidence(from:)),
            resolvedFromMerge: extra.resolvedFromMerge ?? false,
            isFollowedByMe: extra.isFollowedByMe ?? false
        )
    }

    // MARK: Pieces

    private static func identity(
        from dto: Components.Schemas.GameExternalIdentity
    ) -> CatalogExternalIdentity? {
        guard let provider = Product22CommonMapper.identityProvider(dto.provider) else { return nil }
        return CatalogExternalIdentity(
            provider: provider,
            externalID: dto.externalId,
            regionKey: dto.regionKey,
            provenance: Product22CommonMapper.provenance(dto.provenance),
            confidence: dto.confidence
        )
    }

    private static func localization(
        from dto: Components.Schemas.GameLocalization
    ) -> CatalogLocalization? {
        guard let kind = CatalogLocalization.Kind(rawValue: dto.kind.rawValue) else { return nil }
        return CatalogLocalization(
            kind: kind,
            languageCode: dto.languageCode,
            regionCode: dto.regionCode,
            title: dto.title,
            provenance: Product22CommonMapper.provenance(dto.provenance)
        )
    }

    private static func regionalRelease(
        from dto: Components.Schemas.RegionalRelease
    ) -> CatalogRegionalRelease? {
        guard let id = RegionalReleaseID(uuidString: dto.id),
              let status = Product22CommonMapper.serviceStatus(dto.serviceStatus) else {
            return nil
        }
        return CatalogRegionalRelease(
            id: id,
            countryCode: dto.countryCode,
            languageCode: dto.languageCode,
            platform: dto.platform,
            operatorName: dto.operatorName,
            serverRegion: dto.serverRegion,
            releaseDate: dto.releaseDate,
            shutdownDate: dto.shutdownDate,
            serviceStatus: status,
            provenance: Product22CommonMapper.provenance(dto.provenance)
        )
    }

    /// An asset with an unresolved or restricted rights status is dropped
    /// entirely rather than carried with a flag, so no view can render it by
    /// forgetting to check. Non-https assets are dropped for the same reason.
    private static func asset(from dto: Components.Schemas.GameAsset) -> CatalogAsset? {
        guard let kind = CatalogAsset.Kind(rawValue: dto.kind.rawValue),
              let url = Product22CommonMapper.httpsURL(dto.url) else {
            return nil
        }
        return CatalogAsset(
            kind: kind,
            url: url,
            provenance: Product22CommonMapper.provenance(dto.provenance),
            attribution: dto.attribution,
            usableAsPublicHero: dto.usableAsPublicHero
        )
    }

    private static func fieldEvidence(
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
