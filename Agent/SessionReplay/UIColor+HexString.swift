//
//  UIColor+HexString.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 3/15/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit

internal extension UIColor {
    func toHexString(includingAlpha: Bool) -> String {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        
        // Use getRed instead of directly accessing cgColor.components for thread safety
        // and automatic color space conversion
        var didExtract = self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // If getRed fails (e.g., non-sRGB color space, pattern colors),
        // convert to sRGB and retry before falling back to transparent.
        if !didExtract,
           let srgbSpace = CGColorSpace(name: CGColorSpace.sRGB),
           let srgb = self.cgColor.converted(to: srgbSpace, intent: .defaultIntent, options: nil) {
            didExtract = UIColor(cgColor: srgb).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        }

        if didExtract {
            // Clamp values to 0-1 range to handle extended sRGB colors
            red = max(0.0, min(1.0, red))
            green = max(0.0, min(1.0, green))
            blue = max(0.0, min(1.0, blue))
            alpha = max(0.0, min(1.0, alpha))

            let multiplier = CGFloat(255.999999)

            let hexRed = String(format: "%02x", Int(red * multiplier))
            let hexGreen = String(format: "%02x", Int(green * multiplier))
            let hexBlue = String(format: "%02x", Int(blue * multiplier))
            let hexAlpha = includingAlpha ? String(format: "%02x", Int(alpha * multiplier)) : ""

            let colorString = "#\(hexRed)\(hexGreen)\(hexBlue)\(hexAlpha)"

            return colorString.uppercased()
        }

        // Fallback if getRed fails (e.g., pattern-based colors)
        // Return a default transparent color
        return includingAlpha ? "#00000000" : "#000000"
    }
}

internal extension CGColor {
    func toHexString(includingAlpha: Bool) -> String {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        
        let multiplier = CGFloat(255.999999)
        
        // Convert to sRGB if needed to normalize the color space
        let effectiveColor: CGColor
        if let srgbSpace = CGColorSpace(name: CGColorSpace.sRGB),
           self.colorSpace != srgbSpace,
           let converted = self.converted(to: srgbSpace, intent: .defaultIntent, options: nil) {
            effectiveColor = converted
        } else {
            effectiveColor = self
        }

        guard let components = effectiveColor.components, effectiveColor.numberOfComponents >= 2 else {
            // Return default color if components are unavailable
            return includingAlpha ? "#00000000" : "#000000"
        }

        if effectiveColor.numberOfComponents == 2 {
            // Grayscale color space
            red = components[0]
            green = components[0]
            blue = components[0]
            alpha = components[1]
        } else if effectiveColor.numberOfComponents >= 4 {
            // RGB color space
            red = components[0]
            green = components[1]
            blue = components[2]
            alpha = components[3]
        } else {
            // Unexpected number of components, return default
            return includingAlpha ? "#00000000" : "#000000"
        }
        
        // Clamp values to 0-1 range to handle extended color spaces
        red = max(0.0, min(1.0, red))
        green = max(0.0, min(1.0, green))
        blue = max(0.0, min(1.0, blue))
        alpha = max(0.0, min(1.0, alpha))
        
        let hexRed = String(format: "%02x", Int(red * multiplier))
        let hexGreen = String(format: "%02x", Int(green * multiplier))
        let hexBlue = String(format: "%02x", Int(blue * multiplier))
        let hexAlpha = includingAlpha ? String(format: "%02x", Int(alpha * multiplier)) : ""
        
        let colorString = "#\(hexRed)\(hexGreen)\(hexBlue)\(hexAlpha)"
        
        return colorString.uppercased()
    }
}
