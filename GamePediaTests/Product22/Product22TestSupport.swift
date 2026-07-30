import Foundation
import GamePediaProduct22API
import XCTest
@testable import GamePedia

// MARK: - Product22StubURLProtocol
//
// Drives the REAL generated client through the REAL URLSession transport and
// only replaces the bytes on the wire. A test that decoded a fixture with
// JSONDecoder would prove nothing about request construction, the
// Authorization header, path/query building or response decoding — all of
// which are what these tests are actually about.

final class Product22StubURLProtocol: URLProtocol {

    struct Stub {
        let statusCode: Int
        let body: Data
        /// Delays the response so a test can interleave an account change or a
        /// second request before this one lands.
        let delay: TimeInterval

        init(statusCode: Int = 200, body: Data, delay: TimeInterval = 0) {
            self.statusCode = statusCode
            self.body = body
            self.delay = delay
        }
    }

    struct RecordedRequest {
        let url: URL
        let method: String
        let headers: [String: String]
        let body: Data?

        var authorizationHeader: String? {
            headers.first { $0.key.lowercased() == "authorization" }?.value
        }

        var bodyString: String { body.flatMap { String(data: $0, encoding: .utf8) } ?? "" }

        func bodyJSON() -> [String: Any]? {
            guard let body,
                  let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            else { return nil }
            return object
        }
    }

    /// Matched against the request path in insertion order; the first prefix
    /// match wins.
    private nonisolated(unsafe) static var stubs: [(pathContains: String, stub: Stub)] = []
    private nonisolated(unsafe) static var recorded: [RecordedRequest] = []
    private static let lock = NSLock()

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        stubs = []
        recorded = []
    }

    static func stub(pathContains: String, _ stub: Stub) {
        lock.lock(); defer { lock.unlock() }
        stubs.append((pathContains, stub))
    }

    static func stub(pathContains: String, json: String, statusCode: Int = 200, delay: TimeInterval = 0) {
        stub(
            pathContains: pathContains,
            Stub(statusCode: statusCode, body: Data(json.utf8), delay: delay)
        )
    }

    static var recordedRequests: [RecordedRequest] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Product22StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    // MARK: URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let request = self.request
        // URLProtocol strips httpBody for streamed uploads; read the stream
        // so POST/PATCH bodies are still observable.
        var body = request.httpBody
        if body == nil, let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            let bufferSize = 4096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: bufferSize)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            buffer.deallocate()
            stream.close()
            body = data
        }

        let url = request.url ?? URL(string: "https://invalid.example")!
        Self.lock.lock()
        Self.recorded.append(
            RecordedRequest(
                url: url,
                method: request.httpMethod ?? "GET",
                headers: request.allHTTPHeaderFields ?? [:],
                body: body
            )
        )
        let match = Self.stubs.first { url.absoluteString.contains($0.pathContains) }
        Self.lock.unlock()

        guard let match else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        let deliver = { [weak self] in
            guard let self else { return }
            let response = HTTPURLResponse(
                url: url,
                statusCode: match.stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: match.stub.body)
            self.client?.urlProtocolDidFinishLoading(self)
        }

        if match.stub.delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + match.stub.delay, execute: deliver)
        } else {
            deliver()
        }
    }

    override func stopLoading() {}
}

// MARK: - Test factories

enum Product22TestFactory {

    static let baseURL = URL(string: "https://core.gamepedia.test")!

    static func makeService(
        authority: SessionCredentialAuthority
    ) -> DefaultProduct22APIService {
        DefaultProduct22APIService(
            baseURL: baseURL,
            authority: authority,
            session: Product22StubURLProtocol.makeSession()
        )
    }

    /// An authority with `accountID` signed in.
    static func makeAuthority(
        accountID: String = "account-a",
        token: String = "token-a"
    ) -> SessionCredentialAuthority {
        let authority = SessionCredentialAuthority()
        authority.adoptAuthenticatedSession(accountID: accountID, accessToken: token)
        return authority
    }

    static func envelope(_ dataJSON: String) -> String {
        #"{"success":true,"data":\#(dataJSON)}"#
    }

    static func errorEnvelope(code: String, message: String = "nope", field: String? = nil) -> String {
        let details = field.map { #","details":[{"field":"\#($0)","message":"invalid"}]"# } ?? ""
        return #"{"success":false,"error":{"code":"\#(code)","message":"\#(message)"\#(details)}}"#
    }
}

// MARK: - Fixtures shared by several suites

enum Product22Fixture {

    static let gameA = "7a1f2b3c-4d5e-4f60-8a91-2b3c4d5e6f70"
    static let gameB = "8b2f3c4d-5e6f-4071-9ba2-3c4d5e6f7081"

    static func productConfig(
        degraded: Bool = false,
        source: String = "database",
        allFeaturesOn: Bool = true
    ) -> String {
        let flag = allFeaturesOn ? "true" : "false"
        return Product22TestFactory.envelope("""
        {
          "dtoVersion": 1,
          "productVersion": "2.2.0",
          "generatedAt": "2026-07-30T09:00:00.000Z",
          "featureFlagSource": "\(source)",
          "featureFlagStateDegraded": \(degraded),
          "features": {
            "openCatalog": \(flag), "aiQuickAdd": \(flag), "playlog": \(flag),
            "playCompass": \(flag), "gameDNA": \(flag), "monthlyReplay": \(flag),
            "todayFeed": \(flag), "magazine": \(flag)
          },
          "limits": {},
          "allowlists": {
            "productEventCodes": [
              "quick_add_preview","quick_add_confirm","play_compass_submit",
              "play_compass_select","play_session_create","game_dna_view",
              "replay_view","replay_share","article_impression","article_action"
            ]
          }
        }
        """)
    }

    /// A Today feed whose sections are supplied by the caller.
    static func today(sections: String, order: String, partialFailure: Bool = false) -> String {
        Product22TestFactory.envelope("""
        {
          "generatedAt": "2026-07-30T09:00:00.000Z",
          "timezone": "Asia/Seoul",
          "locale": "ko",
          "sections": [\(sections)],
          "meta": {
            "sectionOrder": [\(order)],
            "limit": 8,
            "nextCursor": null,
            "partialFailure": \(partialFailure)
          }
        }
        """)
    }

    static func playCompassOKSection(recommendationCount: Int = 1) -> String {
        let recommendations = (0..<recommendationCount).map { index in
            recommendation(rank: index + 1, gameID: index == 0 ? gameA : gameB)
        }.joined(separator: ",")
        return """
        {"key":"playCompass","status":"ok","reasonCode":null,"data":{
          "recommendations":[\(recommendations)],
          "confidence":"MEDIUM",
          "dataFreshness":{"candidatePoolSize":12,"freshestLibraryUpdateAt":null,
                           "playlogSampleSize":4,"stale":false},
          "emptyReason":null,"ownedOnly":true}}
        """
    }

    static func recommendation(rank: Int, gameID: String) -> String {
        """
        {"catalogGameId":"\(gameID)","title":"Game \(rank)","rank":\(rank),"score":0.5,
         "scoreComponents":{"platform":1,"timeFit":1,"continuity":0,"social":0,
                            "energy":0,"mood":0,"recency":0,"snooze":0},
         "reasonCodes":["fits_available_time","owned_on_steam"],
         "estimatedSessionMinutes":45,"estimatedSessionBasis":"playlog_median",
         "ownershipEvidence":{"source":"STEAM","externalGameId":"1234",
           "libraryStatus":"PLAYING","provenance":"PROVIDER_VERIFIED",
           "playtimeMinutes":100,"lastPlayedAt":null,
           "installEvidence":{"known":false,"reason":"install_state_not_tracked"},
           "ownershipVerified":true}}
        """
    }

    static func degradedSection(key: String, status: String, reason: String) -> String {
        #"{"key":"\#(key)","status":"\#(status)","reasonCode":"\#(reason)","data":null}"#
    }

    static func playSession(
        id: String = "11111111-1111-4111-8111-111111111111",
        mutationID: String,
        note: String? = nil,
        gameID: String = gameA
    ) -> String {
        let noteJSON = note.map { "\"\($0)\"" } ?? "null"
        return """
        {"id":"\(id)","catalogGameId":"\(gameID)","regionalReleaseId":null,
         "playedAt":"2026-07-30T09:00:00.000Z","durationMinutes":60,
         "progressPercent":30,"mood":"FOCUSED","note":\(noteJSON),
         "outcome":"CONTINUE","visibility":"PRIVATE","provenance":"USER_CONFIRMED",
         "clientMutationId":"\(mutationID)",
         "createdAt":"2026-07-30T09:00:00.000Z","updatedAt":"2026-07-30T09:00:00.000Z"}
        """
    }

    static func playSessionList(_ sessions: String) -> String {
        Product22TestFactory.envelope(#"{"playSessions":[\#(sessions)],"meta":{}}"#)
    }
}
