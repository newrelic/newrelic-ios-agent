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
    let imagePlaceholderCSS = "background: rgb(2,0,36);background: linear-gradient(90deg, rgba(2,0,36,1) 0%, rgba(0,212,255,1) 100%);"
    var image: UIImage?
    var contentMode: [String: String]
    
    var shouldRecordSubviews: Bool {
        true
    }
    
    var subviews: [any SessionReplayViewThingy] = []
    
    init(view: UIImageView, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails

        if let isMasked = viewDetails.isMasked {
            self.isMasked = isMasked
        } else {
            self.isMasked = NRMAHarvestController.configuration().session_replay_maskAllImages
        }
        if !self.isMasked {
            self.image = (view.image ?? nil)
        }
        
        self.contentMode = view.contentModeToCSS()
    }
    
    func cssDescription() -> String {
        return """
                #\(viewDetails.cssSelector) { \
                \(inlineCSSDescription())\
                }
                """
    }
    
    func inlineCSSDescription() -> String {
        if isMasked {
            return "\(generateBaseCSSStyle()) \(imagePlaceholderCSS)"
        } else {
            return  """
                    \(generateBaseCSSStyle()) \
                    object-fit: \(contentMode["object-fit"] ?? "contain"); \
                    object-position: \(contentMode["object-position"] ?? "center");
                    """
        }
    }
    
    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        let elementNode = ElementNodeData(id: viewDetails.viewId,
                                          tagName: .image,
                                   attributes: ["id":viewDetails.cssSelector],
                                   childNodes: [])
        elementNode.attributes["style"] = inlineCSSDescription()
        if let imageData = image?.optimizedPngData() {
            elementNode.attributes["src"] = "data:image/png;base64,\(imageData.base64EncodedString())"
        }
        
        let addElementNode: RRWebMutationData.AddRecord = .init(parentId: parentNodeId, nextId: viewDetails.nextId, node: .element(elementNode))

        return [addElementNode]
    }
    
    func generateRRWebNode() -> ElementNodeData {
        if let imageData = image?.optimizedPngData() {
            return ElementNodeData(id: viewDetails.viewId,
                                   tagName: .image,
                                   attributes: ["id":viewDetails.cssSelector,"src":"data:image/png;base64,\(imageData.base64EncodedString())"],
                                   childNodes: [])
        } else {
            return ElementNodeData(id: viewDetails.viewId,
                                   tagName: .image,
                                   attributes: ["id":viewDetails.cssSelector],
                                   childNodes: [])
        }
    }
    
    static func imagesAreLikelyEqual(_ img1: UIImage?, _ img2: UIImage?) -> Bool {
        guard let img1 = img1, let img2 = img2 else { return img1 == nil && img2 == nil }

        // Compare optimized image data
        let data1 = img1.optimizedPngData()
        let data2 = img2.optimizedPngData()
        
        return data1 == data2
    }
    
    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? UIImageViewThingy else {
            return []
        }
        var mutations = [MutationRecord]()
        var allAttributes = [String: String]()
        
        allAttributes["style"] = typedOther.inlineCSSDescription()

        if !typedOther.isMasked {
            if !UIImageViewThingy.imagesAreLikelyEqual(self.image, typedOther.image) {
                if let imageData = typedOther.image?.optimizedPngData() {
                    allAttributes["src"] = "data:image/png;base64,\(imageData.base64EncodedString())"
                }
            }
        }
            
        if !allAttributes.isEmpty {
            let attributeRecord = RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: allAttributes)
            mutations.append(attributeRecord)
        }
        
        return mutations
    }
}

extension UIImageViewThingy: Equatable {
    static func == (lhs: UIImageViewThingy, rhs: UIImageViewThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails && UIImageViewThingy.imagesAreLikelyEqual(lhs.image, rhs.image)
    }
}

extension UIImageViewThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
        hasher.combine(image?.hashValue ?? 0)
    }
}

fileprivate var associatedOptimizedImageDataKey: String = "SessionReplayOptimizedImageData"

internal extension UIImage {
    private var cachedOptimizedData: Data? {
        set {
            withUnsafePointer(to: &associatedOptimizedImageDataKey) {
                objc_setAssociatedObject(self, $0, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
        
        get {
            withUnsafePointer(to: &associatedOptimizedImageDataKey) {
                objc_getAssociatedObject(self, $0) as? Data
            }
        }
    }
    
    func optimizedPngData(maxDimension: CGFloat = 25) -> Data? {
        // Return cached data if available
        if let cachedData = cachedOptimizedData {
            return cachedData
        }
        
        let optimizedData = generateOptimizedPngData(maxDimension: maxDimension)
        cachedOptimizedData = optimizedData
        return optimizedData
    }
    
    private func generateOptimizedPngData(maxDimension: CGFloat) -> Data? {
        let originalSize = self.size
        
        // Calculate new size maintaining aspect ratio
        let scale: CGFloat
        if originalSize.width > originalSize.height {
            scale = min(1.0, maxDimension / originalSize.width)
        } else {
            scale = min(1.0, maxDimension / originalSize.height)
        }
        
        let newSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
        
        // Create graphics context and resize image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: CGRect(origin: .zero, size: newSize))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        
        return resizedImage.pngData()
    }
}

internal extension UIImageView {
    func contentModeToCSS() -> [String: String] {
        var cssProperties = [String: String]()
        
        switch contentMode {
        case .scaleAspectFit:
            cssProperties["object-fit"] = "contain"
            cssProperties["object-position"] = "center"
            
        case .scaleAspectFill:
            cssProperties["object-fit"] = "cover"
            cssProperties["object-position"] = "center"
            
        case .scaleToFill:
            cssProperties["object-fit"] = "fill"
            
        case .center:
            cssProperties["object-fit"] = "none"
            cssProperties["object-position"] = "center"
            
        case .top:
            cssProperties["object-fit"] = "none"
            cssProperties["object-position"] = "top"
            
        case .bottom:
            cssProperties["object-fit"] = "none"
            cssProperties["object-position"] = "bottom"
            
        case .left:
            cssProperties["object-fit"] = "none"
            cssProperties["object-position"] = "left"
            
        case .right:
            cssProperties["object-fit"] = "none"
            cssProperties["object-position"] = "right"
            
        case .topLeft:
            cssProperties["object-fit"] = "none"
            cssProperties["object-position"] = "top left"
            
        case .topRight:
            cssProperties["object-fit"] = "none"
            cssProperties["object-position"] = "top right"
            
        case .bottomLeft:
            cssProperties["object-fit"] = "none"
            cssProperties["object-position"] = "bottom left"
            
        case .bottomRight:
            cssProperties["object-fit"] = "none"
            cssProperties["object-position"] = "bottom right"
            
        default:
            cssProperties["object-fit"] = "contain"
            cssProperties["object-position"] = "center"
        }
        
        return cssProperties
    }
}
