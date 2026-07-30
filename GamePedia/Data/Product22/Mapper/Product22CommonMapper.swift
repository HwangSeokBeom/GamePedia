import Foundation
import GamePediaProduct22API

// MARK: - Product22CommonMapper
//
// Shared conversions from generated contract types to domain values.
//
// Two rules run through every mapper in this directory:
//
//   1. A generated type never escapes. Callers get domain entities.
//   2. A value the app cannot understand is dropped, not guessed. An unknown
//      enum case becomes nil and the item is skipped, rather than being
//      coerced into a neighbouring case that would misinform the reader.

enum Product22CommonMapper {

    static func provenance(_ value: Components.Schemas.CatalogProvenance) -> CatalogProvenance {
        CatalogProvenance(rawValue: value.rawValue) ?? .unknown
    }

    static func serviceStatus(_ value: Components.Schemas.CatalogServiceStatus) -> CatalogServiceStatus? {
        CatalogServiceStatus(rawValue: value.rawValue)
    }

    static func publicationStatus(
        _ value: Components.Schemas.CatalogPublicationStatus
    ) -> CatalogPublicationStatus? {
        CatalogPublicationStatus(rawValue: value.rawValue)
    }

    static func identityProvider(
        _ value: Components.Schemas.CatalogIdentityProvider
    ) -> CatalogIdentityProvider? {
        CatalogIdentityProvider(rawValue: value.rawValue)
    }

    static func catalogGameID(_ value: String) -> CatalogGameID? {
        CatalogGameID(uuidString: value)
    }

    /// Reads a `const` the generator typed as an opaque container. Four Today
    /// sections declare `status` as a single-value const rather than an enum,
    /// so their status arrives this way.
    static func constString(_ container: Product22JSONValue) -> String? {
        Product22JSON.string(container)
    }

    /// Only an absolute https URL is accepted. A source link, a hero image or
    /// an evidence URL that is not https is dropped rather than opened.
    static func httpsURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme?.lowercased() == "https" else {
            return nil
        }
        return url
    }

    /// For values that are displayed but never opened, where a non-https
    /// scheme still needs to be visible to the reader.
    static func anyURL(_ raw: String?) -> URL? {
        guard let raw else { return nil }
        return URL(string: raw)
    }

    static func confidence(_ raw: String) -> PlayIntelligenceConfidence {
        PlayIntelligenceConfidence(rawValue: raw) ?? .low
    }
}
