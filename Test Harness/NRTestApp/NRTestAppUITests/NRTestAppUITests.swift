//
//  NRTestAppUITests.swift
//  NRTestAppUITests
//
//  Created by Chris Dillard on 10/17/23.
//

import XCTest


final class NRTestAppUITests: XCTestCase {

    func testConnectRequest(){
        let vendorId = "myDeviceId"
        let harvestConnector = "[[\"NRTestApp\",\"4.7\",\"com.newrelic.NRApp.bitcode\"],[\"iOS\",\"17.0\",\"arm64\",\"iOSAgent\",\"DEV\",\"\(vendorId)\",\"\",\"\",\"Apple Inc.\",{\"platform\":\"Native\",\"platformVersion\":\"DEV\"}]]"

        let app = XCUIApplication()
        let dynamicStubs = HTTPDynamicStubs()
        dynamicStubs.setUp()
        let expectation = XCTestExpectation(description: "Expected harvest endpoint to be hit.")

        dynamicStubs.setupStub(url: "/mobile/v4/connect", filename: "harvestConnector", method: .POST, matchRequestBody: harvestConnector, hitClosure: { actualRequestBody in
            if actualRequestBody == harvestConnector {
                expectation.fulfill() }
        })

        app.launchEnvironment = ["UITesting":"yes"]
        app.launch()

        XCTWaiter(delegate: self).wait(for: [expectation], timeout: 30)
        app.terminate()
    }
}
