//
//  NRTestAppTests.swift
//  NRTestAppTests
//
//  Created by Mike Bruin on 1/11/23.
//

import XCTest
@testable import NRTestApp

final class NRTestAppTests: XCTestCase, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
    
    var viewModel: ApodViewModel!
    var utilViewModel: UtilViewModel!
    var webViewController: WebViewController!
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        viewModel = ApodViewModel()
        utilViewModel = UtilViewModel()
        webViewController = WebViewController()
        
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        viewModel = nil
        utilViewModel = nil
        try super.tearDownWithError()
    }

    func testApodViewModel() throws {
        let promise = expectation(description: "apodResponse completion handler invoked")
        viewModel.apodResponse.onUpdate = { [weak self] _ in
            if let url = self?.viewModel.apodResponse.value?.url {
                UIImageView().loadImage(withUrl: url)
                promise.fulfill()
            }
        }
        
        viewModel.loadApodData()
        wait(for: [promise], timeout: 5)
    }
    
    func testUtilValidBreadcrumb() throws {
       XCTAssertNoThrow(utilViewModel.makeValidBreadcrumb())
    }
    
    func testUtilInvalidBreadcrumb() throws {
       XCTAssertNoThrow(utilViewModel.makeInvalidBreadcrumb())
    }
    
    func testUtilSetAttributes() throws {
       XCTAssertNoThrow(utilViewModel.setAttributes())
    }
    
    func testUtilRemoveAttributes() throws {
       XCTAssertNoThrow(utilViewModel.removeAttributes())
    }
    
    func testUtilRecordError() throws {
       XCTAssertNoThrow(utilViewModel.makeError())
    }
    
    func testUtilRecordHandledException() throws {
        XCTAssertNoThrow(triggerException.testing())
    }
    
    func testUtilChangeUserID() throws {
        XCTAssertNoThrow(utilViewModel.changeUserID())
    }
    
    func testUtilMake100Events() throws {
        XCTAssertNoThrow(utilViewModel.make100Events())
    }
    
    func testUtilStartAndEndInteractionTrace() throws {
        XCTAssertNoThrow(utilViewModel.startInteractionTrace())
        sleep(1)
        XCTAssertNoThrow(utilViewModel.stopInteractionTrace())
    }
    
    func testUtilNoticeNWRequest() throws {
        XCTAssertNoThrow(utilViewModel.noticeNWRequest())
    }
    func testUtilFailedNWRequest() throws {
        XCTAssertNoThrow(utilViewModel.noticeFailedNWRequest())
    }

    // NR-622029 — reporting with caller-supplied trace headers must not throw for either event
    // type, including on the NSNull `newrelic` entry the Flutter bridge passes.
    func testUtilNoticeFlutterStyleDistributedTracedRequest() throws {
        XCTAssertNoThrow(utilViewModel.noticeFlutterStyleDistributedTracedRequest())
        XCTAssertNoThrow(utilViewModel.noticeFlutterStyleDistributedTracedRequest(statusCode: 403))
    }
    
    func testUtilURLSessionDataTask() throws {
        XCTAssertNoThrow(utilViewModel.doDataTask())
    }

    func testUtilURLSessionDataTaskNoRcvResp() throws {
        // SHOULD NOT LOG API_MISUSE
        // // 2023-02-28 12:29:28.954274-0700 NRTestApp[42431:6943448] [API] API MISUSE: NSURLSession delegate NRMAURLSessionTaskDelegate: <NRMAURLSessionTaskDelegate: 0x600001dcd270> (0x600001dcd270)
        // // 2023-02-28 12:29:28.954355-0700 NRTestApp[42431:6943448] [API] API MISUSE: dataTask:didReceiveResponse:completionHandler: completion handler not called
        XCTAssertNoThrow(utilViewModel.doDataTaskNoDidRcvResp())
    }
    
    func testDecidePolicyForNavigationAction() throws {
        let testURL = URL(string: "https://www.newrelic.com")!
        let testAction = FakeNavigationAction(url: testURL)

        webViewController.webView(webViewController.webView, decidePolicyFor: testAction, decisionHandler: testAction.decisionHandler)

        XCTAssertEqual(testAction.receivedPolicy, .allow)
    }
    
    func testDidReceiveAuthenticationChallenge() throws {
        let testChallenge = FakeURLAuthenticationChallenge.init(protectionSpace: URLProtectionSpace(), proposedCredential: nil, previousFailureCount: 0, failureResponse: nil, error: nil, sender: self)

        webViewController.webView(webViewController.webView, didReceive:testChallenge, completionHandler: testChallenge.completionHandler)
        
        XCTAssertNil(testChallenge.receivedCredential);
        XCTAssertEqual(testChallenge.receivedChallenge, .performDefaultHandling);
    }


    func testAsyncInstrumentation() async {
        let promise = expectation(description: "apodResponse async completion handler invoked")
        viewModel.apodResponse.onUpdate = { _ in
            Task {
                if let url = self.viewModel.apodResponse.value?.url {
                    await UIImageView().loadImage(withUrl: url)
                    promise.fulfill()
                }
            }
        }

        await viewModel.loadApodDataAsync()

        await fulfillment(of: [promise], timeout: 5)
    }
}

// MARK: - Capture server: recovered events

final class CaptureServerRecoveredEventChecksTests: XCTestCase {

    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

    private func dataCapture(at offset: TimeInterval, session: String, events: [[String: Any]]) -> CapturedRequest {
        let body: [Any] = [[1, 2], [], 0, [], [], [], [], [], ["sessionId": session], events]
        let data = try! JSONSerialization.data(withJSONObject: body)
        return CapturedRequest(timestamp: t0.addingTimeInterval(offset), endpoint: "/mobile/v3/data",
                               headers: [:], queryParams: [], decodedBody: data, prettyJSON: "")
    }

    private func checks(_ captures: [CapturedRequest]) -> [UUID: VerificationCheck] {
        NRCaptureServer.recoveredEventChecks(for: captures.reversed())   // newest-first, like verifyAll
    }

    private func live(_ type: String, ts: Int, seq: String) -> [String: Any] {
        ["eventType": type, "timestamp": ts, "nrTestSeq": seq]
    }

    private func recovered(_ type: String, ts: Int, seq: String, session: String) -> [String: Any] {
        ["eventType": type, "timestamp": ts, "nrTestSeq": seq, "sessionId": session, "appVersion": "1.0"]
    }

    func testUploadWithoutRecoveredEventsHasNoCheck() {
        let c = dataCapture(at: 0, session: "S2", events: [live("NRTestCustom", ts: 1, seq: "a")])
        XCTAssertTrue(checks([c]).isEmpty)
    }

    func testRecoveredEventsPassAndNameTheirOriginatingSession() {
        let c = dataCapture(at: 0, session: "S2", events: [recovered("NRTestCustom", ts: 1, seq: "a", session: "S1")])
        let check = checks([c])[c.id]
        XCTAssertEqual(check?.passed, true)
        XCTAssertTrue(check?.detail?.contains("S1") == true)
    }

    func testRecoveredEventAlreadyDeliveredLiveInAnEarlierUploadFails() {
        let first = dataCapture(at: 0, session: "S1", events: [live("NRTestCustom", ts: 1, seq: "a")])
        let second = dataCapture(at: 30, session: "S2", events: [recovered("NRTestCustom", ts: 1, seq: "a", session: "S1")])
        XCTAssertEqual(checks([first, second])[second.id]?.passed, false)
    }

    func testRecoveredEventDeliveredTwiceAcrossUploadsFails() {
        let e = recovered("NRTestCustom", ts: 1, seq: "a", session: "S1")
        let first = dataCapture(at: 0, session: "S2", events: [e])
        let second = dataCapture(at: 30, session: "S2", events: [e])
        XCTAssertEqual(checks([first, second])[first.id]?.passed, true)
        XCTAssertEqual(checks([first, second])[second.id]?.passed, false)
    }

    func testDifferentEventsWithTheSameTimestampAreNotDuplicates() {
        let first = dataCapture(at: 0, session: "S1", events: [live("NRTestCustom", ts: 1, seq: "a")])
        let second = dataCapture(at: 30, session: "S2", events: [recovered("NRTestCustom", ts: 1, seq: "b", session: "S1")])
        XCTAssertEqual(checks([first, second])[second.id]?.passed, true)
    }
}

// MARK: - Capture server: persistence across launches

final class PersistedCaptureTests: XCTestCase {
    func testCaptureSurvivesEncodeDecodeWithLaunchAndBody() throws {
        var original = CapturedRequest(timestamp: Date(timeIntervalSinceReferenceDate: 5), endpoint: "/mobile/v3/data",
                                       headers: ["a": "b"], queryParams: [("k", "v")],
                                       decodedBody: Data([1, 2, 3]), prettyJSON: "{}")
        original.launch = 2
        let data = try JSONEncoder().encode([PersistedCapture(original)])
        let restored = try JSONDecoder().decode([PersistedCapture].self, from: data)[0].capture
        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.launch, 2)
        XCTAssertEqual(restored.decodedBody, Data([1, 2, 3]))
        XCTAssertEqual(restored.queryParams.first?.0, "k")
        XCTAssertEqual(restored.queryParams.first?.1, "v")
    }
}
