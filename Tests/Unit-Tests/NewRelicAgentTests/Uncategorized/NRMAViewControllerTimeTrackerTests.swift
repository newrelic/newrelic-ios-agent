//
//  NRMAViewControllerTimeTrackerTests.swift
//  Agent
//
//  Created by Mike Bruin on 4/10/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

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

// These tests will not run on there own, they need the method profiling that gets setup in earlier tests.
class NRMAViewControllerTimeTrackerTests: XCTestCase {
    var helper:NRMAMeasurementConsumerHelper?
    var fullMetricName = "Mobile/Activity/Name/View_Time " + FakeViewController.description()
    
    override func setUp() {
        helper = NRMAMeasurementConsumerHelper.init(type: NRMAMT_NamedValue)

        NRMAMeasurements.initializeMeasurements()
        NRMAMeasurements.addMeasurementConsumer(helper)

        super.setUp()
    }
    
    override func tearDown() {
        NRMAMeasurements.removeMeasurementConsumer(helper)
        helper = nil;

        NRMAMeasurements.shutdown()

        super.tearDown()
    }
    
    func testViewControllerTimeMetricToBackground() {
        let vc = FakeViewController()

        vc.beginAppearanceTransition(true, animated: false)
        vc.endAppearanceTransition()
        
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        let foundMeasurement = lookForViewTimeMetric()
        XCTAssertNotNil(foundMeasurement)
        XCTAssertEqual(foundMeasurement?.name(), fullMetricName);
    }
    
    func testViewControllerTimeMetricFromBackgroundToForground() {
        let vc = FakeViewController()

        vc.beginAppearanceTransition(true, animated: false)
        vc.endAppearanceTransition()
        
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        var foundMeasurement = lookForViewTimeMetric()
        XCTAssertNotNil(foundMeasurement)
        XCTAssertEqual(foundMeasurement?.name(), fullMetricName);
        
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        vc.viewDidDisappear(false)
        
        foundMeasurement = lookForViewTimeMetric()
        XCTAssertNotNil(foundMeasurement)
        XCTAssertEqual(foundMeasurement?.name(), fullMetricName);
    }
    
    func testViewControllerTimeMetricNormal() {
        let vc = FakeViewController()
        
        vc.beginAppearanceTransition(true, animated: false)
        vc.endAppearanceTransition()

        vc.viewDidDisappear(false)
        
        let foundMeasurement = lookForViewTimeMetric()
        XCTAssertNotNil(foundMeasurement)
        XCTAssertEqual(foundMeasurement?.name(), fullMetricName);
    }

    func lookForViewTimeMetric() -> NRMANamedValueMeasurement? {
        NRMATaskQueue.synchronousDequeue()
        var foundMeasurement: NRMANamedValueMeasurement?
        
        for case let measurement as NRMANamedValueMeasurement in helper!.consumedMeasurements {
            if measurement.name() == fullMetricName {
                foundMeasurement = measurement
                break
            }
        }
        return foundMeasurement
    }
    
}
