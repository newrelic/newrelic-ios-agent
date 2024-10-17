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
        NewRelic.crashNow("New Relic intentionally crashed to test Utils")
    }
    
    func removeAttributes() {
        if(NewRelic.removeAllAttributes()){
            attributes = ""
        }
    }
    
    func setAttributes(){
        attributes = String(NewRelic.setAttribute("test1", value: 1))
    }
    
    func makeError(){
        do {
            try errorMethod()
        } catch {
            NewRelic.recordError(error)
            
        }
    }
    
    private func errorMethod() throws {
        throw CancellationError.init()
    }
    
    func changeUserID() {
        NewRelic.setUserId("testID")
    }
    func changeUserID2() {
        NewRelic.setUserId("Bob")
    }

    func changeUserIDToNil() {
        NewRelic.setUserId(nil)
    }

    func makeValidBreadcrumb() {
        makeBreadcrumb(name: "test", attributes: ["button" : "Breadcrumb"])
    }
    
    func makeInvalidBreadcrumb() {
        makeBreadcrumb(name: "", attributes: ["button" : "Breadcrumb"])
    }
    
    private func makeBreadcrumb(name: String, attributes: Dictionary<String, Any>){
        let madeBreadCrumb = NewRelic.recordBreadcrumb(name,
                                                       attributes: attributes)
        if madeBreadCrumb == true {
            self.numBreadcrumbs += 1
        }
    }
    
    func makeEvent(){
        let madeEvent = NewRelic.recordCustomEvent("ButtonPress")
        if madeEvent == true {
            events += 1
        }
    }

    func make100Events() {
        for _ in 0...100 {
            NewRelic.recordCustomEvent("ButtonPress")
        }
    }
    
    func stopInteractionTrace() {
        guard let identifier = uniqueInteractionTraceIdentifier else {
            print("no interaction to stop...")
            return
        }
        NewRelic.stopCurrentInteraction(identifier)

        uniqueInteractionTraceIdentifier = nil
    }

    func startInteractionTrace() {
        uniqueInteractionTraceIdentifier = NewRelic.startInteraction(withName: "myInteractionName")
    }

    func noticeFailedNWRequest() {
        NewRelic.noticeNetworkFailure(for: URL(string: "https://www.google.com"), httpMethod: "GET",
                                      with: NRTimer(), andFailureCode: NSURLErrorTimedOut)
    }

    func testLogDict() {
        NewRelic.logAll([
            "logLevel": "WARN",
            "message": "This is a test message for the New Relic logging system."
        ])
    }
    
    func testSystemLogs() {
        for i in 0...100 {
            triggerException.testNSLog()
            print("TEST swift!!!!! \(i)")
            if #available(iOS 14.0, *) {
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
            NewRelic.logErrorObject(error)
        }
    }

    func testLogAttributes() {
        NewRelic.logAttributes([
            "logLevel": "WARN",
            "message": "This is a test message for the New Relic logging system.",
            "additionalAttribute1": "attribute1",
            "additionalAttribute2": "attribute2"
        ])
    }


    func noticeNWRequest() {
        NewRelic.noticeNetworkRequest(for: URL(string: "https://www.google.com"), httpMethod: "GET", with: NRTimer(), responseHeaders: [:],
                                      statusCode: 200, bytesSent: 1000, bytesReceived: 1000, responseData: Data(), traceHeaders: nil, andParams: nil)
    }

    func setBuild() {
        NewRelic.setApplicationBuild("42")
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
            NewRelic.logInfo("/")
            // Testing special character
            NewRelic.logInfo("\\")

            NewRelic.logInfo(";")
            NewRelic.logInfo(":")
            NewRelic.logInfo("!")
            NewRelic.logInfo("#")
            NewRelic.logInfo("&")
            NewRelic.logInfo("-")
            NewRelic.logInfo("?")
            NewRelic.logInfo("'")
            NewRelic.logInfo("$")
        }
    }

    @objc func make100Logs() {
        for _ in 0...100 {
            NewRelic.logInfo("I")
            NewRelic.logInfo("L")
            NewRelic.logInfo("O")
            NewRelic.logInfo("V")
            NewRelic.logInfo("E")
            NewRelic.logInfo("N")
            NewRelic.logInfo("E")
            NewRelic.logInfo("W")
            NewRelic.logInfo("R")
            NewRelic.logInfo("E")
            NewRelic.logInfo("L")
            NewRelic.logInfo("I")
            NewRelic.logInfo("C")
        }
    }

    func shutDown() {
        NewRelic.shutdown()
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
