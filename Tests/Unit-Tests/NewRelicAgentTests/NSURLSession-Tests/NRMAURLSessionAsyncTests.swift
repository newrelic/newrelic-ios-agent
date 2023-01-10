//
//  NRMAURLSessionAsyncTests.swift
//  NewRelicAgent
//
//  Created by Chris Dillard on 12/5/22.
//  Copyright © 2023 New Relic. All rights reserved.
//

import Foundation
import XCTest

// Async/Await URLSession bindings are only available in iOS,tvOS 13+
@available(iOS 13.0, tvOS 13.0, *)
class NRMAURLSessionAsyncTests: XCTestCase {

    var helper: NRMAMeasurementConsumerHelper?
    var session: URLSession!

    override func setUp() async throws {
        try super.setUpWithError()

        NRMAURLSessionOverride.beginInstrumentation()

        helper = NRMAMeasurementConsumerHelper(type: NRMAMT_HTTPTransaction)
        NRMAMeasurements.initializeMeasurements()
        NRMAMeasurements.addMeasurementConsumer(helper)
    }
    
    override func tearDown() async throws {
        NRMAURLSessionOverride.deinstrument()

        NRMAMeasurements.removeMeasurementConsumer(helper)
        NRMAMeasurements.shutdown()

        helper = nil

        try super.tearDownWithError()
    }

    func testAsyncURLSessionDataForRequest() async throws {
        let request = URLRequest(url: URL(string: "http://www.google.com")!)
        let (_, _) = try await URLSession.shared.data(for: request)

        sleep(1)

        let result = helper?.result as? NRMAHTTPTransactionMeasurement

        XCTAssertEqual(result?.url, "http://www.google.com")
    }

    func testAsyncURLSessionDataForURL() async throws {
        let (_, _) = try await  URLSession.shared.data(from: URL(string: "http://www.google.com")!)

        sleep(1)

        let result = helper?.result as? NRMAHTTPTransactionMeasurement

        XCTAssertEqual(result?.url, "http://www.google.com")
    }

    func testAsyncURLSessionUploadForRequest() async throws {
        let request = URLRequest(url: URL(string: "http://www.google.com")!)
        let (_, _) = try await URLSession.shared.upload(for: request, from: Data())

        sleep(1)

        let result = helper?.result as? NRMAHTTPTransactionMeasurement

        XCTAssertEqual(result?.url, "http://www.google.com")
    }
}
