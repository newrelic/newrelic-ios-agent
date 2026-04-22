//
//  UILabelThingy.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 2/5/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit
@_implementationOnly import NewRelicPrivate

let RCTParagraphComponentView = "RCTParagraphComponentView"

class UILabelThingy: SessionReplayViewThingy {
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
    let textAlignment: String
    let fontFamily: String
    let textColor: UIColor
    let numberOfLines: Int
    let lineBreakMode: NSLineBreakMode
    let fontWeight: UIFont.Weight
    let isItalic: Bool
    let letterSpacing: CGFloat?

    let widthOffset = 1.0
    init(view: UILabel, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        var frame = self.viewDetails.frame
        frame.size.width = frame.size.width + widthOffset
        self.viewDetails.frame = frame

        if let isMasked = viewDetails.isMasked {
            self.isMasked = isMasked
        }
        else if let maskApplicationText = viewDetails.maskApplicationText {
            self.isMasked = maskApplicationText
        }
        else {
            self.isMasked = NRMAHarvestController.configuration()?.session_replay_maskApplicationText ?? true
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

        // Try to extract properties from attributed text first, then fall back to view properties
        let font: UIFont
        let textColor: UIColor
        let textAlignment: String
        let lineBreakMode: NSLineBreakMode
        let letterSpacing: CGFloat?

        if let attributedText = view.attributedText, attributedText.length > 0 {
            // Extract from attributed text
            let extracted = TextHelper.extractLabelAttributes(from: attributedText)
            font = extracted.font
            textColor = extracted.textColor
            textAlignment = extracted.textAlignment
            lineBreakMode = extracted.lineBreakMode
            letterSpacing = extracted.kern
        } else {
            // Fall back to view properties
            font = view.font ?? UIFont.systemFont(ofSize: 17.0)
            textColor = view.textColor
            textAlignment = view.textAlignment.stringValue()
            lineBreakMode = view.lineBreakMode
            letterSpacing = nil
        }

        self.fontSize = font.pointSize
        let fontNameRaw = font.fontName
        if(fontNameRaw.hasPrefix(".") && fontNameRaw.count > 1) {
            self.fontName = String(fontNameRaw.dropFirst())
        }
        else {
            self.fontName = fontNameRaw
        }

        self.fontFamily = font.toCSSFontFamily()
        self.textAlignment = textAlignment
        self.textColor = textColor
        self.numberOfLines = view.numberOfLines
        self.lineBreakMode = lineBreakMode

        let fontTraits = TextHelper.extractFontTraits(from: font)
        self.fontWeight = fontTraits.weight
        self.isItalic = fontTraits.isItalic
        self.letterSpacing = letterSpacing
    }

    init(view: UIView, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        var frame = self.viewDetails.frame
        frame.size.width = frame.size.width + widthOffset
        self.viewDetails.frame = frame
        
        var text: String?
        var textAlignment = "left"
        var font: UIFont = UIFont.systemFont(ofSize: 17.0)
        var textColor: UIColor = .black
        var lineBreakMode: NSLineBreakMode = .byWordWrapping
        var kern : CGFloat? = nil
        
        if let rctParagraphClass = NSClassFromString(RCTParagraphComponentView),
                  view.isKind(of: rctParagraphClass) {
            if view.responds(to: Selector(("attributedText"))) {
                if let attributedText = view.value(forKey: "attributedText") as? NSAttributedString {
                    let extracted = TextHelper.extractLabelAttributes(from: attributedText)
                    text = extracted.text
                    font = extracted.font
                    textColor = extracted.textColor
                    textAlignment = extracted.textAlignment
                    lineBreakMode = extracted.lineBreakMode
                    kern = extracted.kern
                }
            }
        }

        if let isMasked = viewDetails.isMasked {
            self.isMasked = isMasked
        } else if let maskApplicationText = viewDetails.maskApplicationText {
            self.isMasked = maskApplicationText
        } else {
            self.isMasked = NRMAHarvestController.configuration()?.session_replay_maskApplicationText ?? true
        }

        self.isBlocked = viewDetails.blockView ?? false

        if self.isMasked {
            // If the view is masked, we should not record the text.
            // instead replace it with the number of asterisks as were characters in label
            self.labelText = String(repeating: "*", count: text?.count ?? 0)
        }
        else {
            self.labelText = text ?? ""
        }
        
        self.fontSize = font.pointSize
        let fontNameRaw = font.fontName
        if(fontNameRaw .hasPrefix(".") && fontNameRaw.count > 1) {
            self.fontName = String(fontNameRaw.dropFirst())
        } else {
            self.fontName = fontNameRaw
        }
        
        self.fontFamily = font.toCSSFontFamily()
        
        self.textAlignment = textAlignment

        self.textColor = textColor

        // React Native views typically support multiline by default
        self.numberOfLines = 0
        self.lineBreakMode = lineBreakMode

        let fontTraits = TextHelper.extractFontTraits(from: font)
        self.fontWeight = fontTraits.weight
        self.isItalic = fontTraits.isItalic

        self.letterSpacing = kern

    }

    init(viewDetails: ViewDetails, attributedText: NSAttributedString, iOS15Override: Bool = false) {
        self.viewDetails = viewDetails
        self.viewDetails.backgroundColor = .clear
        var frame = self.viewDetails.frame
        frame.size.width = frame.size.width + widthOffset
        self.viewDetails.frame = frame

        let extracted = TextHelper.extractLabelAttributes(from: attributedText)
        let text = extracted.text
        let font = extracted.font
        let textColor = extracted.textColor
        let textAlignment = extracted.textAlignment
        let lineBreakMode = extracted.lineBreakMode
        let kern = extracted.kern
        
        if let isMasked = viewDetails.isMasked {
            self.isMasked = isMasked
        }
        else if let maskApplicationText = viewDetails.maskApplicationText {
            self.isMasked = maskApplicationText
        }
        else {
            self.isMasked = NRMAHarvestController.configuration()?.session_replay_maskApplicationText ?? true
        }
        
        if iOS15Override || self.isMasked {
            // If the view is masked, we should not record the text.
            // instead replace it with the number of asterisks as were characters in label
            self.labelText = String(repeating: "*", count: text?.count ?? 0)
        }
        else {
            self.labelText = text ?? ""
        }
        
        self.fontSize = font.pointSize
        let fontNameRaw = font.fontName
        if(fontNameRaw .hasPrefix(".") && fontNameRaw.count > 1) {
            self.fontName = String(fontNameRaw.dropFirst())
        } else {
            self.fontName = fontNameRaw
        }
        
        self.fontFamily = font.toCSSFontFamily()
        
        self.textAlignment = textAlignment

        self.textColor = textColor

        // SwiftUI text views typically support multiline by default
        self.numberOfLines = 0
        self.lineBreakMode = lineBreakMode

        let fontTraits = TextHelper.extractFontTraits(from: font)
        self.fontWeight = fontTraits.weight
        self.isItalic = fontTraits.isItalic
        self.letterSpacing = kern
     
        self.isBlocked = viewDetails.blockView ?? false
    }

    func inlineCSSDescription() -> String {
        let wordWrapCSS = TextHelper.generateWordWrapCSS(numberOfLines: numberOfLines, lineBreakMode: lineBreakMode)
        let fontWeightCSS = TextHelper.cssValueForFontWeight(fontWeight)
        let fontStyleCSS = isItalic ? "italic" : "normal"

        // Generate letter-spacing CSS if available
        var letterSpacingCSS = ""
        if let letterSpacing = self.letterSpacing {
            letterSpacingCSS = " letter-spacing: \(String(format: "%.2f", letterSpacing))px;"
        }

        return """
                \(generateBaseCSSStyle())\
                white-space: pre-wrap;\
                \(wordWrapCSS) \
                font: \(fontStyleCSS) \(fontWeightCSS) \(String(format: "%.2f", self.fontSize))px \(self.fontFamily); \
                color: \(textColor.toHexString(includingAlpha: true));\
                text-align: \(textAlignment); \
                overflow: hidden; \(letterSpacingCSS)
                """
    }

    func generateRRWebNode() -> ElementNodeData  {
        let textNode = SerializedNode.text(TextNodeData(id: IDGenerator.shared.getId(),
                                                        isStyle: false,
                                                        textContent: labelText,
                                                        childNodes: []))

        return ElementNodeData(id: viewDetails.viewId,
                               tagName: .div,
                               attributes: ["id": viewDetails.cssSelector,
                                            "style": inlineCSSDescription()],
                               childNodes: [textNode])
    }

    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? UILabelThingy else {
            return []
        }
        var mutations = [MutationRecord]()
        var allAttributes = [String: String]()
        
        allAttributes["style"] = typedOther.inlineCSSDescription()
        
        if !allAttributes.isEmpty {
            let attributeRecord = RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: allAttributes)
            mutations.append(attributeRecord)
        }
        
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
            lhs.textAlignment == rhs.textAlignment &&
            lhs.textColor == rhs.textColor &&
            lhs.numberOfLines == rhs.numberOfLines &&
            lhs.lineBreakMode == rhs.lineBreakMode &&
            lhs.fontWeight == rhs.fontWeight &&
            lhs.isItalic == rhs.isItalic &&
            lhs.letterSpacing == rhs.letterSpacing
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
        hasher.combine(numberOfLines)
        hasher.combine(lineBreakMode.rawValue)
        hasher.combine(fontWeight.rawValue)
        hasher.combine(isItalic)
        hasher.combine(letterSpacing)
    }
}

internal extension NSTextAlignment {
    func stringValue() -> String {
        switch self {
        case .left: return "left"
        case .center: return "center"
        case .right: return "right"
        case .justified: return "justify"
        case .natural: return "start"
        @unknown default: return "left"
        }
    }
}
