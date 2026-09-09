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
