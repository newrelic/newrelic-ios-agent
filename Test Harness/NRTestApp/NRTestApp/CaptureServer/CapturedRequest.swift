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

    var summary: String { String(prettyJSON.prefix(150)) }

    func queryValue(_ name: String) -> String? {
        queryParams.first(where: { $0.0 == name })?.1
    }
}
