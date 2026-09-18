import Foundation

struct CapturedRequest: Identifiable {
    let id: UUID = UUID()
    let timestamp: Date
    let endpoint: String
    let headers: [String: String]
    let queryParams: [(String, String)]
    let decodedBody: Data
    let prettyJSON: String
    var verification: VerificationResult?
    // The connect response config the server actually served (nil when a 4xx/5xx was injected).
    var serverConnectResponse: ConnectConfig? = nil
    let responseStatusCode: Int
    let responseHeaders: [String: String]
    let responseBody: String

    var summary: String { String(prettyJSON.prefix(150)) }

    /// True when the server sent back a non-2xx response (e.g. an injected error).
    var hasFailedResponse: Bool { !(200...299).contains(responseStatusCode) }

    var fullURL: String {
        guard !queryParams.isEmpty else { return endpoint }
        let qs = queryParams.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
        return "\(endpoint)?\(qs)"
    }

    func queryValue(_ name: String) -> String? {
        queryParams.first(where: { $0.0 == name })?.1
    }
}

/// A Codable snapshot of a `CapturedRequest`, persisted to disk so the last few requests from
/// the previous launch can still be inspected after relaunching (`captures` itself is in-memory
/// only and starts empty every launch). Tuples aren't Codable, so query params are stored as
/// [key, value] pairs instead of `(String, String)`; verification isn't persisted since it's only
/// meaningful against the live, in-memory capture list.
struct PersistedCapture: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let endpoint: String
    let headers: [String: String]
    let queryParams: [[String]]
    let prettyJSON: String
    let responseStatusCode: Int
    let responseHeaders: [String: String]
    let responseBody: String

    init(_ capture: CapturedRequest) {
        id = capture.id
        timestamp = capture.timestamp
        endpoint = capture.endpoint
        headers = capture.headers
        queryParams = capture.queryParams.map { [$0.0, $0.1] }
        prettyJSON = capture.prettyJSON
        responseStatusCode = capture.responseStatusCode
        responseHeaders = capture.responseHeaders
        responseBody = capture.responseBody
    }

    var summary: String { String(prettyJSON.prefix(150)) }
    var hasFailedResponse: Bool { !(200...299).contains(responseStatusCode) }
}
