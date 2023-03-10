//
//  NRTestAppNavigationTests.swift
//  NRTestAppTests
//
//  Created by Mike Bruin on 1/27/23.
//

import XCTest
@testable import NRTestApp

final class NRTestAppUITests: XCTestCase {
    
    var mainCoordinator: MainCoordinator!


    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        mainCoordinator = MainCoordinator(navigationController: UINavigationController())
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        try super.setUpWithError()
        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        mainCoordinator = nil
        try super.tearDownWithError()
    }
    
    func testNavigation() throws {
                
        mainCoordinator.start()
        sleep(2)
        
        mainCoordinator.showUtilitiesViewController()
        sleep(2)
        
        mainCoordinator.showWebViewController()
        sleep(2)
        
        mainCoordinator.showImageViewController(image: UIImage())
        sleep(2)
    }
    
}
