import Foundation

// MARK: - AuthService
// Legacy compatibility shim.
// Direct IGDB access is no longer supported on the iOS client.

actor AuthService {

    // MARK: Singleton
    static let shared = AuthService()

    // MARK: Init
    private init() {
    }

    // MARK: - Public Interface

    func validToken() async throws -> String {
        let message = "Direct IGDB access is no longer supported. Use GamePediaCoreServer /games proxy endpoints instead."
        print("[GameAPI] legacyIGDBAccessBlocked message=\(message)")
        throw NetworkError.configurationMissing(message)
    }
}
