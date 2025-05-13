//
//  UtilViewModel.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/13/23.
//

import Foundation
import NewRelic
import OSLog

struct UtilOption {
    let title:String
    let handler:(() -> Void)
}

class UtilViewModel {
        
    var options =  [UtilOption]()
            
    var numBreadcrumbs = 0
    var goodAttribute = false
    var badAttribute = false
    var attributes = ""
    var events = 0 

    var uniqueInteractionTraceIdentifier: String? =  nil

    let taskProcessor = TaskProcessor()
    let taskProcessor2 = TaskProcessorNoDidRcvResp()
    
    init() {
        createUtilOptions()
    }

    func createUtilOptions() {
        options.append(UtilOption(title: "Add Valid Breadcrumb", handler: { [self] in makeValidBreadcrumb()}))
        options.append(UtilOption(title: "Add Invalid Breadcrumb", handler: { [self] in makeInvalidBreadcrumb()}))
        options.append(UtilOption(title: "Set Attributes", handler: { [self] in setAttributes()}))
        options.append(UtilOption(title: "Remove Attributes", handler: { [self] in removeAttributes()}))
        options.append(UtilOption(title: "Crash Now!", handler: { [self] in crash()}))
        options.append(UtilOption(title: "Record Error", handler: { [self] in makeError()}))
        options.append(UtilOption(title: "Record Handled Exception", handler: { triggerException.testing()}))

        options.append(UtilOption(title: "Set UserID to testID", handler: { [self] in changeUserID()}))
        options.append(UtilOption(title: "Set UserID to Bob", handler: { [self] in changeUserID2()}))
        options.append(UtilOption(title: "Set UserID to null", handler: { [self] in changeUserIDToNil()}))

        options.append(UtilOption(title: "Make 100 events", handler: { [self] in make100Events()}))
        options.append(UtilOption(title: "Start Interaction Trace", handler: { [self] in startInteractionTrace()}))
        options.append(UtilOption(title: "End Interaction Trace", handler: { [self] in stopInteractionTrace()}))
        options.append(UtilOption(title: "Notice Network Request", handler: { [self] in noticeNWRequest()}))
        options.append(UtilOption(title: "Notice Network Failure", handler: { [self] in noticeFailedNWRequest()}))

        options.append(UtilOption(title: "Test System Logs", handler: { [self] in testSystemLogs()}))
        options.append(UtilOption(title: "Notice Network Request w headers/params", handler: { [self] in 
            Task { await noticeNetworkRequestWithParams() }
        }))


        options.append(UtilOption(title: "Test Log Dict", handler: { [self] in testLogDict()}))
        options.append(UtilOption(title: "Test Log Error", handler: { [self] in testLogError()}))
        options.append(UtilOption(title: "Test Log Attributes", handler: { [self] in testLogAttributes()}))

        options.append(UtilOption(title: "Make 100 Logs", handler: { [self] in make100Logs()}))
        options.append(UtilOption(title: "Make 100 Special Character Logs", handler: { [self] in make100SpecialCharacterLogs()}))

        options.append(UtilOption(title: "URLSession dataTask", handler: { [self] in doDataTask()}))
        options.append(UtilOption(title: "Shut down New Relic Agent", handler: { [self] in shutDown()}))
    }

    func crash() {
        // This will cause a crash to test the crash uploader, crash files may not get recorded if the debugger is running.
        NewRelicA.crashNow("New Relic intentionally crashed to test Utils")
    }
    
    func removeAttributes() {
        if(NewRelicA.removeAllAttributes()){
            attributes = ""
        }
    }
    
    func setAttributes(){
        attributes = String(NewRelicA.setAttribute("test1", value: 1))
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
    
    func changeUserID() {
        NewRelicA.setUserId("testID")
    }
    func changeUserID2() {
        NewRelicA.setUserId("Bob")
    }

    func changeUserIDToNil() {
        NewRelicA.setUserId(nil)
    }

    func makeValidBreadcrumb() {
        makeBreadcrumb(name: "test", attributes: ["button" : "Breadcrumb"])
    }
    
    func makeInvalidBreadcrumb() {
        makeBreadcrumb(name: "", attributes: ["button" : "Breadcrumb"])
    }
    
    private func makeBreadcrumb(name: String, attributes: Dictionary<String, Any>){
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
        for _ in 0...100 {
            NewRelicA.recordCustomEvent("ButtonPress")
        }
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

    func noticeNetworkRequestWithParams() async {
        let url = URL(string: "https://www.apple.com")!

        let request = URLRequest(url: url)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print("Async-Await Data request made.")
            NewRelicA.noticeNetworkRequest(
                for: url,
                httpMethod: "GET",
                with: NRTimer(),
                responseHeaders: ["x-response-header":"12345"],
                statusCode: 200,
                bytesSent: 0,
                bytesReceived: UInt(data.count),
                responseData: data,
                traceHeaders: [:],
                andParams: ["x-foo-header-id": "foo", "x-bar-header-id": "bar"]
            )
        }
        catch {
            print("\(error): Error making async-await data request.")

        }


    }

    func testLogDict() {
        NewRelicA.logAll([
            "logLevel": "WARN",
            "message": "This is a test message for the New Relic logging system."
        ])
    }
    
    func testSystemLogs() {
        for i in 0...100 {
            //triggerException.testNSLog(Int32(i))
            print("TEST swift!!!!! ", i, "\n")
            if #available(iOS 14.0, tvOS 14.0, *) {
                os_log("TEST OSLog!!!!!!! \(i)")
                let logger = Logger()
                logger.warning("TEST Logger!!!!! \(i)")
            }
        }
    }
    
    func testLogError() {
        do {
            try errorMethod()
        } catch {
            NewRelicA.logErrorObject(error)
        }
    }

    func testLogAttributes() {
        NewRelicA.logAttributes([
            "logLevel": "WARN",
            "message": "This is a test message for the New Relic logging system.",
            "additionalAttribute1": "attribute1",
            "additionalAttribute2": "attribute2"
        ])
    }


    func noticeNWRequest() {
        NewRelicA.noticeNetworkRequest(for: URL(string: "https://www.google.com"), httpMethod: "GET", with: NRTimer(), responseHeaders: [:],
                                      statusCode: 200, bytesSent: 1000, bytesReceived: 1000, responseData: Data(), traceHeaders: nil, andParams: nil)
    }

    func setBuild() {
        NewRelicA.setApplicationBuild("42")
    }

    func doDataTask() {
        let urlSession = URLSession(configuration: URLSession.shared.configuration, delegate: taskProcessor, delegateQueue: nil)
        guard let url = URL(string: "https://www.google.com") else { return }

        var request = URLRequest(url: url)
        request.addValue("Sucsess", forHTTPHeaderField: "Test")
        let dataTask = urlSession.dataTask(with: request)

        dataTask.resume()
    }

    func doDataTaskNoDidRcvResp() {
        let urlSession = URLSession(configuration: URLSession.shared.configuration, delegate: taskProcessor2, delegateQueue: nil)
        guard let url = URL(string: "https://www.google.com") else { return }

        let request = URLRequest(url: url)

        let dataTask = urlSession.dataTask(with: request)

        dataTask.resume()
    }

    @objc func make100SpecialCharacterLogs() {
        for _ in 0...100 {
            NewRelicA.logInfo("/")
            // Testing special character
            NewRelicA.logInfo("\\")

            NewRelicA.logInfo(";")
            NewRelicA.logInfo(":")
            NewRelicA.logInfo("!")
            NewRelicA.logInfo("#")
            NewRelicA.logInfo("&")
            NewRelicA.logInfo("-")
            NewRelicA.logInfo("?")
            NewRelicA.logInfo("'")
            NewRelicA.logInfo("$")
        }
    }

    @objc func make100Logs() {
        for _ in 0...100 {
            NewRelicA.logInfo("I")
            NewRelicA.logInfo("L")
            NewRelicA.logInfo("O")
            NewRelicA.logInfo("V")
            NewRelicA.logInfo("E")
            NewRelicA.logInfo("N")
            NewRelicA.logInfo("E")
            NewRelicA.logInfo("W")
            NewRelicA.logInfo("R")
            NewRelicA.logInfo("E")
            NewRelicA.logInfo("L")
            NewRelicA.logInfo("I")
            NewRelicA.logInfo("C")
        }
    }

    func shutDown() {
        NewRelicA.shutdown()
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

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        if let trust = challenge.protectionSpace.serverTrust,
             SecTrustGetCertificateCount(trust) > 0 {
          if let certificate = SecTrustGetCertificateAtIndex(trust, 0) {
              _ = SecCertificateCopyData(certificate) as Data
              
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
          }
        }
      completionHandler(.cancelAuthenticationChallenge, nil)

    }
}

class TaskProcessorNoDidRcvResp: NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate {

    // DEMONSTRATE BUG in 7.4.2: API_MISUSE
//    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
//
//        completionHandler(.allow)
//    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("DataTask rcv data.")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("DataTask did complete.")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        if let trust = challenge.protectionSpace.serverTrust,
             SecTrustGetCertificateCount(trust) > 0 {
          if let certificate = SecTrustGetCertificateAtIndex(trust, 0) {
              _ = SecCertificateCopyData(certificate) as Data

                completionHandler(.useCredential, URLCredential(trust: trust))
                return
          }
        }
      completionHandler(.cancelAuthenticationChallenge, nil)

    }
}
