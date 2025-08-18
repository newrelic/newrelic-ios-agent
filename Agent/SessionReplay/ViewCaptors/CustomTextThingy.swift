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
    
    var subviews = [any SessionReplayViewThingy]()
    
    var shouldRecordSubviews: Bool {
        false
    }
    
    var viewDetails: ViewDetails
    
    let labelText: String
    let fontSize: CGFloat
    let fontName: String
    let fontFamily: String
    let textAlignment: String

    let textColor: UIColor
    
    init(view: UITextField, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        
        if let identifier = view.sessionReplayCustomTextIDKey {
            self.viewDetails.viewId = identifier
        } else {
            self.viewDetails.viewId = IDGenerator.shared.getId()
            view.sessionReplayCustomTextIDKey = self.viewDetails.viewId
        }
        
//        if #available(iOS 15.0, *) {
//            let fragmentFrames = CustomTextThingy.getTextLayoutFragmentFrames(textField: view)
//            if !fragmentFrames.isEmpty {
//                // Calculate the union of all fragment frames to get the complete text bounds
//                let combinedFrame = fragmentFrames.reduce(fragmentFrames[0]) { result, frame in
//                    result.union(frame)
//                }
//                self.viewDetails.frame = combinedFrame
//            }
//        }
        
        if view.isSecureTextEntry {
            self.isMasked = true
        }
        else if let isMasked = viewDetails.isMasked {
            self.isMasked = isMasked
        } else {
            self.isMasked = NRMAHarvestController.configuration().session_replay_maskUserInputText
        }
        
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
        } else {
            self.fontName = fontNameRaw
        }
        
        let fontFamilyRaw = font.familyName
        if(fontFamilyRaw.hasPrefix(".") && fontFamilyRaw.count > 1) {
            self.fontFamily = String(fontFamilyRaw.dropFirst())
        } else {
            self.fontFamily = fontFamilyRaw
        }
        
        if #available(iOS 13.0, *) {
            self.textColor = view.textColor ?? UIColor.label
        } else {
            // Fallback on earlier versions
            self.textColor = view.textColor ?? UIColor.black
        }
        
        self.textAlignment = view.textAlignment.stringValue()
        
        if let actualTextBounds = CustomTextThingy.getActualTextBounds(textField: view, text: self.labelText, font: font) {
            self.viewDetails.frame = actualTextBounds
        }

    }
    
    static func getActualTextBounds(textField: UITextField, text: String, font: UIFont) -> CGRect? {
        // Get the text rect area from the text field
        let textRect = textField.textRect(forBounds: textField.bounds)
        
        // Calculate actual text size
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: attributes)
        
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

//    private static let fragmentViewClassName = "_UITextLayoutFragmentView"
//    static func getTextLayoutFragmentFrames(textField: UITextField) -> [CGRect] {
//        // Early exit if text field has no text
//        guard let text = textField.text, !text.isEmpty else { return [] }
//        var fragmentFrames: [CGRect] = []
//        
//        // Find UITextLayoutFragmentView subviews
//        func findTextLayoutFragments(in textField: UIView) {
//            if let superview = textField.superview, let window = textField.window {
//                for subview in textField.subviews {
//                    if String(describing: type(of: subview)) == fragmentViewClassName {
//                        fragmentFrames.append(superview.convert(subview.frame, to: window))
//                    }
//                    findTextLayoutFragments(in: subview)
//                }
//            }
//        }
//        
//        findTextLayoutFragments(in: textField)
//        return fragmentFrames
//    }

    func cssDescription() -> String {
        return """
                #\(viewDetails.cssSelector) { \
                \(inlineCSSDescription()) \
                } 
                """
    }
    
    func inlineCSSDescription() -> String {
        return """
                position: fixed; \
                left: \(String(format: "%.2f", self.viewDetails.frame.origin.x))px; \
                top: \(String(format: "%.2f", self.viewDetails.frame.origin.y))px; \
                width: \(String(format: "%.2f", self.viewDetails.frame.size.width))px; \
                height: \(String(format: "%.2f", self.viewDetails.frame.size.height))px; \
                white-space: pre-wrap; \
                font: \(String(format: "%.2f", self.fontSize))px \(self.fontFamily); \
                color: \(textColor.toHexString(includingAlpha: true)); \
                text-align: \(textAlignment);
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
        var frameDifferences = generateBaseDifferences(from: typedOther)
        
        // get text color difference
        if textColor != typedOther.textColor {
            frameDifferences["color"] = typedOther.textColor.toHexString(includingAlpha: true)
        }
        
        if fontSize != typedOther.fontSize || fontFamily != typedOther.fontFamily {
            frameDifferences["font"] = "\(String(format: "%.2f", self.fontSize))px \(self.fontFamily)px"
        }
        
        if !frameDifferences.isEmpty {
            let attributeRecord = RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: frameDifferences)
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
            lhs.textColor == rhs.textColor
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
