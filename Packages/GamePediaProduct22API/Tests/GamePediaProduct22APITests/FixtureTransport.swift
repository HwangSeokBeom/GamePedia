import Foundation
import HTTPTypes
import OpenAPIRuntime

// MARK: - FixtureTransport
//
// A deterministic `ClientTransport`. Tests that use it exercise the REAL
// generated operation — request construction, path/query building, response
// decoding — and only replace the bytes on the wire. A test that decoded a
// fixture with `JSONDecoder` directly would prove nothing about the client.

final class FixtureTransport: ClientTransport, Sendable {

    struct Recorded: Sendable {
        let request: HTTPRequest
        let bodyData: Data?
        let operationID: String
        let baseURL: URL
    }

    /// Recording lives in an actor so `send` never blocks a lock from an async
    /// context — that is an error in Swift 6 and a warning here, and this
    /// package must build warning-free.
    private actor Log {
        private(set) var entries: [Recorded] = []
        func append(_ entry: Recorded) { entries.append(entry) }
    }

    /// Responses keyed by operationID. A missing key means the test did not
    /// expect that operation to be called, which is itself worth surfacing.
    private let responses: [String: (status: Int, body: Data)]
    private let log = Log()

    var recorded: [Recorded] {
        get async { await log.entries }
    }

    init(responses: [String: (status: Int, body: Data)]) {
        self.responses = responses
    }

    convenience init(operationID: String, status: Int = 200, json: Data) {
        self.init(responses: [operationID: (status, json)])
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var collected: Data?
        if let body {
            collected = try await Data(collecting: body, upTo: 4 * 1024 * 1024)
        }
        await log.append(
            Recorded(request: request, bodyData: collected, operationID: operationID, baseURL: baseURL)
        )

        guard let canned = responses[operationID] else {
            throw FixtureTransportError.noStubbedResponse(operationID: operationID)
        }
        var response = HTTPResponse(status: .init(code: canned.status))
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(canned.body))
    }
}

enum FixtureTransportError: Error, CustomStringConvertible {
    case noStubbedResponse(operationID: String)

    var description: String {
        switch self {
        case .noStubbedResponse(let operationID):
            return "No stubbed response for operation '\(operationID)'"
        }
    }
}

// MARK: - Fixture loading

enum Fixture {
    /// Directory holding the checked-in contract fixtures.
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: directory.appendingPathComponent(name))
    }

    /// The OpenAPI document that the build plugin generates from.
    static var openAPIDocument: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // GamePediaProduct22APITests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // package root
            .appendingPathComponent("Sources/GamePediaProduct22API/openapi.json")
    }
}
