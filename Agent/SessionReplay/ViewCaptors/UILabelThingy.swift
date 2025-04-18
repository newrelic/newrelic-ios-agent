//
//  UILabelThingy.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 2/5/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit

class UILabelThingy: SessionReplayViewThingy {
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
        return """
                #\(viewDetails.cssSelector) { \
                \(generateBaseCSSStyle())\
                white-space: pre-wrap;\
                font: \(String(format: "%.2f", self.fontSize))px \(self.fontFamily); \
                color: \(textColor.toHexString(includingAlpha: true));\
                } 
                """
    }
    
    func generateRRWebNode() -> ElementNodeData  {
        let textNode = SerializedNode.text(TextNodeData(id: IDGenerator.shared.getId(),
                                                        isStyle: false,
                                                        textContent: labelText,
                                                        childNodes: []))
        
        return ElementNodeData(id: viewDetails.viewId,
                                        tagName: .div,
                                        attributes: ["id":viewDetails.cssSelector],
                                        childNodes: [textNode])
    }
    
    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? UILabelThingy else {
            return []
        }
        
        var mutations = [MutationRecord]()
        var frameDifferences = generateBaseDifferences(from: typedOther)
        
        // get text color difference
        if textColor != typedOther.textColor {
            frameDifferences["color"] = typedOther.textColor.toHexString(includingAlpha: true)
        }
        
        let attributeRecord = RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: frameDifferences)
        mutations.append(attributeRecord)
        
        if(self.labelText != typedOther.self.labelText) {
            let textRecord = RRWebMutationData.TextRecord(id: viewDetails.viewId, value: typedOther.labelText)
            mutations.append(textRecord)
        }
        
        return mutations
    }
}

extension UILabelThingy: Equatable {
    static func == (lhs: UILabelThingy, rhs: UILabelThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails &&
            lhs.labelText == rhs.labelText &&
            lhs.fontSize == rhs.fontSize &&
            lhs.fontName == rhs.fontName &&
            lhs.fontFamily == rhs.fontFamily &&
            lhs.textColor == rhs.textColor
    }
}

extension UILabelThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
        hasher.combine(labelText)
        hasher.combine(fontSize)
        hasher.combine(fontName)
        hasher.combine(fontFamily)
        hasher.combine(textColor)
    }
}
