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
        try! server.start()
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
                if (filename == "handledException") {
                    hitClosure?("Exception report created")
                } else {
                    hitClosure?(String(bytes: request.body, encoding: .utf8)!)
                }
            }
            return HttpResponse.ok(.json(json as AnyObject))
        }
        switch method  {
        case .GET : server.GET[url] = response
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

