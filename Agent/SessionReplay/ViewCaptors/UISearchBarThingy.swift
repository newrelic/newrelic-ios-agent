//
//  UISearchBarThingy.swift
//  Agent_iOS
//
//  Created by Chris Dillard on 7/18/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit
@_implementationOnly import NewRelicPrivate

@available(iOS 13.0, *)
class UISearchBarThingy: SessionReplayViewThingy {
    var isMasked: Bool
    
    var subviews = [any SessionReplayViewThingy]()
    
    var shouldRecordSubviews: Bool {
        false
    }
    
    var viewDetails: ViewDetails

    
    let labelText: String
    let fontSize: CGFloat
    let fontName: String
    let textAlignment: String
    let fontFamily: String
    let textColor: UIColor
    
    init(view: UISearchBar, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails

        if let isMasked = viewDetails.isMasked {
            self.isMasked = isMasked
        } else {
            self.isMasked = NRMAHarvestController.configuration().session_replay_maskApplicationText
        }
        
        if self.isMasked {
            // If the view is masked, we should not record the text.
            // instead replace it with the number of asterisks as were characters in label
            self.labelText = String(repeating: "*", count: view.text?.count ?? 0)
        }
        else {
            self.labelText = view.text ?? ""
        }

        self.fontSize = view.searchTextField.font?.pointSize ?? 8.0
        let fontNameRaw = view.searchTextField.font?.fontName ?? ""
        if(fontNameRaw .hasPrefix(".") && fontNameRaw.count > 1) {
            self.fontName = String(fontNameRaw.dropFirst())
        } else {
            self.fontName = fontNameRaw
        }
        
        let fontFamilyRaw = view.searchTextField.font?.familyName ?? ""
        if(fontFamilyRaw.hasPrefix(".") && fontFamilyRaw.count > 1) {
            self.fontFamily = String(fontFamilyRaw.dropFirst())
        } else {
            self.fontFamily = fontFamilyRaw
        }
        self.textAlignment = view.textAlignmentString()

        self.textColor = view.searchTextField.textColor ?? UIColor.black

    }
    
    func cssDescription() -> String {
        return """
                #\(viewDetails.cssSelector) { \
                \(inlineCSSDescription()) \
                } 
                """
    }
    
    func inlineCSSDescription() -> String {
        return """
                \(generateBaseCSSStyle())\
                white-space: pre-wrap;\
                font: \(String(format: "%.2f", self.fontSize))px \(self.fontFamily); \
                color: \(textColor.toHexString(includingAlpha: true));
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
    
    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        let elementNode = ElementNodeData(id: viewDetails.viewId,
                                   tagName: .div,
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
        guard let typedOther = other as? UISearchBarThingy else {
            return []
        }
        
        var mutations = [MutationRecord]()
        var frameDifferences = generateBaseDifferences(from: typedOther)
        
        // get text color difference
        if textColor != typedOther.textColor {
            frameDifferences["color"] = typedOther.textColor.toHexString(includingAlpha: true)
        }
        
        if textAlignment != typedOther.textAlignment {
            frameDifferences["text-align"] = typedOther.textAlignment
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

@available(iOS 13.0, *)
extension UISearchBarThingy: Equatable {
    static func == (lhs: UISearchBarThingy, rhs: UISearchBarThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails &&
            lhs.labelText == rhs.labelText &&
            lhs.fontSize == rhs.fontSize &&
            lhs.fontName == rhs.fontName &&
            lhs.fontFamily == rhs.fontFamily &&
            lhs.textAlignment == rhs.textAlignment &&
            lhs.textColor == rhs.textColor
    }
}

@available(iOS 13.0, *)
extension UISearchBarThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
        hasher.combine(labelText)
        hasher.combine(fontSize)
        hasher.combine(fontName)
        hasher.combine(fontFamily)
        hasher.combine(textColor)
    }
}

internal extension UISearchBar {

    func textAlignmentString() -> String {
        if #available(iOS 13.0, *) {

            switch self.searchTextField.textAlignment {
            case .left:
                return "left"
            case .center:
                return "center"
            case .right:
                return "right"
            case .justified:
                return "justify"
            case .natural:
                // In CSS, 'start' is the logical value that aligns to the beginning
                // of the text flow, respecting LTR/RTL direction, similar to .natural.
                return "start"
            @unknown default:
                return "left"
            }
        }
        else {
            return "left"
        }
    }
}

