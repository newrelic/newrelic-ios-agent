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
        } else if cleanName.contains("Button") || cleanName.contains("Control") || cleanName.contains("Touch") {
            // SwiftUI buttons might appear as Control, Touch, or other internal names
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
        } else if cleanName.contains("Shape") || cleanName.contains("Rectangle") {
            // Many SwiftUI buttons are rendered as shapes
            return getDefaultCornerRadius(for: "Button")
        }

        return 0.0
    }

    /// Analyzes a SwiftUI content type and suggests appropriate corner radius
    static func detectCornerRadiusFromContent(contentType: String, parentViewName: String) -> CGFloat {
        // For SwiftUI buttons that appear as shapes or platform views,
        // check if the parent context suggests it's a button
        if contentType.contains("shape") || contentType.contains("color") {
            if parentViewName.contains("Button") || parentViewName.contains("Touch") || parentViewName.contains("Control") {
                return getDefaultCornerRadius(for: "Button")
            }
        }

        return 0.0
    }


    /// Enhanced UIKit component detection - provides fallback defaults when no explicit corner radius
    static func detectUIKitComponentType(view: UIView) -> CGFloat {
        let className = String(describing: type(of: view))

        // SwiftUI List cells - these need special handling for sectioned corner radius
        if className.contains("ListCollectionViewCell") {
            return detectSwiftUIListCellCornerRadius(view: view)
        }

        // Collection view cells
        if className.contains("CollectionViewCell") {
            return 8.0
        }

        // Table view cells
        if className.contains("TableViewCell") {
            return 10.0
        }

        // System background views in Lists
        if className.contains("SystemBackgroundView") {
            return detectSystemBackgroundViewCornerRadius(view: view)
        }

        // UIKitPlatformViewHost in Lists (SwiftUI -> UIKit bridging)
        if className.contains("UIKitPlatformViewHost") || className.contains("PlatformViewHost") {
            return detectPlatformViewHostCornerRadius(view: view)
        }

        // Buttons
        if className.contains("Button") {
            return 8.0
        }

        // Text fields
        if className.contains("TextField") || className.contains("TextInput") {
            return 8.0
        }

        // Image views that might have rounded corners
        if className.contains("ImageView") {
            return 4.0
        }

        // Views with common corner radius patterns
        if className.contains("Card") || className.contains("Container") {
            return 12.0
        }

        return 0.0
    }

    /// Detects corner radius for SwiftUI List cells based on position in section
    static func detectSwiftUIListCellCornerRadius(view: UIView) -> CGFloat {
        // SwiftUI List cells should have 10px corner radius for sectioned lists
        // The system automatically handles which corners to round based on position
        return 10.0
    }

    /// Detects corner radius for system background views (often inside List cells)
    static func detectSystemBackgroundViewCornerRadius(view: UIView) -> CGFloat {
        // Check if this is inside a List structure
        if isInsideSwiftUIList(view: view) {
            return 10.0
        }
        return 0.0
    }

    /// Detects corner radius for UIKitPlatformViewHost (SwiftUI-UIKit bridging views)
    static func detectPlatformViewHostCornerRadius(view: UIView) -> CGFloat {
        if isInsideSwiftUIList(view: view) {
            return 10.0
        }
        return 0.0
    }

    /// Helper to detect if a view is inside a SwiftUI List
    static func isInsideSwiftUIList(view: UIView) -> Bool {
        var currentView: UIView? = view.superview
        while currentView != nil {
            let className = String(describing: type(of: currentView!))

            // Enhanced List detection including all SwiftUI List-related classes
            if className.contains("ListCollectionViewCell") ||
               className.contains("UICollectionView") ||
               className.contains("ListCellContentView") ||
               className.contains("UICollectionViewListCell") ||
               className.contains("ListRepresentable") ||
               className.contains("CollectionView") {
                return true
            }
            currentView = currentView?.superview
        }
        return false
    }

    /// Detects the position of a view within a SwiftUI List section for selective corner rounding
    static func detectListCellPosition(view: UIView) -> ListCellPosition {
        // For now, we'll detect based on the view hierarchy and naming patterns
        var currentView: UIView? = view.superview

        while currentView != nil {
            let className = String(describing: type(of: currentView!))

            // Look for ListCollectionViewCell which contains position information
            if className.contains("ListCollectionViewCell") {
                // For now, assume this is a first cell (top corners) - this could be enhanced
                // by analyzing the cell's position in the collection view
                return .first
            }

            currentView = currentView?.superview
        }

        return .middle // Default to middle (no corners)
    }

    /// Represents the position of a cell within a List section
    enum ListCellPosition {
        case first      // Top corners rounded
        case middle     // No corners rounded
        case last       // Bottom corners rounded
        case single     // All corners rounded
    }
}
