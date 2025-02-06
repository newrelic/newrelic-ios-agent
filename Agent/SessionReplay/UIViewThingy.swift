//
//  UIViewThingy.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 2/5/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit

struct UIViewThingy: SessionReplayViewThingy {
    var shouldRecordSubviews: Bool {
        true
    }
    
    let viewDetails: ViewDetails
    
    init(view: UIView, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
    }
    
    func jsonDescription() -> [String: Any] {
        return generateBaseJSONDescription()
    }
    
    func cssDescription() -> String {
        "#\(viewDetails.cssSelector) { \(generateBaseCSSStyle())"
    }
}
