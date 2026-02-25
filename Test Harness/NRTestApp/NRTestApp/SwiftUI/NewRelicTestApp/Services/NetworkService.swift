import Foundation
import NewRelic

class NetworkService {
    static let shared = NetworkService()

    private init() {}

    func fetchData(completion: @escaping (Result<Data, Error>) -> Void) {
        let startTime = Date()
        let url = URL(string: "https://jsonplaceholder.typicode.com/todos/1")!

        NewRelic.recordBreadcrumb("Network request initiated",
                                attributes: ["url": url.absoluteString])

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            let duration = Date().timeIntervalSince(startTime)

            if let error = error {
                NewRelic.recordMetric(withName: "Network/Error", category: "Network", value: 1)
                NewRelic.recordError(error)
                NewRelic.recordCustomEvent("NetworkRequestFailed",
                                          attributes: [
                                            "url": url.absoluteString,
                                            "duration": duration,
                                            "error": error.localizedDescription
                                          ])
                completion(.failure(error))
                return
            }

            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(domain: "NetworkService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                NewRelic.recordError(error)
                completion(.failure(error))
                return
            }

            NewRelic.recordMetric(withName: "Network/ResponseTime",
                                category: "Network",
                                value: NSNumber(value: duration * 1000))

            NewRelic.recordMetric(withName: "Network/ResponseSize",
                                category: "Network",
                                value: NSNumber(value: data.count))

            NewRelic.recordCustomEvent("NetworkRequestSuccess",
                                      attributes: [
                                        "url": url.absoluteString,
                                        "duration": duration,
                                        "statusCode": httpResponse.statusCode,
                                        "dataSize": data.count
                                      ])

            completion(.success(data))
        }

        task.resume()
    }
}
