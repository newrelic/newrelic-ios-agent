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
}
