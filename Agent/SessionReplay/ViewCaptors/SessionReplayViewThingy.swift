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
    
    func inlineCSSDescription() -> String
    func generateRRWebNode() -> ElementNodeData
    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord]
    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord]
}

extension SessionReplayViewThingy {
    /// Determines if subviews should be recorded. Blocked views should not record their subviews.
    var shouldRecordSubviewsComputed: Bool {
        return shouldRecordSubviews && !isBlocked
    }

    func inlineCSSDescription() -> String {
        return generateBaseCSSStyle()
    }

    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        let node = generateRRWebNode()
        return [.init(parentId: parentNodeId, nextId: viewDetails.nextId, node: .element(node))]
    }

    func generateBaseCSSStyle() -> String {
        var cssStyle = """
            position: fixed; \
            left: \(String(format: "%.2f", self.viewDetails.frame.origin.x))px; \
            top: \(String(format: "%.2f", self.viewDetails.frame.origin.y))px; \
            width: \(String(format: "%.2f", self.viewDetails.frame.size.width))px; \
            height: \(String(format: "%.2f", self.viewDetails.frame.size.height))px; \
            border-radius: \(String(format: "%.2f", self.viewDetails.cornerRadius))px;
            """

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
    
    func generateBaseDifferences(from other: Self) -> [String:String] {
        // get style differences
        var styleDifferences = [String:String]()
        
        // check frames
        if(!viewDetails.frame.equalTo(other.viewDetails.frame)) {
            styleDifferences["position"] = "fixed"
            styleDifferences["left"] = "\(String(format: "%.2f", other.viewDetails.frame.origin.x))px"
            styleDifferences["top"] = "\(String(format: "%.2f", other.viewDetails.frame.origin.y))px"
            styleDifferences["width"] = "\(String(format: "%.2f", other.viewDetails.frame.size.width))px"
            styleDifferences["height"] = "\(String(format: "%.2f", other.viewDetails.frame.size.height))px"
            styleDifferences["border-radius"] = "\(String(format: "%.2f", other.viewDetails.cornerRadius))px"
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
