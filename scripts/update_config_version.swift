#!/usr/bin/swift

import Foundation

let API_ENDPOINT = "/v2/system_configuration.json"
let STAGING_HOST = "staging-api.newrelic.com"
let PRODUCTION_HOST = "api.newrelic.com"
let PRODUCTION_EU_HOST = "api.eu.newrelic.com"

struct EnvironmentDetails {
    let host: String
    let apiKey: String
}

struct SystemConfigurationBody:Codable {
    let systemConfiguration: SystemConfiguration
    struct SystemConfiguration:Codable {
        var key = "ios_agent_version"
        let value: String
    }
}

let urlSession = URLSession.shared
// Uncomment if you need to do debugging with Charles
// let urlSession = URLSession(configuration: .default, delegate: NetworkEnabler(), delegateQueue: nil)

// @available(macOS 11, *)
// public class NetworkEnabler: NSObject, URLSessionDelegate {
//     public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
//         completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
//     }
// }

if CommandLine.arguments.contains("-help") {
    print("Help Passed")
    printHelp()
    exit(1)
}

let namedArguments = UserDefaults.standard
guard let version = namedArguments.string(forKey: "version") else {
    print("No Version Passed")
    printHelp()
    exit(1)
}
print("Version is: \(version)")

guard let prodKey = namedArguments.string(forKey: "productionKey") else {
    print("No Production Key Passed")
    printHelp()
    exit(1)
}

guard let stagingKey = namedArguments.string(forKey: "stagingKey") else {
    print("No Staging Key Passed")
    printHelp()
    exit(1)
}

let stagingEnvironment = EnvironmentDetails(host: STAGING_HOST, apiKey: stagingKey)
let productionEnvironment = EnvironmentDetails(host: PRODUCTION_HOST, apiKey: prodKey)
let productionEUEnvironment = EnvironmentDetails(host: PRODUCTION_EU_HOST, apiKey: prodKey)

let environments = [stagingEnvironment, productionEnvironment, productionEUEnvironment]
let urlDispatchGroup = DispatchGroup()
let urlDispatchQueue = DispatchQueue(label: "update config queue")
var results = [URL:Int]()

environments.forEach { (environment) in
    urlDispatchGroup.enter()
    let request = buildRequest(environment: environment)

    let task = urlSession.dataTask(with: request) { (data, response, error) in
        if let error = error {
            print("\(error)")
            urlDispatchQueue.async {
                urlDispatchGroup.leave()
            }
            return
        }

        if let response = response as? HTTPURLResponse, let url = response.url {
            urlDispatchQueue.async {
                results[url] = response.statusCode
                urlDispatchGroup.leave()
            }
        }
    }
    task.resume()
}

urlDispatchGroup.notify(queue: DispatchQueue.global()) {
    print("Finished")
    completion(statusCodes: results)
}

func completion(statusCodes: [URL:Int]) {
    if(statusCodes.count != environments.count) {
        print("Expected ")
        exit(-1)
    }
    
    for (url, statusCode) in statusCodes {
        print ("Status Code is \(statusCode)")
        if (statusCode != 200) && (statusCode != 201) {
            print("Error trying to update to \(url)")
            exit(-1)
        }
    }
    
    print("Version successfully updated")
    exit(0)
}

func buildRequest(environment: EnvironmentDetails) -> URLRequest {
    var components = URLComponents()
    components.scheme = "https"
    components.host = environment.host
    components.path = API_ENDPOINT
    let url = components.url!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
    request.addValue(environment.apiKey, forHTTPHeaderField: "X-API-KEY")
    request.httpBody = buildPayload(version: version)
    return request
}

func buildPayload(version: String) -> Data {
    let systemConfiguration = SystemConfigurationBody(systemConfiguration: SystemConfigurationBody.SystemConfiguration(value: version))
    
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return try! encoder.encode(systemConfiguration)
}

func printHelp() {
    let helpMessage =
    """
    -version        New Version of iOS Agent
    -productionKey  API Key for Production Configuration (both US and EU)
    -stagingKey     API Key for Staging Configuration.
    -help           Prints this help message

    USAGE
    ./update_config_version -version <version> -productionKey <key> -stagingKey <key>
    """

    print(helpMessage)
}

dispatchMain()
