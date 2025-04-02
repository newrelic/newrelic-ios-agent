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
    var subviews = [any SessionReplayViewThingy]()
    
    var shouldRecordSubviews: Bool {
        true
    }
    
    let viewDetails: ViewDetails
    
    init(view: UIView, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
    }
    
    func cssDescription() -> String {
//        var cssDescription = generateBaseCSSStyle()
        return "#\(viewDetails.cssSelector) {\(generateBaseCSSStyle())} "
    }
    
    func generateRRWebNode() -> RRWebElementNode {
        return RRWebElementNode(id: viewDetails.viewId,
                                tagName: .div,
                                attributes: ["id":viewDetails.cssSelector],
                                childNodes: [])
    }
}



