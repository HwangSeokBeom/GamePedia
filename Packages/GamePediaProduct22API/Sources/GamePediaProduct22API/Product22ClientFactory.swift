import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

// MARK: - Product22ClientFactory
//
// The only supported way to construct the generated Product 2.2 client.
//
// The contract document declares a single relative server (`/`, "same-origin
// deployment root"), so a client built from the generated `Servers` helper
// would have no host at all. Every caller therefore has to supply the
// deployment root explicitly — in the app that is `AppConfig.coreBaseURL`.
//
// Authentication is deliberately NOT handled here. Product 2.2 mixes public
// and authenticated operations, and the app's account-bound credential rules
// (capture an account expectation at gesture time, bind it atomically just
// before transmission, never attach a token a guest gesture did not own)
// live in the app's session layer. This factory takes whatever middlewares
// the caller hands it and stays ignorant of credentials.

public enum Product22ClientFactory {

    /// Contract provenance, compiled in so a test can assert the shipped
    /// document is the one the server team published rather than a copy that
    /// drifted. See PROVENANCE.md.
    public enum Contract {
        /// SHA-256 of `Sources/GamePediaProduct22API/openapi.json`.
        public static let openAPISHA256 =
            "c0c5c0287879b4139306d59ef4951afc2d81d409ba34f24bdc7233e3c0612e27"
        /// Exact GamePediaCoreServer commit the document was taken from.
        public static let serverHead = "ce083aa9d873c4f9338c0f926cc2cea647c455bf"
        /// Path of the document inside that server checkout.
        public static let serverPath = "openapi/product-2.2.openapi.json"
        /// `info.version` of the contract document.
        public static let productVersion = "2.2.0"
        /// Every operationId the contract declares, in document order.
        public static let operationIDs: [String] = [
            "searchCatalogGames",
            "getCatalogGame",
            "previewCatalogSubmission",
            "confirmCatalogSubmission",
            "getCatalogSubmission",
            "submitCatalogCorrections",
            "followCatalogGame",
            "unfollowCatalogGame",
            "listPlaySessions",
            "createPlaySession",
            "updatePlaySession",
            "deletePlaySession",
            "getPlayCalendar",
            "getGameDna",
            "recommendPlayCompass",
            "recordPlayCompassEvent",
            "getMonthlyReplay",
            "getTodayFeed",
            "getArticle",
            "listEditorialArticles",
            "createEditorialArticle",
            "updateEditorialArticle",
            "publishEditorialArticle",
            "retractEditorialArticle",
            "getProductConfig",
            "submitProductEvents"
        ]
    }

    /// Runtime configuration every Product 2.2 client must use.
    ///
    /// The only deviation from the runtime defaults is the date transcoder,
    /// and it is not optional: GamePediaCoreServer serialises every timestamp
    /// with JavaScript's `Date.prototype.toISOString()`, which always emits
    /// milliseconds (`2026-07-30T09:00:00.000Z`). The runtime's stock
    /// `.iso8601` transcoder does not set `.withFractionalSeconds`, so it
    /// rejects that — meaning a stock client fails to decode *every* Product
    /// 2.2 response that carries a date. See `RFC3339DateTranscoder`.
    public static let configuration = Configuration(
        dateTranscoder: RFC3339DateTranscoder()
    )

    /// Builds a client against `baseURL` using URLSession transport.
    ///
    /// - Parameters:
    ///   - baseURL: deployment root, e.g. `AppConfig.coreBaseURL`.
    ///   - middlewares: applied in order; the app injects its authorization
    ///     middleware here.
    ///   - session: overridable so tests can install a `URLProtocol` stub and
    ///     exercise the real generated operations end to end.
    public static func makeClient(
        baseURL: URL,
        middlewares: [any ClientMiddleware] = [],
        session: URLSession = .shared
    ) -> Client {
        Client(
            serverURL: baseURL,
            configuration: configuration,
            transport: URLSessionTransport(
                configuration: .init(session: session)
            ),
            middlewares: middlewares
        )
    }

    /// Builds a client on an arbitrary transport. Used by tests that want a
    /// fully deterministic transport rather than a URL loading system stub.
    public static func makeClient(
        baseURL: URL,
        transport: any ClientTransport,
        middlewares: [any ClientMiddleware] = []
    ) -> Client {
        Client(
            serverURL: baseURL,
            configuration: configuration,
            transport: transport,
            middlewares: middlewares
        )
    }
}

// MARK: - RFC3339DateTranscoder

/// Reads any RFC 3339 timestamp the contract permits, with or without
/// fractional seconds, and writes the millisecond form the server itself uses.
///
/// `format: date-time` in the contract is RFC 3339, which makes the fractional
/// part optional. A transcoder that accepts only one of the two forms is
/// therefore stricter than the contract, and in this deployment the stricter
/// reading is also the wrong one — the server always sends milliseconds.
/// Accepting both is the only reading that cannot break on a server-side
/// serialisation change.
public struct RFC3339DateTranscoder: DateTranscoder, Sendable {

    private static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let withoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    public init() {}

    public func decode(_ string: String) throws -> Date {
        if let date = Self.withFractionalSeconds.date(from: string) { return date }
        if let date = Self.withoutFractionalSeconds.date(from: string) { return date }
        throw DecodingError.dataCorrupted(
            .init(
                codingPath: [],
                debugDescription: "Expected an RFC 3339 date-time, got \"\(string)\""
            )
        )
    }

    /// Writes the same shape the server emits, so a value that round-trips
    /// through the client is byte-identical to one that never left the server.
    public func encode(_ date: Date) throws -> String {
        Self.withFractionalSeconds.string(from: date)
    }
}
