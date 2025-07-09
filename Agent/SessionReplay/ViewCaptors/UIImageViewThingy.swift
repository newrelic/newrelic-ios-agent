//
//  UIImageViewThingy.swift
//  Agent
//
//  Created by Steve Malsam on 4/1/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit
@_implementationOnly import NewRelicPrivate

class UIImageViewThingy: SessionReplayViewThingy {
    var isMasked: Bool
    
    var viewDetails: ViewDetails
    var image: UIImage?
    
    var shouldRecordSubviews: Bool {
        true
    }
    
    var subviews: [any SessionReplayViewThingy] = []
    
    init(view: UIImageView, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        if false {
            self.image = (view.image ?? nil)
        }
        if let isMasked = viewDetails.isMasked {
            self.isMasked = isMasked
        } else {
            self.isMasked = NRMAHarvestController.configuration().session_replay_maskAllImages
        }
    }
    
    func cssDescription() -> String {
        return """
                #\(viewDetails.cssSelector) { \
                \(inlineCSSDescription())\
                }
                """
    }
    
    func inlineCSSDescription() -> String {
        if let _ = image {
            return generateBaseCSSStyle()
        } else {
            let imagePlaceholderCSS = "background: rgb(2,0,36);background: linear-gradient(90deg, rgba(2,0,36,1) 0%, rgba(0,212,255,1) 100%);"
            return "\(generateBaseCSSStyle()) \(imagePlaceholderCSS)"
        }
    }
    
    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        let elementNode = generateRRWebNode()
        elementNode.attributes["style"] = inlineCSSDescription()
        
        let addElementNode: RRWebMutationData.AddRecord = .init(parentId: parentNodeId, nextId: nil, node: .element(elementNode))

        return [addElementNode]
    }
    
    func generateRRWebNode() -> ElementNodeData {
        if let imageData = image?.compressImage().pngData() {
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
        if let imageData = typedOther.image?.compressImage().pngData() {
            differences["src"] = "data:image/png;base64,\(imageData.base64EncodedString())"
        }
        return [RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: differences)]
    }
}

extension UIImageViewThingy: Equatable {
    static func == (lhs: UIImageViewThingy, rhs: UIImageViewThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails //&& lhs.imageData?.hashValue == rhs.imageData?.hashValue
    }
}

extension UIImageViewThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
        hasher.combine(image?.hashValue ?? 0)
    }
}

internal extension UIImage {
    func aspectFittedToHeight(_ newHeight: CGFloat) -> UIImage {
        let scale = newHeight / self.size.height
        let newWidth = self.size.width * scale
        let newSize = CGSize(width: newWidth, height: newHeight)
        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    func compressImage() -> UIImage {
            let resizedImage = self.aspectFittedToHeight(10)
            resizedImage.jpegData(compressionQuality: 0.1)

            return resizedImage
    }
}
