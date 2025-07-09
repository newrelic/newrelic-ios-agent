//
//  UIViewThingy.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 2/5/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit

class UIViewThingy: SessionReplayViewThingy {
    var isMasked: Bool
    
    var subviews = [any SessionReplayViewThingy]()
    
    var shouldRecordSubviews: Bool {
        true
    }
    
    let viewDetails: ViewDetails
    
    init(view: UIView, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        self.isMasked = viewDetails.isMasked ?? false
    }
    
    func cssDescription() -> String {
        return "#\(viewDetails.cssSelector) {\(generateBaseCSSStyle())} "
    }
    
    func generateRRWebNode() -> ElementNodeData {
        return ElementNodeData(id: viewDetails.viewId,
                               tagName: .div,
                               attributes: ["id":viewDetails.cssSelector],
                               childNodes: [])
    }
    
    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        let node = generateRRWebNode()
        node.attributes["style"] = generateBaseCSSStyle()
        let addNode: RRWebMutationData.AddRecord = .init(parentId: parentNodeId, nextId: nil, node: .element(node))
        
        return [addNode]
    }
    
    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? UIViewThingy else {
            return []
        }
        return [RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: generateBaseDifferences(from: typedOther))]
    }
}

extension UIViewThingy: Equatable {
    static func == (lhs: UIViewThingy, rhs: UIViewThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails
    }
}

extension UIViewThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
    }
}
