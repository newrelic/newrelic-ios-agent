//
//  UITextFieldThingy.swift
//  Agent_iOS
//
//  Created by Chris Dillard on 6/13/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit
@_implementationOnly import NewRelicPrivate

class UITextFieldThingy: SessionReplayViewThingy {
    var isMasked: Bool
    var isBlocked: Bool

    var subviews = [any SessionReplayViewThingy]()
    
    var shouldRecordSubviews: Bool {
        true
    }
    
    var viewDetails: ViewDetails
    
    let labelText: String
    let fontSize: CGFloat
    let fontName: String
    let fontFamily: String
    
    let textColor: UIColor
    
    init(view: UITextField, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails

        if view.isSecureTextEntry {
            self.isMasked = true
        }
        else if let isMasked = viewDetails.isMasked {
            self.isMasked = isMasked
        }
        else if let maskUserInputText = viewDetails.maskUserInputText {
            self.isMasked = maskUserInputText
        }
        else {
            self.isMasked = NRMAHarvestController.configuration()?.session_replay_maskUserInputText ?? true
        }

        self.isBlocked = viewDetails.blockView ?? false

        if self.isMasked {
            // If the view is masked, we should not record the text.
            // instead replace it with the number of asterisks as were characters in label
            self.labelText = String(repeating: "*", count: view.text?.count ?? 0)
        }
        else {
            self.labelText = view.text ?? ""
        }

        // If the view is not a UITextField, we should not be here.
        let font = view.font ?? UIFont.systemFont(ofSize: 17.0)

        self.fontSize = font.pointSize
        let fontNameRaw = font.fontName
        if(fontNameRaw .hasPrefix(".") && fontNameRaw.count > 1) {
            self.fontName = String(fontNameRaw.dropFirst())
        }
        else {
            self.fontName = fontNameRaw
        }
        
        let fontFamilyRaw = font.familyName
        if(fontFamilyRaw.hasPrefix(".") && fontFamilyRaw.count > 1) {
            self.fontFamily = String(fontFamilyRaw.dropFirst())
        }
        else {
            self.fontFamily = fontFamilyRaw
        }
        
        if #available(iOS 13.0, *) {
            self.textColor = view.textColor ?? UIColor.label
        }
        else {
            // Fallback on earlier versions
            self.textColor = view.textColor ?? UIColor.black
        }

    }
    
    func inlineCSSDescription() -> String {
        return generateBaseCSSStyle()
//                """
//                \(generateBaseCSSStyle())\
//                white-space: pre-wrap;\
//                font: \(String(format: "%.2f", self.fontSize))px \(self.fontFamily); \
//                color: \(textColor.toHexString(includingAlpha: true));
//                """
    }

    func generateRRWebNode() -> ElementNodeData  {
        return ElementNodeData(id: viewDetails.viewId,
                               tagName: .div,
                               attributes: ["id": viewDetails.cssSelector,
                                            "style": inlineCSSDescription()],
                               childNodes: [])
    }

    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? UITextFieldThingy else {
            return []
        }
        
        var mutations = [MutationRecord]()
        var allAttributes = [String: String]()
        
        allAttributes["style"] = typedOther.inlineCSSDescription()
        
        if !allAttributes.isEmpty {
            let attributeRecord = RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: allAttributes)
            mutations.append(attributeRecord)
        }
        
        return mutations
    }
}

extension UITextFieldThingy: Equatable {
    static func == (lhs: UITextFieldThingy, rhs: UITextFieldThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails
//            lhs.labelText == rhs.labelText &&
//            lhs.fontSize == rhs.fontSize &&
//            lhs.fontName == rhs.fontName &&
//            lhs.fontFamily == rhs.fontFamily &&
//            lhs.textColor == rhs.textColor
    }
}

extension UITextFieldThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
        hasher.combine(labelText)
        hasher.combine(fontSize)
        hasher.combine(fontName)
        hasher.combine(fontFamily)
        hasher.combine(textColor)
    }
}
