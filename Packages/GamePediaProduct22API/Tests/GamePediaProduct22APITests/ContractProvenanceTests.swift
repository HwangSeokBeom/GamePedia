import CryptoKit
import Foundation
import XCTest
@testable import GamePediaProduct22API

// MARK: - ContractProvenanceTests
//
// Required gate 1: the OpenAPI document the client is generated from must be
// the exact document the server published, and the provenance recorded next to
// it must agree.

final class ContractProvenanceTests: XCTestCase {

    func testShippedOpenAPIDocumentMatchesPublishedSHA256() throws {
        let data = try Data(contentsOf: Fixture.openAPIDocument)
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()

        XCTAssertEqual(
            hex,
            Product22ClientFactory.Contract.openAPISHA256,
            """
            The bundled openapi.json is not the document this client was \
            verified against. Re-sync it from GamePediaCoreServer \
            \(Product22ClientFactory.Contract.serverHead):\
            \(Product22ClientFactory.Contract.serverPath) and update \
            PROVENANCE.md — do not adjust the expected hash to match a copy \
            of unknown origin.
            """
        )
    }

    func testProvenanceFileRecordsTheSameServerHeadAndHash() throws {
        let provenance = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PROVENANCE.md")
        let text = try String(contentsOf: provenance, encoding: .utf8)

        XCTAssertTrue(
            text.contains(Product22ClientFactory.Contract.serverHead),
            "PROVENANCE.md does not record the server HEAD the client claims"
        )
        XCTAssertTrue(
            text.contains(Product22ClientFactory.Contract.openAPISHA256),
            "PROVENANCE.md does not record the contract SHA-256 the client claims"
        )
    }

    func testDocumentDeclaresAllTwentySixOperations() throws {
        let data = try Data(contentsOf: Fixture.openAPIDocument)
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let paths = try XCTUnwrap(root["paths"] as? [String: Any])

        let methods: Set<String> = ["get", "post", "put", "patch", "delete"]
        var declared: Set<String> = []
        for (_, item) in paths {
            guard let item = item as? [String: Any] else { continue }
            for (method, operation) in item where methods.contains(method) {
                guard let operation = operation as? [String: Any],
                      let id = operation["operationId"] as? String else { continue }
                declared.insert(id)
            }
        }

        XCTAssertEqual(declared.count, 26, "contract operation count changed")
        XCTAssertEqual(
            declared,
            Set(Product22ClientFactory.Contract.operationIDs),
            "the contract's operation set no longer matches the compiled-in list"
        )
    }

    /// Every operation the app is allowed to call must exist as a method on the
    /// generated `APIProtocol`. This is a compile-time assertion written as a
    /// test so a lost operation fails the build with an obvious message.
    func testGeneratedClientExposesEveryUserFacingOperation() {
        let client: any APIProtocol = Product22ClientFactory.makeClient(
            baseURL: URL(string: "https://example.invalid")!,
            transport: FixtureTransport(responses: [:])
        )
        // Referencing the methods is the assertion; calling them is not needed.
        let surface: [Any] = [
            client.searchCatalogGames, client.getCatalogGame,
            client.previewCatalogSubmission, client.confirmCatalogSubmission,
            client.getCatalogSubmission, client.submitCatalogCorrections,
            client.followCatalogGame, client.unfollowCatalogGame,
            client.listPlaySessions, client.createPlaySession,
            client.updatePlaySession, client.deletePlaySession,
            client.getPlayCalendar, client.getGameDna,
            client.recommendPlayCompass, client.recordPlayCompassEvent,
            client.getMonthlyReplay, client.getTodayFeed,
            client.getArticle, client.getProductConfig,
            client.submitProductEvents
        ]
        XCTAssertEqual(surface.count, 21, "user-facing operation surface changed")
    }
}
