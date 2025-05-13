//
//  UtilViewModel.swift
//  testApp (iOS)
//
//  Created by Anna Huller on 6/14/22.
//

import SwiftUI
import NewRelic

extension UtilityView {
    @MainActor class ViewModel: ObservableObject {
        
        let title = "Utility"
        @Published var numBreadcrumbs = 0
        @Published var goodAttribute = false
        @Published var badAttribute = false
        @Published var attributes = ""
        @Published var events = 0

        var uniqueInteractionTraceIdentifier: String? =  nil

        let taskProcessor = TaskProcessor()

        func crash() {
            NewRelicA.crashNow("New Relic intentionally crashed to test Utils")
        }
        func hugeCrashReport() {
            let crashOutputFilePath = String(format: "%@%@/%d.%@", NSTemporaryDirectory(), "nrcrashreports", 42, "nrcrashreport")
            
            let data = makeBigDictionary()
            do {
                try FileManager.default.createDirectory(atPath: String(format: "%@/%@", NSTemporaryDirectory(), "nrcrashreports"), withIntermediateDirectories: true)
                
                let success = FileManager.default.createFile(atPath: crashOutputFilePath, contents: data)
                
            } catch {
                print(error.localizedDescription)
            }
        }
        func removeAttributes() -> Bool{
            return NewRelicA.removeAllAttributes()
        }
        func setAttributes(){
            attributes = "test1: " + String(NewRelicA.setAttribute("test1", value: 1)) + " '': " + String(NewRelicA.setAttribute("", value: 2))
        }
        func makeError(){
            do {
                try errorMethod()
            } catch {
                NewRelicA.recordError(error)
                
            }
        }
        private func errorMethod() throws {
            throw CancellationError.init()
        }
        func makeBreadcrumb(name: String, attributes: Dictionary<String, Any>){
            let madeBreadCrumb = NewRelicA.recordBreadcrumb(name,
                                                           attributes: attributes)
            if madeBreadCrumb == true {
                self.numBreadcrumbs += 1
            }
        }
        
        func makeEvent(){
            let madeEvent = NewRelicA.recordCustomEvent("ButtonPress")
            if madeEvent == true {
                events += 1
            }
        }

        func make100Events() {
            for i in 0...100 {
                NewRelicA.recordCustomEvent("ButtonPress")
            }
        }

        func sendRedirectRequest() {
            guard let url = URL(string: "https://easynvest.com.br") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                print("ok")
            }
            task.resume()
        }
        func stopInteractionTrace() {
            guard let identifier = uniqueInteractionTraceIdentifier else {
                print("no interaction to stop...")
                return
            }
            NewRelicA.stopCurrentInteraction(identifier)

            uniqueInteractionTraceIdentifier = nil
        }

        func startInteractionTrace() {
            uniqueInteractionTraceIdentifier = NewRelicA.startInteraction(withName: "myInteractionName")
        }



        func noticeFailedNWRequest() {
            NewRelicA.noticeNetworkFailure(for: URL(string: "https://www.google.com"), httpMethod: "GET",
                                          with: NRTimer(), andFailureCode: NSURLErrorTimedOut)
        }

        func noticeNWRequest() {
           // NewRelic.noticeNetworkRequest(for: URL(string: "https://www.google.com"), httpMethod: "GET", with: NRTimer(), responseHeaders: [:],
           //                               statusCode: 200, bytesSent: 1000, bytesReceived: 1000, responseData: Data(), traceHeaders: nil, andParams: nil)

            NewRelicA.noticeNetworkRequest(for: URL(string:"https://fakeurl.com"),
                                          httpMethod: "GET",
                                          startTime: Date().timeIntervalSince1970,
                                          endTime: Date().timeIntervalSince1970,
                                          responseHeaders: nil,
                                          statusCode: 400,
                                          bytesSent: 100,
                                          bytesReceived: 200,
                                          responseData: Data("example response body".utf8),
                                          traceHeaders: nil,
                                          andParams: nil)
        }

        func setBuild() {
            NewRelicA.setApplicationBuild("42")
        }


        func doDataTask() {
            let urlSession = URLSession(configuration: URLSession.shared.configuration, delegate: taskProcessor, delegateQueue: nil)
            guard let url = URL(string: "https://www.google.com") else { return }

            let request = URLRequest(url: url)

            let dataTask = urlSession.dataTask(with: request)

            dataTask.resume()
        }

        func doDataTaskWithCompletionHandler() {
            let urlSession = URLSession(configuration: URLSessionConfiguration.default)
            guard let url = URL(string: "https://www.google.com") else { return }

            let request = URLRequest(url: url)

            let dataTask = urlSession.dataTask(with: request) { data, response, error in
                //Handle
                if let httpResponse = response as? HTTPURLResponse {
                    print("SUCCESS w/ dataTask w/ completionHandler")

                }
                else if let errorCode = error?._code {
                    print(error?.localizedDescription)

                }
                else {

                }
            }

            dataTask.resume()
            urlSession.finishTasksAndInvalidate()
        }
        
        func makeBigDictionary() -> Data {
            var dictionary = [String:String]()
            var data = Data()
            for i in 0...30000 {
                dictionary.updateValue("42", forKey: "The meaning of life #"+String(i))
            }
            do {
                data = try JSONSerialization.data(withJSONObject: dictionary)
            } catch {
                print(error.localizedDescription)
            }
            return data
        }
    }
}

class TaskProcessor: NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("DataTask rcv data.")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("DataTask did complete.")
    }

    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
//        completionHandler(.performDefaultHandling, nil)

        //completionHandler(.cancelAuthenticationChallenge, nil)

        if let trust = challenge.protectionSpace.serverTrust,
             SecTrustGetCertificateCount(trust) > 0 {
          if let certificate = SecTrustGetCertificateAtIndex(trust, 0) {
            let data = SecCertificateCopyData(certificate) as Data

                completionHandler(.useCredential, URLCredential(trust: trust))
                return
          }

        }
      completionHandler(.cancelAuthenticationChallenge, nil)


    }
}
