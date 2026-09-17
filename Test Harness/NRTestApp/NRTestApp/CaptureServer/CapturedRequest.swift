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
