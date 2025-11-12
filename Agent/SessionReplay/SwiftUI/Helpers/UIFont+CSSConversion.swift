//
//  UIFont+CSSConversion.swift
//  Agent
//
//  Created by Mike Bruin on 10/28/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit

internal extension UIFont {

    // Fonts are ordered: 1) Most accurate visual match, 2) Most universally available
    private static let fontFamilyMap: [String: String] = [
        "sfui": "-apple-system, system-ui",
        "applesystemuifont": "-apple-system, system-ui",
        "sf pro text": "-apple-system, system-ui",
        "sf pro display": "-apple-system, system-ui",
        "sf pro": "-apple-system, system-ui",
        "sfprotext": "-apple-system, system-ui",
        "sfprodisplay": "-apple-system, system-ui",
        "sf compact": "-apple-system, system-ui",
        "sfcompact": "-apple-system, system-ui",
        
        "new york": "Charter, Georgia",
        "newyork": "Charter, Georgia"
    ]
    
    private static let prefixPatterns: [(String, String)] = [
        ("applesystemuifont", "-apple-system, system-ui"),  // Most common iOS font
        ("sfui", "-apple-system, system-ui"),
        ("sfpro", "-apple-system, system-ui"),
        ("sf pro", "-apple-system, system-ui"),
        ("helvetica", "Helvetica, Arial"),
        ("arial", "Arial, sans-serif"),
        ("avenir", "Avenir, Arial")
    ]
    
    /// Converts an Apple font family name to a CSS-compatible font family
    /// - Parameter fontFamily: The UIFont familyName
    /// - Returns: A CSS-compatible font family name
    static func convertToCSSFontFamily(_ fontFamily: String) -> String {
        // Remove leading dot if present (Apple's system font indicator)
        let cleanedFamily = fontFamily.hasPrefix(".") && fontFamily.count > 1
            ? String(fontFamily.dropFirst())
            : fontFamily
        
        let lowercasedFamily = cleanedFamily.lowercased()
        
        if let cssFont = fontFamilyMap[lowercasedFamily] {
            return cssFont
        }

        for (prefix, cssFont) in prefixPatterns {
            if lowercasedFamily.hasPrefix(prefix) {
                return cssFont
            }
        }
        
        // For unknown fonts, quote the name if it contains spaces and provide fallbacks
        if cleanedFamily.contains(" ") {
            return "'\(cleanedFamily)', system-ui"
        } else {
            return "\(cleanedFamily), system-ui"
        }
    }
    
    /// Converts the current UIFont instance to a CSS font family string
    /// - Returns: A CSS-compatible font family name
    func toCSSFontFamily() -> String {
        return UIFont.convertToCSSFontFamily(self.familyName)
    }
}
