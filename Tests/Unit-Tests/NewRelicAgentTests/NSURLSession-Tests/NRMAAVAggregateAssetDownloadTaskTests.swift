//
//  NRMAAVAggregateAssetDownloadTaskTests.swift
//  Agent_Tests
//
//  Created by Mike Bruin on 4/3/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

import Foundation
import AVKit
import XCTest

@available(iOS 11.0, *)
class NRMAAVAggregateAssetDownloadTaskTests: XCTestCase {
    
    var helper: NRMAMeasurementConsumerHelper?
    var assetDownloadURLSession: AVAssetDownloadURLSession!
    
    override func setUp() {
        super.setUp()
        
        NRMAURLSessionOverride.beginInstrumentation()
        
        helper = NRMAMeasurementConsumerHelper(type: NRMAMT_HTTPTransaction)
        NRMAMeasurements.initializeMeasurements()
        NRMAMeasurements.addMeasurementConsumer(helper)
        
        let backgroundConfiguration = URLSessionConfiguration.background(withIdentifier: "NRMA-Identifier")

        assetDownloadURLSession = AVAssetDownloadURLSession(configuration: backgroundConfiguration, assetDownloadDelegate: nil, delegateQueue: OperationQueue.main)
    }
    
    override func tearDown() {
        NRMAURLSessionOverride.deinstrument()
        
        NRMAMeasurements.removeMeasurementConsumer(helper)
        NRMAMeasurements.shutdown()
        
        helper = nil
        
        super.tearDown()
    }
    
    func testAggregateAssetDownloadTask() {
        let urlAsset = AVURLAsset(url: URL(string: "http://www.google.com")!)
        let preferredMediaSelection = urlAsset.preferredMediaSelection

        guard let task = assetDownloadURLSession.aggregateAssetDownloadTask(with: urlAsset,
                                                               mediaSelections: [preferredMediaSelection],
                                                               assetTitle: "Test Asset",
                                                               assetArtworkData: nil,
                                                               options:
                [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 265_000]) else { return }

        task.taskDescription = "Test Asset"

        task.resume()
        
        sleep(1)
        
        let result = helper?.result as? NRMAHTTPTransactionMeasurement

        XCTAssertEqual(result?.url, "http://www.google.com")
    }
}
