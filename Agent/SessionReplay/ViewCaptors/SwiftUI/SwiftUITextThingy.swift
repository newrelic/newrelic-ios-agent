//  SwiftUITextThingy.swift
//  Agent
//
//  Created to provide Session Replay capture for SwiftUI Text-like views that surface as opaque hosting UIViews.
//
//  NOTE: This uses heuristic / KVC based introspection of SwiftUI hosting views. These internals are not
//  considered stable by Apple and may need maintenance across iOS releases.
//

import Foundation
import UIKit
@_implementationOnly import NewRelicPrivate

class SwiftUITextThingy: SessionReplayViewThingy {
    var isMasked: Bool
    var subviews: [any SessionReplayViewThingy] = []
    var shouldRecordSubviews: Bool { false }
    var viewDetails: ViewDetails

    let labelText: String
    let fontSize: CGFloat
    let fontName: String
    let fontFamily: String
    let textAlignment: String
    let textColor: UIColor

    init(view: UIView, viewDetails: ViewDetails, text textInfo: ExtractedTextInfo) {
        self.viewDetails = viewDetails

        // Masking parity with UILabelThingy
        if let isMasked = viewDetails.isMasked {
            self.isMasked = isMasked
        } else {
            self.isMasked = NRMAHarvestController.configuration()?.session_replay_maskApplicationText ?? true
        }

        let effectiveText: String
        if self.isMasked {
            effectiveText = String(repeating: "*", count: textInfo.labelText.count)
        } else {
            effectiveText = textInfo.labelText
        }
        self.labelText = effectiveText

        self.fontSize = textInfo.fontSize
        self.fontName = textInfo.fontName
        self.fontFamily = textInfo.fontFamily
        self.textColor = textInfo.textColor
        self.textAlignment = textInfo.textAlignment
    }

    private static func findDescendantLabel(in view: UIView, depthLimit: Int = 4) -> UILabel? {
        if depthLimit < 0 { return nil }
        for sub in view.subviews {
            if let label = sub as? UILabel { return label }
            if let found = findDescendantLabel(in: sub, depthLimit: depthLimit - 1) { return found }
        }
        return nil
    }

    func cssDescription() -> String {
        "#\(viewDetails.cssSelector) { \(inlineCSSDescription())}"
    }

    func inlineCSSDescription() -> String {
        "\(generateBaseCSSStyle())white-space: pre-wrap; font: \(String(format: "%.2f", fontSize))px \(fontFamily); color: \(textColor.toHexString(includingAlpha: true)); text-align: \(textAlignment);"
    }

    func generateRRWebNode() -> ElementNodeData {
        let textNode = SerializedNode.text(TextNodeData(id: IDGenerator.shared.getId(), isStyle: false, textContent: labelText, childNodes: []))
        return ElementNodeData(id: viewDetails.viewId, tagName: .div, attributes: ["id": viewDetails.cssSelector], childNodes: [textNode])
    }

    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        let elementNode = ElementNodeData(id: viewDetails.viewId, tagName: .div, attributes: ["id": viewDetails.cssSelector], childNodes: [])
        elementNode.attributes["style"] = inlineCSSDescription()
        let textNode = SerializedNode.text(TextNodeData(id: IDGenerator.shared.getId(), isStyle: false, textContent: labelText, childNodes: []))
        let addElementNode: RRWebMutationData.AddRecord = .init(parentId: parentNodeId, nextId: viewDetails.nextId, node: .element(elementNode))
        let addTextNode: RRWebMutationData.AddRecord = .init(parentId: viewDetails.viewId, nextId: nil, node: textNode)
        return [addElementNode, addTextNode]
    }

    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? SwiftUITextThingy else { return [] }
        var mutations: [MutationRecord] = []
        var attrs: [String:String] = [:]
        attrs["style"] = typedOther.inlineCSSDescription()
        if !attrs.isEmpty { mutations.append(RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: attrs)) }
        if labelText != typedOther.labelText { mutations.append(RRWebMutationData.TextRecord(id: viewDetails.viewId, value: typedOther.labelText)) }
        return mutations
    }
}

extension SwiftUITextThingy: Equatable {
    static func == (lhs: SwiftUITextThingy, rhs: SwiftUITextThingy) -> Bool {
        lhs.viewDetails == rhs.viewDetails && lhs.labelText == rhs.labelText && lhs.fontSize == rhs.fontSize && lhs.fontName == rhs.fontName && lhs.fontFamily == rhs.fontFamily && lhs.textAlignment == rhs.textAlignment && lhs.textColor == rhs.textColor
    }
}

extension SwiftUITextThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
        hasher.combine(labelText)
        hasher.combine(fontSize)
        hasher.combine(fontName)
        hasher.combine(fontFamily)
        hasher.combine(textAlignment)
        hasher.combine(textColor)
    }
}
