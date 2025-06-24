//
//  NRMASessionReplayView.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 1/30/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

protocol SessionReplayViewThingy: Hashable {
    var viewDetails: ViewDetails { get }
    var shouldRecordSubviews: Bool { get }
    var isMasked: Bool { get set }

    var subviews: [any SessionReplayViewThingy] { get set }
    
    func cssDescription() -> String
    func generateRRWebNode() -> ElementNodeData
    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord]
}

extension SessionReplayViewThingy {    
    func generateBaseCSSStyle() -> String {
        var cssStyle = """
            position: fixed; \
            left: \(String(format: "%.2f", self.viewDetails.frame.origin.x))px; \
            top: \(String(format: "%.2f", self.viewDetails.frame.origin.y))px; \
            width: \(String(format: "%.2f", self.viewDetails.frame.size.width))px; \
            height: \(String(format: "%.2f", self.viewDetails.frame.size.height))px;
            """
        
        if let backgroundColor = self.viewDetails.backgroundColor {
            let backgroundColorString = "background-color: \(backgroundColor.toHexString(includingAlpha: true));"
            cssStyle.append(backgroundColorString)
        }
        
        if let borderColor = self.viewDetails.borderColor,
           self.viewDetails.borderWidth > 0 {
            let borderString = """
            border-radius: \(String(format: "%.2f", self.viewDetails.cornerRadius))px; \
            border: \(String(format: "%.2f", self.viewDetails.borderWidth))px \
            solid \(borderColor.toHexString(includingAlpha: true))
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
            styleDifferences["left"] = "\(String(format: "%.2f", other.viewDetails.frame.origin.x))px"
            styleDifferences["top"] = "\(String(format: "%.2f", other.viewDetails.frame.origin.y))px"
            styleDifferences["width"] = "\(String(format: "%.2f", other.viewDetails.frame.size.width))px"
            styleDifferences["height"] = "\(String(format: "%.2f", other.viewDetails.frame.size.height))px"
        }
        
        // background color
        if let otherBackgroundColor = other.viewDetails.backgroundColor {
            if let backgroundColor = viewDetails.backgroundColor,
               !(backgroundColor == otherBackgroundColor) {
                styleDifferences["background-color: \(otherBackgroundColor.toHexString(includingAlpha: true))"]
            }
        }
        
        return styleDifferences
    }
}
