//  SwiftUIImageThingy.swift
//  Agent
//
//  Provides Session Replay capture for SwiftUI Image views surfaced as opaque SwiftUI hosting UIViews.
//  We receive an already obtained UIImage (best-effort) from SessionReplayCapture.
//

import Foundation
import UIKit
@_implementationOnly import NewRelicPrivate

@available(iOS 13.0, *)
class SwiftUIImageThingy: SessionReplayViewThingy {
    var isMasked: Bool
    var subviews: [any SessionReplayViewThingy] = []
    var shouldRecordSubviews: Bool { false }
    var viewDetails: ViewDetails
    var maxSize: CGFloat = 200
        

    private var image: UIImage?
    private let isCompositeSnapshot: Bool

    init(view: UIView, viewDetails: ViewDetails, image: UIImage, isCompositeSnapshot: Bool = true) {
        self.viewDetails = viewDetails
        self.isCompositeSnapshot = isCompositeSnapshot
        if let isMasked = view.sessionReplayMaskState {
            self.isMasked = isMasked
        } else if let declared = view.sessionReplayEffectiveDeclaredType {
            switch declared {
            case .applicationText:
                self.isMasked = NRMAHarvestController.configuration()?.session_replay_maskApplicationText ?? true
            case .userInputText:
                self.isMasked = NRMAHarvestController.configuration()?.session_replay_maskUserInputText ?? true
            case .image:
                self.isMasked = NRMAHarvestController.configuration()?.session_replay_maskAllImages ?? true
            }
        } else {
            isMasked = true
        }
        if self.isMasked {
           // maxSize = 20
        }
        self.image = image

    }

    func cssDescription() -> String {
        "#\(viewDetails.cssSelector) { \(inlineCSSDescription())}"
    }

    func inlineCSSDescription() -> String {
        return "\(generateBaseCSSStyle()) object-fit: contain; object-position: center;"
    }

    func generateRRWebNode() -> ElementNodeData {
        var attrs: [String:String] = ["id": viewDetails.cssSelector]
        if let data = image?.optimizedPngData(maxDimension: maxSize) {
            attrs["src"] = "data:image/png;base64,\(data.base64EncodedString())"
        }
        return ElementNodeData(id: viewDetails.viewId, tagName: .image, attributes: attrs, childNodes: [])
    }

    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        let node = ElementNodeData(id: viewDetails.viewId, tagName: .image, attributes: ["id": viewDetails.cssSelector], childNodes: [])
        node.attributes["style"] = inlineCSSDescription()
        if let data = image?.optimizedPngData(maxDimension: maxSize) {
            node.attributes["src"] = "data:image/png;base64,\(data.base64EncodedString())"
        }
        let add = RRWebMutationData.AddRecord(parentId: parentNodeId, nextId: viewDetails.nextId, node: .element(node))
        return [add]
    }

    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? SwiftUIImageThingy else { return [] }
        var mutations: [MutationRecord] = []
        var attrs: [String:String] = [:]
        
        attrs["style"] = typedOther.inlineCSSDescription()
        
        let currentData = image?.optimizedPngData(maxDimension: maxSize)
        let otherData = typedOther.image?.optimizedPngData(maxDimension: maxSize)
        if currentData != otherData, let nd = otherData {
            attrs["src"] = "data:image/png;base64,\(nd.base64EncodedString())"
        }
        
        if !attrs.isEmpty { mutations.append(RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: attrs)) }
        return mutations
    }
}

@available(iOS 13.0, *)
extension SwiftUIImageThingy: Equatable {
    static func == (lhs: SwiftUIImageThingy, rhs: SwiftUIImageThingy) -> Bool {
        if lhs.viewDetails != rhs.viewDetails { return false }
        let ld = lhs.image?.optimizedPngData(maxDimension: lhs.maxSize)
        let rd = rhs.image?.optimizedPngData(maxDimension: rhs.maxSize)
        return ld == rd
    }
}

@available(iOS 13.0, *)
extension SwiftUIImageThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
        hasher.combine(image?.optimizedPngData(maxDimension: maxSize)?.hashValue ?? 0)
    }
}
