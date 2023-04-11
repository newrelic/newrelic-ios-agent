//
//  NRMAViewControllerTimeTrackerTests.swift
//  Agent
//
//  Created by Mike Bruin on 4/10/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

import Foundation
import XCTest
import UIKit

class FakeViewController: UIViewController {
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
}

class NRMAViewControllerTimeTrackerTests: XCTestCase {
    let vc = FakeViewController()
    var helper:NRMAMeasurementConsumerHelper?
    
    override func setUp() {
        NRMAMethodProfiler().startMethodReplacement()

        helper = NRMAMeasurementConsumerHelper.init(type: NRMAMT_NamedValue)

        NRMAMeasurements.initializeMeasurements()
        NRMAMeasurements.addMeasurementConsumer(helper)
        super.setUp()
    }
    
    override func tearDown() {
        NRMAMethodProfiler.resetskipInstrumentationOnceToken()
        NRMAMeasurements.removeMeasurementConsumer(helper)
        helper = nil;

        NRMAMeasurements.shutdown()
        
        super.tearDown()
    }
    
    // This test doesn't test much but is needed to get the NRMAMethodProfiler to work right. `\_(*-*)_/`
    func testANothing() {
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

    }
    
    func testViewControllerTimeMetric() {
        XCTAssertNoThrow(vc.viewDidAppear(false))
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        lookForViewTimeMetric()

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        XCTAssertNoThrow(vc.viewDidDisappear(false))
        lookForViewTimeMetric()
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        
        XCTAssertNoThrow(vc.viewDidAppear(false))

        XCTAssertNoThrow(vc.viewDidDisappear(false))
        lookForViewTimeMetric()
    }

    func lookForViewTimeMetric() {
        NRMATaskQueue.synchronousDequeue()
        let fullMetricName = "Mobile/Activity/Name/View_Time " + FakeViewController.description()
        var foundMeasurement: NRMANamedValueMeasurement?
        
        for case let measurement as NRMANamedValueMeasurement in helper!.consumedMeasurements {
            if measurement.name() == fullMetricName {
                foundMeasurement = measurement
                break
            }
        }
        
        XCTAssertNotNil(foundMeasurement)
        XCTAssertEqual(foundMeasurement?.name(), fullMetricName);
        helper?.consumedMeasurements.removeAllObjects()
    }
    
}
