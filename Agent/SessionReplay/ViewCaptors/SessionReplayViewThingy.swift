//
//  NRMASessionReplayView.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 1/30/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit

protocol SessionReplayViewThingy: Hashable {
    var viewDetails: ViewDetails { get set }
    var shouldRecordSubviews: Bool { get }
    var isMasked: Bool { get set }
    var isBlocked: Bool { get set }

    var subviews: [any SessionReplayViewThingy] { get set }
    
    func cssDescription() -> String
    func generateRRWebNode() -> ElementNodeData
    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord]
    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord]
}

extension SessionReplayViewThingy {
    /// Determines if subviews should be recorded. Blocked views should not record their subviews.
    var shouldRecordSubviewsComputed: Bool {
        return shouldRecordSubviews && !isBlocked
    }

    func generateBaseCSSStyle() -> String {
        var cssStyle = """
            position: fixed; \
            left: \(String(format: "%.2f", self.viewDetails.frame.origin.x))px; \
            top: \(String(format: "%.2f", self.viewDetails.frame.origin.y))px; \
            width: \(String(format: "%.2f", self.viewDetails.frame.size.width))px; \
            height: \(String(format: "%.2f", self.viewDetails.frame.size.height))px;
            """

        // Enhanced corner radius handling for SwiftUI Lists
        let cornerRadiusCSS = generateCornerRadiusCSS()
        cssStyle.append(cornerRadiusCSS)

        // If the view is blocked, make it a solid black rectangle
        if self.isBlocked {
            cssStyle.append(" background-color: #000000 !important; opacity: 1.0 !important; overflow: hidden !important; z-index: 9999 !important;")
            return cssStyle
        }

        // Add opacity if it's not fully opaque
        if self.viewDetails.alpha < 1.0 {
            cssStyle.append(" opacity: \(String(format: "%.3f", self.viewDetails.alpha));")
        }

        if let backgroundColor = self.viewDetails.backgroundColor {
            let backgroundColorString = "background-color: \(backgroundColor.toHexString(includingAlpha: true));"
            cssStyle.append(backgroundColorString)
        }

        if let borderColor = self.viewDetails.borderColor,
           self.viewDetails.borderWidth > 0 {
            let borderString = """
            border: \(String(format: "%.2f", self.viewDetails.borderWidth))px \
            solid \(borderColor.toHexString(includingAlpha: true));
            """
            cssStyle.append(borderString)
        }

        return cssStyle
    }

    /// Generates appropriate corner radius CSS based on view type and context
    func generateCornerRadiusCSS() -> String {
        let radius = self.viewDetails.cornerRadius
        let viewName = self.viewDetails.viewName

        if radius <= 0 {
            return " border-radius: 0px;"
        }

        // Check if this is a SwiftUI List-related view that needs enhanced corner radius
        if isSwiftUIListRelatedView() {
            let enhancedCSS = generateEnhancedCornerRadiusCSS(radius: radius)
            return enhancedCSS
        }

        // Default uniform corner radius
        let defaultCSS = " border-radius: \(String(format: "%.2f", radius))px;"

        return defaultCSS
    }

    /// Detects if this view is related to SwiftUI List rendering
    private func isSwiftUIListRelatedView() -> Bool {
        let viewName = self.viewDetails.viewName
        return viewName.contains("ListCollectionViewCell") ||
               viewName.contains("SystemBackgroundView") ||
               viewName.contains("UICollectionViewListCell") ||
               viewName.contains("UIKitPlatformViewHost") ||
               viewName.contains("PlatformViewHost") ||
               viewName.contains("ListRepresentable") ||
               (viewName.contains("UIView") && isNestedInListCell())
    }

    /// Checks if this UIView is nested inside a ListCollectionViewCell
    private func isNestedInListCell() -> Bool {
        // More conservative detection - only return true for views we're confident are in Lists
        // For now, return false to avoid false positives - let the other detection methods handle it
        return false
    }

    /// Generates enhanced corner radius CSS for SwiftUI List-related views
    private func generateEnhancedCornerRadiusCSS(radius: CGFloat) -> String {
        let radiusStr = String(format: "%.2f", radius > 0 ? radius : 10.0)
        let viewName = self.viewDetails.viewName

        // For SwiftUI List inner views, determine the cell position and apply selective corner rounding
        if isListInnerView() {
            let selectiveCSS = generateSelectiveCornerRadiusCSS(radiusStr: radiusStr)

            return selectiveCSS
        }

        // For ListCollectionViewCell itself, use standard radius
        let standardCSS = " border-radius: \(radiusStr)px;"

        return standardCSS
    }

    /// Checks if this is an inner view within a List cell that should inherit corner radius
    private func isListInnerView() -> Bool {
        let viewName = self.viewDetails.viewName
        let cssSelector = self.viewDetails.cssSelector

        // Specific inner views that should get selective corner radius
        let isSystemBackgroundView = viewName.contains("SystemBackgroundView")
        let isPlatformViewHost = viewName.contains("UIKitPlatformViewHost") || viewName.contains("PlatformViewHost")
        let isGenericUIView = viewName.contains("UIView") &&
                              !viewName.contains("ListCollectionViewCell") &&
                              !viewName.contains("CollectionView") &&
                              !viewName.contains("ContentView")

        let result = isSystemBackgroundView || isPlatformViewHost || isGenericUIView

        return result
    }

    /// Generates selective corner radius CSS based on List cell position
    private func generateSelectiveCornerRadiusCSS(radiusStr: String) -> String {
        // For now, assume this is a first cell (top corners only)
        // TODO: This could be enhanced by detecting actual cell position in section

        // Based on your request: top-left and top-right corners only for first cell
        // Force override any inherited border-radius by explicitly setting all corners
        let selectiveCSS = " border-radius: 0px; border-top-left-radius: \(radiusStr)px; border-top-right-radius: \(radiusStr)px; border-bottom-left-radius: 0px !important; border-bottom-right-radius: 0px !important;"
        return selectiveCSS
    }

    /// Gets enhanced corner radius value for a view
    private func getEnhancedCornerRadius(_ radius: CGFloat) -> CGFloat {
        if radius > 0 {
            return radius
        }

        // For SwiftUI List inner views, provide default radius
        if isSwiftUIListRelatedView() && isListInnerView() {
            return 10.0
        }

        return radius
    }

    func generateBaseDifferences(from other: Self) -> [String:String] {
        // get style differences
        var styleDifferences = [String:String]()
        
        // check frames and corner radius
        if(!viewDetails.frame.equalTo(other.viewDetails.frame) || viewDetails.cornerRadius != other.viewDetails.cornerRadius) {
            styleDifferences["position"] = "fixed"
            styleDifferences["left"] = "\(String(format: "%.2f", other.viewDetails.frame.origin.x))px"
            styleDifferences["top"] = "\(String(format: "%.2f", other.viewDetails.frame.origin.y))px"
            styleDifferences["width"] = "\(String(format: "%.2f", other.viewDetails.frame.size.width))px"
            styleDifferences["height"] = "\(String(format: "%.2f", other.viewDetails.frame.size.height))px"

            // Handle corner radius differences - check if this needs selective corner radius
            let enhancedRadius = getEnhancedCornerRadius(other.viewDetails.cornerRadius)
            if isSwiftUIListRelatedView() && isListInnerView() {
                // For List inner views, use selective corner radius
                let radiusStr = String(format: "%.2f", enhancedRadius)
                styleDifferences["border-top-left-radius"] = "\(radiusStr)px"
                styleDifferences["border-top-right-radius"] = "\(radiusStr)px"
                styleDifferences["border-bottom-left-radius"] = "0px"
                styleDifferences["border-bottom-right-radius"] = "0px"
            } else {
                // Standard corner radius
                styleDifferences["border-radius"] = "\(String(format: "%.2f", enhancedRadius))px"
            }
        }

        // Check alpha/opacity changes
        if viewDetails.alpha != other.viewDetails.alpha {
            styleDifferences["opacity"] = "\(String(format: "%.3f", other.viewDetails.alpha))"
        }

        // background color
        if let otherBackgroundColor = other.viewDetails.backgroundColor {
            if let backgroundColor = viewDetails.backgroundColor,
               !(backgroundColor == otherBackgroundColor) {
                styleDifferences["background-color"] = "\(otherBackgroundColor.toHexString(includingAlpha: true))"
            }
        }
        
        // Border differences
        if let borderColor = other.viewDetails.borderColor,
           other.viewDetails.borderWidth > 0 {
            let borderString = "\(String(format: "%.2f", other.viewDetails.borderWidth))px solid \(borderColor.toHexString(includingAlpha: true))"
            styleDifferences["border"] = borderString
        }
        
        return styleDifferences
    }
}
