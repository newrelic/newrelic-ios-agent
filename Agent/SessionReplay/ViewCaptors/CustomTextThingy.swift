//
//  CustomTextThingy.swift
//  Agent
//
//  Created by Mike Bruin on 7/29/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit
@_implementationOnly import NewRelicPrivate

class CustomTextThingy: SessionReplayViewThingy {
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
    let textAlignment: String
    let fontWeight: UIFont.Weight
    let isItalic: Bool
    let numberOfLines: Int
    let lineBreakMode: NSLineBreakMode
    let letterSpacing: CGFloat?
    let textColor: UIColor

    init(view: UITextField, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        
        if let identifier = view.sessionReplayCustomTextIDKey {
            self.viewDetails.viewId = identifier
        }
        else {
            self.viewDetails.viewId = IDGenerator.shared.getId()
            view.sessionReplayCustomTextIDKey = self.viewDetails.viewId
        }
        
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
            textColor = view.textColor ?? UIColor.label
            textAlignment = view.textAlignment.stringValue()
            lineBreakMode = .byClipping
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
        self.numberOfLines = 1
        self.lineBreakMode = lineBreakMode

        let fontTraits = TextHelper.extractFontTraits(from: font)
        self.fontWeight = fontTraits.weight
        self.isItalic = fontTraits.isItalic
        self.letterSpacing = letterSpacing
        
        if let actualTextBounds = CustomTextThingy.getActualTextBounds(textField: view, text: self.labelText, font: font, letterSpacing: letterSpacing) {
            self.viewDetails.frame = actualTextBounds
        }

    }

    static func getActualTextBounds(textField: UITextField, text: String, font: UIFont, letterSpacing: CGFloat?) -> CGRect? {
        // Get the text rect area from the text field
        let textRect = textField.textRect(forBounds: textField.bounds)

        // Calculate actual text size with all attributes
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        if let letterSpacing = letterSpacing {
            attributes[.kern] = letterSpacing
        }
        var textSize = (text as NSString).size(withAttributes: attributes)
        textSize.width = min(textSize.width, textRect.width)
        
        // Create bounds that match the actual text size within the text rect
        var actualTextBounds = CGRect(origin: textRect.origin, size: textSize)
        
        // Adjust horizontal position based on text alignment
        switch textField.textAlignment {
        case .center:
            actualTextBounds.origin.x = textRect.origin.x + (textRect.width - textSize.width) / 2
        case .right:
            actualTextBounds.origin.x = textRect.origin.x + textRect.width - textSize.width
        case .left, .natural:
            // Keep the original x position from textRect
            break
        case .justified:
            // For justified, use left alignment as fallback
            break
        @unknown default:
            break
        }
        
        // Center vertically within the text rect
        actualTextBounds.origin.y = textRect.origin.y + (textRect.height - textSize.height) / 2
        
        // Convert to window coordinates
        if let window = textField.window {
            return textField.convert(actualTextBounds, to: window)
        }
        
        return actualTextBounds
    }

    func cssDescription() -> String {
        return """
                #\(viewDetails.cssSelector) { \
                \(inlineCSSDescription()) \
                } 
                """
    }
    
    func inlineCSSDescription() -> String {
        let fontWeightCSS = TextHelper.cssValueForFontWeight(fontWeight)
        let fontStyleCSS = isItalic ? "italic" : "normal"
        
        // Generate letter-spacing CSS if available
        var letterSpacingCSS = ""
        if let letterSpacing = self.letterSpacing {
            letterSpacingCSS = " letter-spacing: \(String(format: "%.2f", letterSpacing))px;"
        }

        return """
                \(generateBaseCSSStyle()) \
                white-space: nowrap; \
                font: \(fontStyleCSS) \(fontWeightCSS) \(String(format: "%.2f", self.fontSize))px \(self.fontFamily); \
                color: \(textColor.toHexString(includingAlpha: true)); \
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
                                        tagName: .span,
                                        attributes: ["id":viewDetails.cssSelector],
                                        childNodes: [textNode])
    }
    
    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        let elementNode = ElementNodeData(id: viewDetails.viewId,
                                   tagName: .span,
                                   attributes: ["id":viewDetails.cssSelector],
                                   childNodes: [])
        elementNode.attributes["style"] = inlineCSSDescription()

        let textNode = SerializedNode.text(TextNodeData(id: IDGenerator.shared.getId(),
                                                        isStyle: false,
                                                        textContent: labelText,
                                                        childNodes: []))
        
        let addElementNode: RRWebMutationData.AddRecord = .init(parentId: parentNodeId, nextId: viewDetails.nextId, node: .element(elementNode))
        let addTextNode: RRWebMutationData.AddRecord = .init(parentId: viewDetails.viewId, nextId: nil, node: textNode)
        
        return [addElementNode, addTextNode]
    }
    
    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? CustomTextThingy else {
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

extension CustomTextThingy: Equatable {
    static func == (lhs: CustomTextThingy, rhs: CustomTextThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails &&
            lhs.labelText == rhs.labelText &&
            lhs.fontSize == rhs.fontSize &&
            lhs.fontName == rhs.fontName &&
            lhs.fontFamily == rhs.fontFamily &&
            lhs.textColor == rhs.textColor &&
            lhs.fontWeight == rhs.fontWeight &&
            lhs.isItalic == rhs.isItalic &&
            lhs.numberOfLines == rhs.numberOfLines &&
            lhs.lineBreakMode == rhs.lineBreakMode
    }
}

extension CustomTextThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
        hasher.combine(labelText)
        hasher.combine(fontSize)
        hasher.combine(fontName)
        hasher.combine(fontFamily)
        hasher.combine(textColor)
        hasher.combine(fontWeight)
        hasher.combine(isItalic)
        hasher.combine(numberOfLines)
        hasher.combine(lineBreakMode)
    }
}

fileprivate var associatedSessionReplayCustomTextIDKey: String = "SessionReplayCustomTextID"

internal extension UIView {
    var sessionReplayCustomTextIDKey: Int? {
        set {
            withUnsafePointer(to: &associatedSessionReplayCustomTextIDKey) {
                objc_setAssociatedObject(self, $0, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
        
        get {
            withUnsafePointer(to: &associatedSessionReplayCustomTextIDKey) {
                objc_getAssociatedObject(self, $0) as? Int
            }
        }
    }
}
