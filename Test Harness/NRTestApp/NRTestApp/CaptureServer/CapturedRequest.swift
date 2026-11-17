import Foundation

struct CapturedRequest: Identifiable {
    let id: UUID
    let timestamp: Date
    let endpoint: String
    let headers: [String: String]
    let queryParams: [(String, String)]
    let decodedBody: Data
    let prettyJSON: String
    var verification: VerificationResult?
    // The connect response config the server actually served (nil when a 4xx/5xx was injected).
    var serverConnectResponse: ConnectConfig? = nil
    /// Which app launch received this upload (1-based, persisted across launches). 0 = unknown.
    var launch: Int = 0

    init(id: UUID = UUID(), timestamp: Date, endpoint: String, headers: [String: String],
         queryParams: [(String, String)], decodedBody: Data, prettyJSON: String) {
        self.id = id; self.timestamp = timestamp; self.endpoint = endpoint; self.headers = headers
        self.queryParams = queryParams; self.decodedBody = decodedBody; self.prettyJSON = prettyJSON
    }

    var summary: String { String(prettyJSON.prefix(150)) }

    var fullURL: String {
        guard !queryParams.isEmpty else { return endpoint }
        let qs = queryParams.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
        return "\(endpoint)?\(qs)"
    }

    func queryValue(_ name: String) -> String? {
        queryParams.first(where: { $0.0 == name })?.1
    }
}

/// On-disk form of a capture. Verification results aren't stored; "Verify All" recomputes them.
struct PersistedCapture: Codable {
    let id: UUID
    let timestamp: Date
    let endpoint: String
    let headers: [String: String]
    let queryParams: [[String]]
    let decodedBody: Data
    let prettyJSON: String
    let serverConnectResponse: ConnectConfig?
    let launch: Int

    init(_ c: CapturedRequest) {
        id = c.id; timestamp = c.timestamp; endpoint = c.endpoint; headers = c.headers
        queryParams = c.queryParams.map { [$0.0, $0.1] }
        decodedBody = c.decodedBody; prettyJSON = c.prettyJSON
        serverConnectResponse = c.serverConnectResponse; launch = c.launch
    }

    var capture: CapturedRequest {
        var c = CapturedRequest(id: id, timestamp: timestamp, endpoint: endpoint, headers: headers,
                                queryParams: queryParams.compactMap { $0.count == 2 ? ($0[0], $0[1]) : nil },
                                decodedBody: decodedBody, prettyJSON: prettyJSON)
        c.serverConnectResponse = serverConnectResponse
        c.launch = launch
        return c
    }
}
