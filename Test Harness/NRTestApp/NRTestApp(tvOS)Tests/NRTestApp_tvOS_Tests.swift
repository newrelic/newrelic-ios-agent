//
//  NRTestApp_tvOS_Tests.swift
//  NRTestApp(tvOS)Tests
//
//  Created by Mike Bruin on 9/1/23.
//

import XCTest

final class NRTestApp_tvOS_Tests: XCTestCase {

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
    
    func testSetMaxEventPoolSize(){
        var i = 0
        let app = XCUIApplication()
        //max event pool size was set to 10 in app delegate
        while i <= 10 {
            app.launch()
            app.terminate()
            i += 1
        }
        XCTAssertNoThrow(app.launch(), "An event after max pool has been reached should not cause crash")
    }
    
    func testNavigation() throws {
        //Navigate through the app and make sure all screens load properly
        let app = XCUIApplication()
        app.launch()
        
        XCUIRemote.shared.press(.select)
        XCUIRemote.shared.press(.menu)

        sleep(1)
        XCUIRemote.shared.press(.down)
        sleep(1)
        XCUIRemote.shared.press(.select)

        sleep(1)
        XCUIRemote.shared.press(.down)
        sleep(1)
        XCUIRemote.shared.press(.select)
        sleep(1)
        app.terminate()
    }
    
    func testUtilities() throws {
        //Navigate through the app and make sure all screens load properly
        let app = XCUIApplication()
        app.launch()
        
        let crashCell = app.tables.cells.staticTexts["Crash Now!"]
        
        XCUIRemote.shared.press(.select)
        
        for cell in app.tables.cells.allElementsBoundByIndex {
            if !cell.staticTexts["Crash Now!"].exists {
                XCUIRemote.shared.press(.select)
            }
            XCUIRemote.shared.press(.down)
        }
        
        app.terminate()
        app.launch()
    }
}

