import Foundation
import GamePediaProduct22API

// MARK: - ArticleMapper

enum ArticleMapper {

    // MARK: Card (Today feed)

    static func card(from dto: Components.Schemas.ArticleSummary) -> ArticleCard? {
        guard let status = ArticleStatus(rawValue: dto.status.rawValue) else { return nil }
        return ArticleCard(
            slug: dto.slug,
            status: status,
            locale: dto.locale,
            headline: dto.headline,
            excerpt: dto.excerpt,
            publishedAt: dto.publishedAt,
            correctedAt: dto.correctedAt,
            heroImage: heroImage(from: dto.heroImage),
            heroImageWithheldReason: dto.heroImageWithheldReason,
            relatedGames: dto.relatedGames.compactMap(relatedGame(from:)),
            sourceCount: dto.sourceCount
        )
    }

    // MARK: Full article

    static func article(from dto: Components.Schemas.PublicArticle) throws -> Article {
        guard let status = ArticleStatus(rawValue: dto.status.rawValue) else {
            throw Product22Error.decoding(message: "unsupported article status")
        }
        // The contract pins bodyFormat to commonmark-no-html. If a future
        // server ever sends something else, refuse rather than render an
        // unknown format through a Markdown parser.
        guard dto.bodyFormat.rawValue == Article.supportedBodyFormat else {
            throw Product22Error.decoding(message: "unsupported article body format")
        }
        guard let revisionStatus = ArticleStatus(rawValue: dto.revision.status.rawValue) else {
            throw Product22Error.decoding(message: "unsupported article revision status")
        }

        return Article(
            slug: dto.slug,
            status: status,
            locale: dto.locale,
            headline: dto.headline,
            excerpt: dto.excerpt,
            bodyMarkdown: dto.bodyMarkdown,
            publishedAt: dto.publishedAt,
            correctedAt: dto.correctedAt,
            revision: Article.Revision(
                number: dto.revision.revisionNumber,
                status: revisionStatus,
                changeNote: dto.revision.changeNote,
                createdAt: dto.revision.createdAt
            ),
            heroImageWithheldReason: dto.heroImageWithheldReason,
            sources: dto.sources.compactMap(source(from:))
        )
    }

    // MARK: Pieces

    /// A hero survives only if it is https and its rights status is one the
    /// contract clears for public use. Anything else becomes nil, and the UI
    /// falls back to a placeholder plus the withheld reason.
    private static func heroImage(
        from dto: Components.Schemas.ArticleHeroImage?
    ) -> ArticleHeroImage? {
        guard let dto,
              let url = Product22CommonMapper.httpsURL(dto.url),
              let rights = ArticleHeroImage.RightsStatus(rawValue: dto.rightsStatus.rawValue) else {
            return nil
        }
        return ArticleHeroImage(url: url, rightsStatus: rights, attribution: dto.attribution)
    }

    private static func relatedGame(
        from dto: Components.Schemas.ArticleRelatedGame
    ) -> ArticleRelatedGame? {
        guard let id = Product22CommonMapper.catalogGameID(dto.catalogGameId),
              let relation = ArticleRelatedGame.Relation(rawValue: dto.relation.rawValue) else {
            return nil
        }
        return ArticleRelatedGame(catalogGameID: id, relation: relation)
    }

    private static func source(
        from dto: Components.Schemas.PublicArticle.sourcesPayloadPayload
    ) -> ArticleSource? {
        guard let kind = ArticleSource.Kind(rawValue: dto.sourceType.rawValue),
              let url = Product22CommonMapper.anyURL(dto.sourceUrl) else {
            return nil
        }
        return ArticleSource(
            kind: kind,
            publisherKey: dto.publisherKey,
            headline: dto.headline,
            excerpt: dto.excerpt,
            url: url,
            publishedAt: dto.publishedAt,
            fetchedAt: dto.fetchedAt,
            provenance: Product22CommonMapper.provenance(dto.provenance)
        )
    }
}
