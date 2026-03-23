//
//  CornerRadiusExtractor.swift
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import SwiftUI
import UIKit

@available(iOS 13.0, tvOS 13.0, *)
struct CornerRadiusExtractor {

    /// Analyzes a SwiftUI.Path to detect if it represents a rounded rectangle and extracts corner radius
    static func extractCornerRadius(from path: SwiftUI.Path) -> CGFloat? {
        let cgPath = path.cgPath
        var arcCount = 0
        var arcRadius: CGFloat = 0
        var pathElements: [CGPathElement] = []

        // Collect all path elements
        cgPath.applyWithBlock { elementPtr in
            pathElements.append(elementPtr.pointee)
        }

        // Analyze path structure for rounded rectangle pattern
        for element in pathElements {
            switch element.type {
            case .addCurveToPoint:
                // Curved corners typically use cubic curves
                arcCount += 1
                if arcCount == 1 {
                    // Calculate approximate corner radius from first curve
                    let control1 = element.points[0]
                    let control2 = element.points[1]
                    let end = element.points[2]

                    // Simple heuristic: distance between control points suggests corner radius
                    let deltaX = abs(control2.x - control1.x)
                    let deltaY = abs(control2.y - control1.y)
                    arcRadius = max(deltaX, deltaY)
                }

            case .addQuadCurveToPoint:
                // Some rounded rectangles use quadratic curves
                arcCount += 1
                if arcCount == 1 {
                    let control = element.points[0]
                    let end = element.points[1]

                    // Approximate radius from control point offset
                    let deltaX = abs(end.x - control.x)
                    let deltaY = abs(end.y - control.y)
                    arcRadius = min(deltaX, deltaY)
                }

            default:
                break
            }
        }

        // If we found 4 or more curves (typical for rounded rect), return radius
        if arcCount >= 4 && arcRadius > 0 {
            return arcRadius
        }

        return nil
    }

    /// Maps SwiftUI component types to their default system corner radius values
    static func getDefaultCornerRadius(for componentName: String) -> CGFloat {
        let iosVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion

        // iOS version-aware defaults
        let defaults: [String: CGFloat] = [
            // List Components
            "List": iosVersion >= 15 ? 12.0 : 10.0,
            "NavigationLink": 10.0,
            "Section": 12.0,

            // Buttons & Controls
            "Button": 10.0,
            "Toggle": 16.0,  // Pill-shaped
            "Picker": 10.0,
            "Stepper": 8.0,

            // Input Controls
            "TextField": 10.0,
            "TextEditor": 12.0,
            "SearchBar": 12.0,

            // Containers
            "GroupBox": 12.0,
            "Form": 12.0,

            // Generic SwiftUI container types (no default radius)
            "VStack": 0.0,
            "HStack": 0.0,
            "ZStack": 0.0,
            "ScrollView": 0.0,

            // SwiftUI system views that commonly have corner radius
            "SwiftUITextView": 0.0,      // Text doesn't have default corners
            "SwiftUIColorView": 0.0,     // Plain color backgrounds don't have corners
            "SwiftUIShapeView": 0.0      // Shapes define their own corners
        ]

        return defaults[componentName] ?? 0.0
    }

    /// Detects common SwiftUI component patterns from view name and suggests corner radius
    static func detectComponentType(from viewName: String) -> CGFloat {
        // Clean up the view name for pattern matching
        let cleanName = viewName
            .replacingOccurrences(of: "SwiftUI", with: "")
            .replacingOccurrences(of: "View", with: "")

        // Pattern matching for component detection
        if cleanName.contains("List") {
            return getDefaultCornerRadius(for: "List")
        } else if cleanName.contains("Navigation") || cleanName.contains("Link") {
            return getDefaultCornerRadius(for: "NavigationLink")
        } else if cleanName.contains("Button") {
            return getDefaultCornerRadius(for: "Button")
        } else if cleanName.contains("Toggle") {
            return getDefaultCornerRadius(for: "Toggle")
        } else if cleanName.contains("Text") && (cleanName.contains("Field") || cleanName.contains("Editor")) {
            return cleanName.contains("Field") ?
                getDefaultCornerRadius(for: "TextField") :
                getDefaultCornerRadius(for: "TextEditor")
        } else if cleanName.contains("Picker") {
            return getDefaultCornerRadius(for: "Picker")
        } else if cleanName.contains("Group") {
            return getDefaultCornerRadius(for: "GroupBox")
        }

        return 0.0
    }
}
