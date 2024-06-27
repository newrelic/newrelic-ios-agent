//
//  NRTestApp__watchOS__AppTests.swift
//  NRTestApp (watchOS) AppTests
//
//  Created by Mike Bruin on 5/8/24.
//

import XCTest

final class NRTestApp__watchOS__AppTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
    
    func testUtilities() throws {
        //Navigate through the app and make sure all screens load properly
        let app = XCUIApplication()
        app.launch()
                        
        for cell in app.collectionViews.cells.allElementsBoundByIndex {
            if !cell.staticTexts["Crash Now!"].exists {
                cell.tap()
                sleep(1)
            }
        }
        
        app.terminate()
        app.launch()
    }
}
