//
//  NRMASessionReplayView.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 1/30/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

protocol SessionReplayViewThingy {
    var viewDetails: ViewDetails { get }
    var shouldRecordSubviews: Bool { get }
    
    func jsonDescription() -> Dictionary<String,Any>
    func cssDescription() -> String
}

extension SessionReplayViewThingy {
    func generateBaseJSONDescription() -> [String: Any] {
        [
            "type": 2,
            "tagName": "div",
            "attributes": [
                "id": viewDetails.cssSelector
            ],
            "childNodes": [String: Any](),
            "id": viewDetails.viewId
        ] as [String : Any]
    }
    
    func generateBaseCSSStyle() -> String {
        var cssStyle = """
            position: fixed; \
            left: \(String(format: "%.2f", self.viewDetails.frame.origin.x))px; \
            top: \(String(format: "%.2f", self.viewDetails.frame.origin.y))px; \
            width: \(String(format: "%.2f", self.viewDetails.frame.size.width))px; \
            height: \(String(format: "%.2f", self.viewDetails.frame.size.height))px;
            """
        
        if let backgroundColor = self.viewDetails.backgroundColor {
            let backgroundColorString = "background-color: \(backgroundColor.toHexString(includingAlpha: true))"
            cssStyle.append(backgroundColorString)
        }
        
        if let borderColor = self.viewDetails.borderColor,
           self.viewDetails.borderWidth > 0 {
            let borderString = """
                border-radius: \(String(format: "%.2f", self.viewDetails.cornerRadius))px; \
                border: \(String(format: "%.2f", self.viewDetails.borderWidth))px; \
                solid \(borderColor.toHexString(includingAlpha: true))
            """
            cssStyle.append(borderString)
        }
        
        return cssStyle
    }
}
