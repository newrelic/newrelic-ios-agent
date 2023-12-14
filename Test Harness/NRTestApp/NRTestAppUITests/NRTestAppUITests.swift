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

        let vendorId = "myDeviceId"
        let harvestConnector = "[[\"NRTestApp\",\"4.7\",\"com.newrelic.NRApp.bitcode\"],[\"iOS\",\"17.0\",\"arm64\",\"iOSAgent\",\"DEV\",\"\(vendorId)\",\"\",\"\",\"Apple Inc.\",{\"platform\":\"Native\",\"platformVersion\":\"DEV\"}]]"

        let app = XCUIApplication()
        dynamicStubs.setUp()

// expectation: TEST HARVEST /connect
        let expectation = XCTestExpectation(description: "Expected connect endpoint to be hit.")

        dynamicStubs.setupStub(url: "/mobile/v4/connect", filename: "harvestConnector", method: .POST, matchRequestBody: harvestConnector, hitClosure: { actualRequestBody in
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

        let tablesQuery = app.tables
        tablesQuery.staticTexts["Change Image"].tap()

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

    let harvestCollector = "[[6665544329,6662343329],[\"iOS\",\"17.0\",\"arm64\",\"iOSAgent\",\"DEV\",\"myDeviceId\",\"\",\"\",\"Apple Inc.\",{\"platform\":\"Native\",\"platformVersion\":\"DEV\"}],0,[],[[{\"name\":\"Method\\/UIViewController\\/viewWillLayoutSubviews\",\"scope\":\"Mobile\\/Activity\\/Name\\/Display _TtGC7SwiftUI19UIHostingControllerGVS_15ModifiedContentVS_7AnyViewVS_12RootModifier__\"},{\"sum_of_squares\":0,\"min\":0,\"exclusive\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"CPU\\/System\\/Utilization\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"Session\\/Start\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"CPU\\/User\\/Utilization\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"Memory\\/Used\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"Method\\/UIViewController\\/viewWillLayoutSubviews\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"exclusive\":0,\"count\":1,\"max\":0,\"total\":0}],[{\"name\":\"CPU\\/Total\\/Utilization\",\"scope\":\"\"},{\"sum_of_squares\":0,\"min\":0,\"count\":1,\"max\":0,\"total\":0}]],[],[],[],{},[]]"
}
