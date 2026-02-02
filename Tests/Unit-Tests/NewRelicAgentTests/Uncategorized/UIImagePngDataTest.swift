//
//  UIImagePngDataTest.swift
//  NewRelicAgentTests
//
//  Created by Mike Bruin on 12/11/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import XCTest
import UIKit

class UIImagePngDataTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testZeroSizeImageReturnsNil() {
        let zeroSizeImage = UIImage()
        let data = zeroSizeImage.optimizedPngData()
        XCTAssertNil(data, "Should return nil for zero-sized image")
    }

    func testNonZeroSizeImageReturnsData() {
        UIGraphicsBeginImageContext(CGSize(width: 10, height: 10))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        let data = image?.optimizedPngData()
        XCTAssertNotNil(data, "Should return PNG data for non-zero-sized image")
    }
}
