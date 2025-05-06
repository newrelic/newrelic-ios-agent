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
    var imageData: Data?
    
    var shouldRecordSubviews: Bool {
        true
    }
    
    var subviews: [any SessionReplayViewThingy] = []
    
    init(view: UIImageView, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        self.imageData = (view.image?.pngData() ?? nil)
    }
    
    func cssDescription() -> String {
        let cssSelector = viewDetails.cssSelector
        
       // if let _ = imageData {
            return "#\(viewDetails.cssSelector) { \(generateBaseCSSStyle()) }"
//        } else {
//            let imagePlaceholderCSS = "background: rgb(2,0,36);background: linear-gradient(90deg, rgba(2,0,36,1) 0%, rgba(0,212,255,1) 100%);"
//            return "#\(viewDetails.cssSelector) { \(generateBaseCSSStyle()) \(imagePlaceholderCSS) }"
//        }
    }
    
    func generateRRWebNode() -> ElementNodeData {
        if let imageData = imageData {
            return ElementNodeData(id: viewDetails.viewId,
                                   tagName: .image,
                                   attributes: ["id":viewDetails.cssSelector,"src":"data:image/png;base64,\(imageData.base64EncodedString())"],
                                   childNodes: [])
        } else {
            return ElementNodeData(id: viewDetails.viewId,
                                   tagName: .div,
                                   attributes: ["id":viewDetails.cssSelector],
                                   childNodes: [])
        }
    }
    
    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? UIImageViewThingy else {
            return []
        }
        var differences = generateBaseDifferences(from: typedOther)
        if let imageData = imageData {
            differences["src"] = "data:image/png;base64,\(imageData.base64EncodedString())"
        }
        return [RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: differences)]
    }
}

extension UIImageViewThingy: Equatable {
    static func == (lhs: UIImageViewThingy, rhs: UIImageViewThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails && lhs.imageData?.hashValue == rhs.imageData?.hashValue
    }
}

extension UIImageViewThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
    }
}
