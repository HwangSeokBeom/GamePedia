import Foundation

// MARK: - CatalogGameID
//
// The identifier of a game in the Product 2.2 canonical catalog.
//
// This is a UUID and it is NOT the same thing as `Game.id`, which is an IGDB
// integer the rest of the app has used since before the catalog existed. The
// two identifier spaces name different rows in different systems and the
// contract provides no mapping between them, so this type deliberately offers
// no way to produce or consume an `Int`:
//
//   - no `init(_ int: Int)`, no `intValue`, no `RawRepresentable where
//     RawValue == Int`, no `ExpressibleByIntegerLiteral`
//   - no `Codable` conformance that could round-trip through a number
//
// If a screen needs to move between a catalog game and a legacy IGDB game, it
// must carry an explicit link the server supplied (see
// `TodayFriendActivityItem.legacyIdentity`, the only place the contract
// provides one). Anything else would be an invention.

struct CatalogGameID: Hashable, Sendable, CustomStringConvertible {

    let uuid: UUID

    init(uuid: UUID) {
        self.uuid = uuid
    }

    /// Fails rather than substituting a placeholder: an unparseable catalog id
    /// is a contract violation, and a request built on a made-up UUID would
    /// silently address the wrong row.
    init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.uuid = uuid
    }

    /// The wire form. Lowercased because that is what the server emits and
    /// what its indexes are built on.
    var wireValue: String {
        uuid.uuidString.lowercased()
    }

    var description: String { wireValue }
}

// MARK: - Other catalog-space identifiers
//
// Same reasoning: distinct types so one cannot be passed where another is
// expected, and no integer bridge on any of them.

struct RegionalReleaseID: Hashable, Sendable {
    let uuid: UUID

    init(uuid: UUID) { self.uuid = uuid }

    init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.uuid = uuid
    }

    var wireValue: String { uuid.uuidString.lowercased() }
}

struct PlaySessionID: Hashable, Sendable {
    let uuid: UUID

    init(uuid: UUID) { self.uuid = uuid }

    init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.uuid = uuid
    }

    var wireValue: String { uuid.uuidString.lowercased() }
}

struct CatalogSubmissionID: Hashable, Sendable {
    let uuid: UUID

    init(uuid: UUID) { self.uuid = uuid }

    init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.uuid = uuid
    }

    var wireValue: String { uuid.uuidString.lowercased() }
}

// MARK: - LegacyGameIdentity
//
// The only bridge the contract offers between the canonical catalog and the
// app's pre-existing IGDB/Steam identifiers. Every field is optional because
// the server sends it that way — a Steam sync activity, for instance, carries
// no canonical id at all.
//
// `igdbGameId` arrives as a string. It is exposed as a string and converted to
// `Game.id`'s `Int` only through `legacyGameID`, which is the single, named,
// testable place that conversion happens. There is no path from
// `CatalogGameID` to this type: a catalog UUID never becomes an IGDB integer.

struct LegacyGameIdentity: Hashable, Sendable {
    enum Source: String, Hashable, Sendable {
        case steam = "STEAM"
        case igdb = "IGDB"
    }

    let source: Source?
    let externalGameID: String?
    let igdbGameID: String?

    /// The legacy `Game.id` this identity names, when the server supplied one
    /// that is actually an integer. Nil otherwise — callers must then treat
    /// the row as having no legacy route rather than fabricating one.
    var legacyGameID: Int? {
        guard let igdbGameID, let value = Int(igdbGameID) else { return nil }
        return value
    }
}
