//
//  UIVisualEffectViewThingy.swift
//  Agent
//
//  Created by Mike Bruin on 7/3/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit

class UIVisualEffectViewThingy: SessionReplayViewThingy {
    var isMasked: Bool
    
    var subviews = [any SessionReplayViewThingy]()
    
    var shouldRecordSubviews: Bool {
        true
    }
    
    var viewDetails: ViewDetails
    
    init(view: UIVisualEffectView, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        self.isMasked = viewDetails.isMasked
        if #available(iOS 12.0, *) {
            if view.traitCollection.userInterfaceStyle == .light {
                self.viewDetails.backgroundColor = UIColor(red: 248.0/255.0, green: 248.0/255.0, blue: 248.0/255.0, alpha: 0.85)
            } else {
                self.viewDetails.backgroundColor = UIColor(red: 8.0/255.0, green: 8.0/255.0, blue: 8.0/255.0, alpha: 0.85)
            }
        }
    }
    
    func cssDescription() -> String {
        return """
        #\(viewDetails.cssSelector) { \
        \(generateBaseCSSStyle())\
        backdrop-filter: blur(10px);\
        -webkit-backdrop-filter: blur(10px);\
        box-shadow: 0px 0.5px 0px rgba(0, 0, 0, 0.3);
        }
        """
    }
    
    func generateRRWebNode() -> ElementNodeData {
        return ElementNodeData(id: viewDetails.viewId,
                               tagName: .div,
                               attributes: ["id":viewDetails.cssSelector],
                               childNodes: [])
    }
    
    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? UIVisualEffectViewThingy else {
            return []
        }
        return [RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: generateBaseDifferences(from: typedOther))]
    }
}

extension UIVisualEffectViewThingy: Equatable {
    static func == (lhs: UIVisualEffectViewThingy, rhs: UIVisualEffectViewThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails
    }
}

extension UIVisualEffectViewThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
    }
}
