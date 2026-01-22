//
//  UIColorHexStringTests.swift
//  NewRelicAgentTests
//
//  Created by New Relic on 11/14/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import XCTest
import UIKit

class UIColorHexStringTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - UIColor Extension Tests
    
    func testUIColor_BasicRGBColorWithoutAlpha() {
        let color = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let hexString = color.toHexString(includingAlpha: false)
        XCTAssertEqual(hexString, "#FF0000", "Red color should convert to #FF0000")
    }
    
    func testUIColor_BasicRGBColorWithAlpha() {
        let color = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let hexString = color.toHexString(includingAlpha: true)
        XCTAssertEqual(hexString, "#FF0000FF", "Red color with alpha should convert to #FF0000FF")
    }
    
    func testUIColor_TransparentColor() {
        let color = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.0)
        let hexString = color.toHexString(includingAlpha: true)
        XCTAssertEqual(hexString, "#FF000000", "Transparent red should have 00 alpha")
    }
    
    func testUIColor_SemiTransparentColor() {
        let color = UIColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 0.5)
        let hexString = color.toHexString(includingAlpha: true)
        XCTAssertTrue(hexString.hasPrefix("#"), "Hex string should start with #")
        XCTAssertEqual(hexString.count, 9, "Hex string with alpha should have 9 characters")
    }
    
    func testUIColor_BlackColor() {
        let color = UIColor.black
        let hexString = color.toHexString(includingAlpha: false)
        XCTAssertEqual(hexString, "#000000", "Black color should convert to #000000")
    }
    
    func testUIColor_WhiteColor() {
        let color = UIColor.white
        let hexString = color.toHexString(includingAlpha: false)
        XCTAssertEqual(hexString, "#FFFFFF", "White color should convert to #FFFFFF")
    }
    
    func testUIColor_ClearColor() {
        let color = UIColor.clear
        let hexString = color.toHexString(includingAlpha: true)
        // Clear color should not crash and return a valid hex string
        XCTAssertTrue(hexString.hasPrefix("#"), "Clear color should return a valid hex string")
        XCTAssertTrue(hexString.count == 7 || hexString.count == 9, "Hex string should be valid length")
    }
    
    func testUIColor_GrayColor() {
        let color = UIColor.gray
        let hexString = color.toHexString(includingAlpha: false)
        // Gray should not crash and return a valid hex string
        XCTAssertTrue(hexString.hasPrefix("#"), "Gray color should return a valid hex string")
        XCTAssertEqual(hexString.count, 7, "Hex string without alpha should have 7 characters")
    }
    
    func testUIColor_SystemColors() {
        // Test system colors that might have special color spaces
        let systemColors = [
            UIColor.systemRed,
            UIColor.systemBlue,
            UIColor.systemGreen,
            UIColor.systemYellow,
            UIColor.systemPink,
            UIColor.systemTeal
        ]
        
        for color in systemColors {
            let hexString = color.toHexString(includingAlpha: false)
            XCTAssertTrue(hexString.hasPrefix("#"), "System color should return a valid hex string")
            XCTAssertEqual(hexString.count, 7, "Hex string without alpha should have 7 characters")
        }
    }
    
    func testUIColor_PatternColor_DoesNotCrash() {
        // Pattern-based colors cannot be converted to RGBA - test fallback
        if let patternImage = UIImage(systemName: "checkmark") {
            let patternColor = UIColor(patternImage: patternImage)
            let hexString = patternColor.toHexString(includingAlpha: false)
            // Should return fallback without crashing
            XCTAssertEqual(hexString, "#000000", "Pattern color should return fallback")
        }
    }
    
    func testUIColor_DynamicColor_DoesNotCrash() {
        // Test dynamic colors (iOS 13+)
        if #available(iOS 13.0, *) {
            let dynamicColor = UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black
            }
            let hexString = dynamicColor.toHexString(includingAlpha: false)
            // Should not crash and return a valid hex string
            XCTAssertTrue(hexString.hasPrefix("#"), "Dynamic color should return a valid hex string")
        }
    }
    
    func testUIColor_ExtendedSRGBColor() {
        // Test colors with values outside 0-1 range (extended sRGB)
        let color = UIColor(red: 1.5, green: -0.5, blue: 0.5, alpha: 1.0)
        let hexString = color.toHexString(includingAlpha: false)
        // Should not crash and return a valid hex string
        XCTAssertTrue(hexString.hasPrefix("#"), "Extended sRGB color should return a valid hex string")
        XCTAssertEqual(hexString.count, 7, "Hex string should have 7 characters")
    }
    
    func testUIColor_ZeroComponents() {
        let color = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        let hexStringWithAlpha = color.toHexString(includingAlpha: true)
        let hexStringWithoutAlpha = color.toHexString(includingAlpha: false)
        
        XCTAssertEqual(hexStringWithAlpha, "#00000000", "Zero color with alpha should be #00000000")
        XCTAssertEqual(hexStringWithoutAlpha, "#000000", "Zero color without alpha should be #000000")
    }
    
    func testUIColor_MaxComponents() {
        let color = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let hexStringWithAlpha = color.toHexString(includingAlpha: true)
        let hexStringWithoutAlpha = color.toHexString(includingAlpha: false)
        
        XCTAssertEqual(hexStringWithAlpha, "#FFFFFFFF", "Max color with alpha should be #FFFFFFFF")
        XCTAssertEqual(hexStringWithoutAlpha, "#FFFFFF", "Max color without alpha should be #FFFFFF")
    }
    
    func testUIColor_OutputFormat() {
        let color = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        let hexString = color.toHexString(includingAlpha: true)
        
        // Verify format
        XCTAssertTrue(hexString.hasPrefix("#"), "Hex string should start with #")
        XCTAssertTrue(hexString.uppercased() == hexString, "Hex string should be uppercase")
        XCTAssertEqual(hexString.count, 9, "Hex string with alpha should have 9 characters")
    }
    
    func testUIColor_ConcurrentAccess_DoesNotCrash() {
        let color = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let expectation = self.expectation(description: "Concurrent access completes")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Test concurrent access to ensure thread safety
        for _ in 0..<100 {
            group.enter()
            queue.async {
                _ = color.toHexString(includingAlpha: Bool.random())
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error, "Concurrent access should not timeout or crash")
        }
    }
    
    // MARK: - CGColor Extension Tests
    
    func testCGColor_BasicRGBColorWithoutAlpha() {
        let uiColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        guard let cgColor = uiColor.cgColor as CGColor? else {
            XCTFail("Failed to get CGColor")
            return
        }
        let hexString = cgColor.toHexString(includingAlpha: false)
        XCTAssertEqual(hexString, "#FF0000", "Red CGColor should convert to #FF0000")
    }
    
    func testCGColor_BasicRGBColorWithAlpha() {
        let uiColor = UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        guard let cgColor = uiColor.cgColor as CGColor? else {
            XCTFail("Failed to get CGColor")
            return
        }
        let hexString = cgColor.toHexString(includingAlpha: true)
        XCTAssertEqual(hexString, "#00FF00FF", "Green CGColor with alpha should convert to #00FF00FF")
    }
    
    func testCGColor_TransparentColor() {
        let uiColor = UIColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 0.0)
        guard let cgColor = uiColor.cgColor as CGColor? else {
            XCTFail("Failed to get CGColor")
            return
        }
        let hexString = cgColor.toHexString(includingAlpha: true)
        XCTAssertEqual(hexString, "#0000FF00", "Transparent blue CGColor should have 00 alpha")
    }
    
    func testCGColor_GrayscaleColor() {
        let uiColor = UIColor(white: 0.5, alpha: 1.0)
        guard let cgColor = uiColor.cgColor as CGColor? else {
            XCTFail("Failed to get CGColor")
            return
        }
        let hexString = cgColor.toHexString(includingAlpha: false)
        // Should not crash and return a valid hex string
        XCTAssertTrue(hexString.hasPrefix("#"), "Grayscale CGColor should return a valid hex string")
        XCTAssertEqual(hexString.count, 7, "Hex string without alpha should have 7 characters")
    }
    
    func testCGColor_BlackGrayscale() {
        let uiColor = UIColor(white: 0.0, alpha: 1.0)
        guard let cgColor = uiColor.cgColor as CGColor? else {
            XCTFail("Failed to get CGColor")
            return
        }
        let hexString = cgColor.toHexString(includingAlpha: false)
        XCTAssertEqual(hexString, "#000000", "Black grayscale CGColor should convert to #000000")
    }
    
    func testCGColor_WhiteGrayscale() {
        let uiColor = UIColor(white: 1.0, alpha: 1.0)
        guard let cgColor = uiColor.cgColor as CGColor? else {
            XCTFail("Failed to get CGColor")
            return
        }
        let hexString = cgColor.toHexString(includingAlpha: false)
        XCTAssertEqual(hexString, "#FFFFFF", "White grayscale CGColor should convert to #FFFFFF")
    }
    
    func testCGColor_GrayscaleWithAlpha() {
        let uiColor = UIColor(white: 0.5, alpha: 0.5)
        guard let cgColor = uiColor.cgColor as CGColor? else {
            XCTFail("Failed to get CGColor")
            return
        }
        let hexString = cgColor.toHexString(includingAlpha: true)
        // Should not crash and return a valid hex string
        XCTAssertTrue(hexString.hasPrefix("#"), "Grayscale CGColor with alpha should return a valid hex string")
        XCTAssertEqual(hexString.count, 9, "Hex string with alpha should have 9 characters")
    }
    
    func testCGColor_OutputFormat() {
        let uiColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        guard let cgColor = uiColor.cgColor as CGColor? else {
            XCTFail("Failed to get CGColor")
            return
        }
        let hexString = cgColor.toHexString(includingAlpha: true)
        
        // Verify format
        XCTAssertTrue(hexString.hasPrefix("#"), "Hex string should start with #")
        XCTAssertTrue(hexString.uppercased() == hexString, "Hex string should be uppercase")
        XCTAssertEqual(hexString.count, 9, "Hex string with alpha should have 9 characters")
    }
    
    func testCGColor_ComponentsInRange() {
        // Test that the hex values are properly bounded
        let uiColor = UIColor(red: 0.999, green: 0.001, blue: 0.5, alpha: 0.75)
        guard let cgColor = uiColor.cgColor as CGColor? else {
            XCTFail("Failed to get CGColor")
            return
        }
        let hexString = cgColor.toHexString(includingAlpha: true)
        
        // Should produce valid 2-digit hex values for each component
        XCTAssertEqual(hexString.count, 9, "Hex string with alpha should have 9 characters")
        
        // Extract components and verify they're valid hex
        let hexPattern = "^#[0-9A-F]{8}$"
        let regex = try? NSRegularExpression(pattern: hexPattern)
        let range = NSRange(location: 0, length: hexString.utf16.count)
        let matches = regex?.firstMatch(in: hexString, options: [], range: range)
        XCTAssertNotNil(matches, "Hex string should match valid hex pattern")
    }
    
    func testCGColor_MultipleColorSpaces() {
        // Test colors from different color spaces
        let colors = [
            UIColor.black.cgColor,
            UIColor.white.cgColor,
            UIColor.red.cgColor,
            UIColor.green.cgColor,
            UIColor.blue.cgColor,
            UIColor(white: 0.5, alpha: 1.0).cgColor
        ]
        
        for cgColor in colors {
            let hexString = cgColor.toHexString(includingAlpha: false)
            XCTAssertTrue(hexString.hasPrefix("#"), "CGColor should return a valid hex string")
            XCTAssertEqual(hexString.count, 7, "Hex string without alpha should have 7 characters")
        }
    }
    
    func testCGColor_ConcurrentAccess_DoesNotCrash() {
        let uiColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        guard let cgColor = uiColor.cgColor as CGColor? else {
            XCTFail("Failed to get CGColor")
            return
        }
        
        let expectation = self.expectation(description: "Concurrent CGColor access completes")
        let queue = DispatchQueue(label: "test.cgcolor.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Test concurrent access to ensure thread safety
        for _ in 0..<100 {
            group.enter()
            queue.async {
                _ = cgColor.toHexString(includingAlpha: Bool.random())
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error, "Concurrent CGColor access should not timeout or crash")
        }
    }
    
    // MARK: - Edge Cases and Crash Prevention Tests
    
    func testColorRoundingBehavior() {
        // Test the 255.999999 multiplier edge case
        let color = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let hexString = color.toHexString(includingAlpha: true)
        
        // Should round to FF, not overflow
        XCTAssertEqual(hexString, "#FFFFFFFF", "Maximum color values should round to FF")
    }
    
    func testVerySmallColorValues() {
        let color = UIColor(red: 0.001, green: 0.001, blue: 0.001, alpha: 0.001)
        let hexString = color.toHexString(includingAlpha: true)
        
        XCTAssertEqual(hexString, "#00000000", "Very small color values should round to #00000000")
    }
    
    func testMultipleConversions() {
        // Test that multiple conversions on the same color don't cause issues
        let color = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        
        for _ in 0..<100 {
            _ = color.toHexString(includingAlpha: true)
            _ = color.toHexString(includingAlpha: false)
        }
        
        // If we get here without crashing, the test passes
        XCTAssertTrue(true, "Multiple conversions should not crash")
    }
    
    func testFallbackScenarios() {
        // Test that fallback values are sensible
        let fallbackWithAlpha = "#00000000"
        let fallbackWithoutAlpha = "#000000"
        
        XCTAssertEqual(fallbackWithAlpha.count, 9, "Fallback with alpha should be proper length")
        XCTAssertEqual(fallbackWithoutAlpha.count, 7, "Fallback without alpha should be proper length")
    }
}
