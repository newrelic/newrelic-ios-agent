//
//  UILabelThingy.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 2/5/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit

struct UILabelThingy: SessionReplayViewThingy {
    var subviews = [any SessionReplayViewThingy]()
    
    var shouldRecordSubviews: Bool {
        false
    }
    
    let viewDetails: ViewDetails
    
    let labelText: String
    let fontSize: CGFloat
    let fontName: String
    let fontFamily: String
    let textColor: UIColor
    
    init(view: UILabel, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        self.labelText = view.text ?? ""
        self.fontSize = view.font.pointSize
        let fontNameRaw = view.font.fontName
        if(fontNameRaw .hasPrefix(".") && fontNameRaw.count > 1) {
            self.fontName = String(fontNameRaw.dropFirst())
        } else {
            self.fontName = fontNameRaw
        }
        
        let fontFamilyRaw = view.font.familyName
        if(fontFamilyRaw.hasPrefix(".") && fontFamilyRaw.count > 1) {
            self.fontFamily = String(fontFamilyRaw.dropFirst())
        } else {
            self.fontFamily = fontFamilyRaw
        }
        
        self.textColor = view.textColor
    }
    
    func cssDescription() -> String {
        let cssSelector = viewDetails.cssSelector
//        var cssStyle = generateBaseCSSStyle()
        
        return """
#\(viewDetails.cssSelector) { \
\(generateBaseCSSStyle())\
white-space: pre-wrap;\
font: \(String(format: "%.2f", self.fontSize))px \(self.fontFamily); \
color: \(textColor.toHexString(includingAlpha: true));\
} 
"""
    }
    
    func generateRRWebNode() -> RRWebElementNode  {
        let textNode = RRWebTextNode(id: IDGenerator.shared.getId(),
                                     textContent: labelText,
                                     isStyle: false)
        
        return RRWebElementNode(id: viewDetails.viewId,
                                tagName: .div,
                                attributes: ["id":viewDetails.cssSelector],
                                childNodes: [textNode])
    }
}
