import Foundation

// MARK: - Product22Feature

/// The eight independent kill switches the contract declares. Each can be
/// turned off without affecting the others or any pre-existing endpoint.
enum Product22Feature: String, CaseIterable, Sendable {
    case openCatalog
    case aiQuickAdd
    case playlog
    case playCompass
    case gameDNA
    case monthlyReplay
    case todayFeed
    case magazine
}

// MARK: - Product22ProductConfig

struct Product22ProductConfig: Equatable, Sendable {

    let dtoVersion: Int
    let productVersion: String
    let generatedAt: Date

    /// True when the server could not read the kill-switch table at all. Every
    /// Product 2.2 endpoint then answers 503 FEATURE_STATE_UNAVAILABLE, so the
    /// client must treat every new feature as off. Pre-existing endpoints —
    /// home, search, reviews, Steam, library — are unaffected and keep working.
    let isDegraded: Bool

    private let enabledFeatures: Set<Product22Feature>

    /// Event codes the server currently accepts, when it named them in a way
    /// this client can read. Nil means "the server did not tell us", not
    /// "none" — see `ProductEventRecorder` for how that is handled.
    let allowedEventCodes: Set<String>?

    init(
        dtoVersion: Int,
        productVersion: String,
        generatedAt: Date,
        isDegraded: Bool,
        enabledFeatures: Set<Product22Feature>,
        allowedEventCodes: Set<String>?
    ) {
        self.dtoVersion = dtoVersion
        self.productVersion = productVersion
        self.generatedAt = generatedAt
        self.isDegraded = isDegraded
        // Fail closed at construction rather than at every call site: a
        // degraded config cannot report any feature as on, no matter what the
        // flags said.
        self.enabledFeatures = isDegraded ? [] : enabledFeatures
        self.allowedEventCodes = allowedEventCodes
    }

    func isEnabled(_ feature: Product22Feature) -> Bool {
        enabledFeatures.contains(feature)
    }

    /// The state the app assumes before it has ever heard from the server, and
    /// the state it falls back to when the cached config has expired and the
    /// refresh failed. Nothing new is offered until the server says otherwise.
    static let failClosed = Product22ProductConfig(
        dtoVersion: 0,
        productVersion: "unknown",
        generatedAt: .distantPast,
        isDegraded: true,
        enabledFeatures: [],
        allowedEventCodes: nil
    )
}
