//
//  UIImageViewThingy.swift
//  Agent
//
//  Created by Steve Malsam on 4/1/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit

class UIImageViewThingy: SessionReplayViewThingy {
    var viewDetails: ViewDetails
    
    var shouldRecordSubviews: Bool {
        true
    }
    
    var subviews: [any SessionReplayViewThingy] = []
    
    init(view: UIImageView, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
    }
    
    func cssDescription() -> String {
        let cssSelector = viewDetails.cssSelector
        
        let imagePlaceholderCSS = "background: rgb(2,0,36);background: linear-gradient(90deg, rgba(2,0,36,1) 0%, rgba(0,212,255,1) 100%);"
        
        return "#\(viewDetails.cssSelector) { \(generateBaseCSSStyle()) \(imagePlaceholderCSS) }"
    }
    
    func generateRRWebNode() -> ElementNodeData {
        return ElementNodeData(id: viewDetails.viewId,
                                        tagName: .div,
                                        attributes: ["id":viewDetails.cssSelector],
                                        childNodes: [])
    }
    
    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? UIImageViewThingy else {
            return []
        }
        return [RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: generateBaseDifferences(from: typedOther))]
    }
}

extension UIImageViewThingy: Equatable {
    static func == (lhs: UIImageViewThingy, rhs: UIImageViewThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails
    }
}

extension UIImageViewThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
    }
}
