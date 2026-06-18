//
//  NRTestAppUITests.swift
//  NRTestAppUITests
//
//  Created by Chris Dillard on 10/17/23.
//

import XCTest


final class NRTestAppUITests: XCTestCase {
    
    let dataEndpoint = "/mobile/v3/data"

    func testARequests(){
        let dynamicStubs = HTTPDynamicStubs()

        let vendorId = "00000000-0000-0000-0000-000000000000"
        let harvestConnector = "[[\"NRTestApp\",\"4.7\",\"com.newrelic.NRApp.bitcode\"],[\"iOS\",\"27.0\",\"arm64\",\"iOSAgent\",\"DEV\",\"\(vendorId)\",\"\",\"\",\"Apple Inc.\",{\"platform\":\"Native\",\"platformVersion\":\"DEV\"}]]"

        let app = XCUIApplication()
        dynamicStubs.setUp()

// expectation: TEST HARVEST /connect
        let expectation = XCTestExpectation(description: "Expected connect endpoint to be hit.")
        
        
        dynamicStubs.setupStub(url: "/mobile/v5/connect", filename: "harvestConnector", method: .POST, matchRequestBody: harvestConnector, hitClosure: { actualRequestBody in
            if actualRequestBody == harvestConnector {
                expectation.fulfill() }
        })

        app.launchEnvironment = ["UITesting":"yes", "DeleteConnect":"yes"]
        app.launch()

        XCTWaiter(delegate: self).wait(for: [expectation], timeout: 30)
        app.terminate()

// expectation: TEST HARVEST /data
        let expectation2 = XCTestExpectation(description: "Expected data harvest endpoint to be hit.")

        dynamicStubs.setupStub(url: dataEndpoint, filename: "harvestCollector", method: .POST, matchRequestBody: harvestCollector, hitClosure: { actualRequestBody in

            let jsonMatch = dynamicStubs.dataToJSON(data: (self.harvestCollector.data(using: .utf8))!) as! Array<Any>
            let jsonActualArray = dynamicStubs.dataToJSON(data: actualRequestBody.data(using: .utf8)!) as! Array<Any>

            if jsonMatch.count == jsonActualArray.count {
                expectation2.fulfill()
            }
            else {
                XCTFail()
            }
        })

        app.launchEnvironment = ["UITesting":"yes"]
        app.launch()

        XCTWaiter(delegate: self).wait(for: [expectation2], timeout: 30)
        app.terminate()

        dynamicStubs.tearDown()
    }

    func testBRequests(){
        let dynamicStubs = HTTPDynamicStubs()

        let app = XCUIApplication()

        dynamicStubs.setUp()

// expectation: TEST HARVEST /data
        // The first expectation of this test is used for the automatically fired /data request when launching the app
        let expectation2 = XCTestExpectation(description: "Expected data harvest endpoint to be hit.")

        dynamicStubs.setupStub(url: dataEndpoint, filename: "harvestCollector", method: .POST, matchRequestBody: harvestCollector, hitClosure: { actualRequestBody in

            let jsonMatch = dynamicStubs.dataToJSON(data: (self.harvestCollector.data(using: .utf8))!) as! Array<Any>
            let jsonActualArray = dynamicStubs.dataToJSON(data: actualRequestBody.data(using: .utf8)!) as! Array<Any>

            if jsonMatch.count == jsonActualArray.count {
                expectation2.fulfill()
            }
            else {
                XCTFail()
            }
        })

        app.launchEnvironment = ["UITesting":"yes"]
        app.launch()
        
        XCTWaiter(delegate: self).wait(for: [expectation2], timeout: 30)

        let tables = app.tables
        if tables.staticTexts["Utilities"].waitForExistence(timeout: 15) {
            tables.staticTexts["Utilities"].tap()
            
            if tables.staticTexts["Notice Network Request"].waitForExistence(timeout: 15) {
                tables.staticTexts["Notice Network Request"].tap()
            }

        }
        // This expectation of this test is used for the automatically fired /data request when launching the app
// expectation: TEST HARVEST /data
        let expectation3 = XCTestExpectation(description: "Expected data harvest endpoint to be hit w/ MobileRequest.")

        dynamicStubs.setupStub(url: dataEndpoint, filename: "harvestCollector", method: .POST, matchRequestBody: harvestCollector, hitClosure: { actualRequestBody in

            //let jsonMatch = dynamicStubs.dataToJSON(data: (self.harvestCollector.data(using: .utf8))!) as! Array<Any>
            let jsonActualArray = dynamicStubs.dataToJSON(data: actualRequestBody.data(using: .utf8)!) as! Array<Any>
            var metricSeen = false
            if let urlArray = jsonActualArray[3] as? [NSObject] {
                for array in urlArray {
                    if let array = array as? [AnyObject] {
                        if let url = array[0] as? String  {
                            if url == "https://api.nasa.gov/planetary/apod" {
                                metricSeen = true
                                break
                            }
                        }
                    }
                }
            }

            // Get events array
            if let eventArray = jsonActualArray[9] as? [[String: Any]] {
                for event in eventArray {
                    if let eventType = event["eventType"] as? String {
                        if eventType == "MobileRequest" {
                            // If the metric was seen and we see an event with type == "MobileRequest" that means harvesting Network Requests is working.
                            if metricSeen {
                                expectation3.fulfill()
                                break
                            }
                        }
                    }
                }
            }
        })

        // Wait up to Max Event Buffer Time
        XCTWaiter(delegate: self).wait(for: [expectation3], timeout: 62)

        app.terminate()

        dynamicStubs.tearDown()
    }

    // Verifies the agent's HTTP 429 / rate-limit backoff handling end-to-end against the local mock
    // collector: when /data returns 429 with a Retry-After header, the agent must pause uploads for
    // the backoff window (rather than hammering the collector), then resume once the window expires
    // and the collector starts returning 200 again.
    func testRateLimitBackoffOn429() {
        let dynamicStubs = HTTPDynamicStubs()
        dynamicStubs.setUp()
        defer { dynamicStubs.tearDown() }

        // Shared, lock-guarded counter — Swifter serves requests off the main thread.
        let hitLock = NSLock()
        var dataHitCount = 0
        func recordDataHit() -> Int {
            hitLock.lock(); defer { hitLock.unlock() }
            dataHitCount += 1
            return dataHitCount
        }
        func currentDataHitCount() -> Int {
            hitLock.lock(); defer { hitLock.unlock() }
            return dataHitCount
        }

        // A short harvest period makes the backoff observable within a fast test. The connect
        // response drives the harvest timer (NRMAHarvestTimer reads data_report_period).
        let harvestPeriodSeconds = 5
        dynamicStubs.setupStub(url: "/mobile/v5/connect",
                               method: .POST,
                               statusCode: 200,
                               responseHeaders: ["Content-Type": "application/json"],
                               jsonBody: connectResponse(dataReportPeriodSeconds: harvestPeriodSeconds))

        // /data rate-limits the agent. Retry-After is longer than several harvest periods so the
        // backoff window straddles multiple ticks that the agent must skip.
        let retryAfterSeconds = 20
        let firstHit = XCTestExpectation(description: "agent POSTed to /data and received a 429")
        dynamicStubs.setupStub(url: dataEndpoint,
                               method: .POST,
                               statusCode: 429,
                               responseHeaders: ["Retry-After": "\(retryAfterSeconds)"],
                               jsonBody: [String: Any]()) { _ in
            _ = recordDataHit()
            firstHit.fulfill()
        }

        let app = XCUIApplication()
        app.launchEnvironment = ["UITesting": "yes", "DeleteConnect": "yes"]
        app.launch()

        // Generate some data worth harvesting.
        let tables = app.tables
        if tables.staticTexts["Utilities"].waitForExistence(timeout: 15) {
            tables.staticTexts["Utilities"].tap()
            
            if tables.staticTexts["Notice Network Request"].waitForExistence(timeout: 15) {
                tables.staticTexts["Notice Network Request"].tap()
            }

        }

        // The first /data POST should arrive within a couple of harvest periods and get a 429.
        XCTAssertEqual(XCTWaiter(delegate: self).wait(for: [firstHit], timeout: 30), .completed,
                       "Agent never POSTed to /data")

        // Observe across several harvest periods that fall inside the backoff window. Without backoff
        // the agent would re-POST every harvestPeriodSeconds; with backoff it must stay quiet.
        Thread.sleep(forTimeInterval: TimeInterval(harvestPeriodSeconds * 3))
        let countDuringBackoff = currentDataHitCount()
        XCTAssertEqual(countDuringBackoff, 1,
                       "Agent should pause /data uploads during the 429 backoff window, but posted \(countDuringBackoff) times")

        // Recovery: the collector stops rate-limiting. Once the backoff window expires the agent
        // should resume harvesting and a fresh /data POST should land.
        let recovered = XCTestExpectation(description: "agent resumed POSTing to /data after backoff")
        dynamicStubs.setupStub(url: dataEndpoint,
                               method: .POST,
                               statusCode: 200,
                               responseHeaders: ["Content-Type": "application/json"],
                               jsonBody: [String: Any]()) { _ in
            if recordDataHit() > 1 {
                recovered.fulfill()
            }
        }

        XCTAssertEqual(XCTWaiter(delegate: self).wait(for: [recovered], timeout: 40), .completed,
                       "Agent did not resume /data uploads after the rate-limit backoff window expired")

        app.terminate()
    }

    // Loads the canned connect response and overrides the harvest period so tests can speed up the
    // harvest loop. Falls back to a minimal valid configuration if the stub file can't be read.
    private func connectResponse(dataReportPeriodSeconds: Int) -> [String: Any] {
        let bundle = Bundle(for: HTTPDynamicStubs.self)
        var dict: [String: Any] = [:]
        if let path = bundle.path(forResource: "harvestConnector", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            dict = parsed
        }
        dict["data_report_period"] = dataReportPeriodSeconds
        return dict
    }

    let harvestCollector = "[[6665544329,6662343329],[\"iOS\",\"17.0\",\"arm64\",\"iOSAgent\",\"DEV\",\"myDeviceId\",\"\",\"\",\"Apple Inc.\",{\"platform\":\"Native\",\"platformVersion\":\"DEV\"}],0,[],[[{\"name\":\"Method\\/UIViewController\\/viewWillLayoutSubviews\",\"scope\":\"Mobile\\/Activity\\/Name\\/Display _TtGC7SwiftUI19UIHostingControllerGVS_15ModifiedContentVS_7AnyViewVS_12RootModifier__\"},{\"sum_of_squares\":0,\"min\":0,\"exclusive\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"CPU\\/System\\/Utilization\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"Session\\/Start\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"CPU\\/User\\/Utilization\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"Memory\\/Used\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"Method\\/UIViewController\\/viewWillLayoutSubviews\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"exclusive\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"CPU\\/Total\\/Utilization\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"count\":1,\"max\":0,\"total\":0}]],[],[],[],{},[]]"
}
