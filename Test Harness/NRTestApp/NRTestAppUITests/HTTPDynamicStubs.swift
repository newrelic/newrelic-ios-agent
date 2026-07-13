//
//  HTTPDynamicStubs.swift
//  Tests iOS
//
//  Created by Anna Huller on 6/23/22.
//

import Foundation

enum HTTPMethod {
    case POST
    case GET
}

class HTTPDynamicStubs {
    
    var server = HttpServer()
    func setUp() {
        do {
            try server.start()
        } catch {
            print(error)
        }
    }
    
    func tearDown() {
        server.stop()
    }

    public func setupStub(url: String, filename: String, method: HTTPMethod = .GET, matchRequestBody: String? = nil, hitClosure: ((String) -> ())? = nil) {
        let testBundle = Bundle(for: HTTPDynamicStubs.self)
        let filePath = testBundle.path(forResource: filename, ofType: "json")
        let fileUrl = URL(fileURLWithPath: filePath!)
        let data = try! Data(contentsOf: fileUrl, options: .uncached)
        // Looking for a file and converting it to JSON
        let json = dataToJSON(data: data)
        // Swifter makes it very easy to create stubbed responses
        let response: ((HttpRequest) -> HttpResponse) = { request in
            if let matchRequestBody = matchRequestBody {
                    hitClosure?(String(bytes: request.body, encoding: .utf8)!)
            }
            return HttpResponse.ok(.json(json as AnyObject))
        }
        switch method  {
        case .GET : server.GET[url] = response
        case .POST: server.POST[url] = response
        }
    }
    
    /// Stubs an endpoint with an explicit HTTP status code, response headers, and an inline JSON
    /// body. Unlike the file-based `setupStub`, this can express non-200 responses (e.g. a 429 with
    /// a `Retry-After` header) so tests can exercise the agent's rate-limit backoff handling.
    /// `hitClosure` is invoked with the request body string on every hit.
    public func setupStub(url: String,
                          method: HTTPMethod = .POST,
                          statusCode: Int,
                          responseHeaders: [String: String] = [:],
                          jsonBody: Any = [String: Any](),
                          hitClosure: ((String) -> ())? = nil) {
        let bodyData = (try? JSONSerialization.data(withJSONObject: jsonBody)) ?? Data()
        let reasonPhrase = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        let response: ((HttpRequest) -> HttpResponse) = { request in
            hitClosure?(String(bytes: request.body, encoding: .utf8) ?? "")
            return HttpResponse.raw(statusCode, reasonPhrase, responseHeaders) { writer in
                try writer.write(bodyData)
            }
        }
        switch method {
        case .GET: server.GET[url] = response
        case .POST: server.POST[url] = response
        }
    }

    func dataToJSON(data: Data) -> Any? {
        do {
            return try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
        } catch let myJSONError {
            print(myJSONError)
        }
        return nil
    }
}

struct HTTPStubInfo {
    let url: String
    let jsonFilename: String
    let method: HTTPMethod
}

