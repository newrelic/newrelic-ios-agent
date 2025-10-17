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
        }
        else {
            self.isMasked = NRMAHarvestController.configuration()?.session_replay_maskAllImages ?? true
        }
        if !self.isMasked {
            self.image = view.image
        }
        
        self.contentMode = UIImageViewThingy.contentModeToCSS(contentMode: view.contentMode)
    }
    
    init(viewDetails: ViewDetails, cgImage: CGImage?, swiftUIImage: SwiftUIGraphicsImage, contentMode: UIView.ContentMode) {
        self.viewDetails = viewDetails

        if let isMasked = viewDetails.isMasked {
            self.isMasked = isMasked
        }
        else {
            self.isMasked = NRMAHarvestController.configuration()?.session_replay_maskAllImages ?? true
        }
        if !self.isMasked {
            if let cgImage = cgImage {
                let uiImage = UIImage(cgImage: cgImage, scale: swiftUIImage.scale, orientation: swiftUIImage.orientation.toUIImageOrientation())
                    self.image = uiImage
            }
        }
        
        self.contentMode = UIImageViewThingy.contentModeToCSS(contentMode: contentMode)
    }
    
    func cssDescription() -> String {
        return """
                #\(viewDetails.cssSelector) { \
                \(inlineCSSDescription())\
                }
                """
    }
    
    func inlineCSSDescription() -> String {
        return "\(generateBaseCSSStyle()) display: block;"
    }
    
    func imageInlineCSSDescription() -> String {
        if isMasked {
            return "\(generateBaseCSSStyle()) \(imagePlaceholderCSS)"
        }
        else {
            return  """
                    \(generateBaseCSSStyle()) \
                    object-fit: \(contentMode["object-fit"] ?? "contain"); \
                    object-position: \(contentMode["object-position"] ?? "center");
                    """
        }
    }
    
    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        // Create the img element
        let imgNode = ElementNodeData(id: viewDetails.viewId + 1000000, // Use offset to avoid ID conflicts
                                      tagName: .image,
                                      attributes: [:],
                                      childNodes: [])
        imgNode.attributes["style"] = imageInlineCSSDescription()
        if let imageData = image?.optimizedPngData() {
            imgNode.attributes["src"] = "data:image/png;base64,\(imageData.base64EncodedString())"
        }
        
        // Create the container div element
        let containerNode = ElementNodeData(id: viewDetails.viewId,
                                            tagName: .div,
                                            attributes: ["id": viewDetails.cssSelector],
                                            childNodes: [])
        containerNode.attributes["style"] = inlineCSSDescription()
        
        let addDivNode: RRWebMutationData.AddRecord = .init(parentId: parentNodeId, nextId: viewDetails.nextId, node: .element(containerNode))
        let addImgNode: RRWebMutationData.AddRecord = .init(parentId: viewDetails.viewId, nextId: nil, node: .element(imgNode))

        return [addDivNode, addImgNode]
    }
    
    func generateRRWebNode() -> ElementNodeData {
        // Create the img element
        let imgNode = ElementNodeData(id: viewDetails.viewId + 1000000, // Use offset to avoid ID conflicts
                                      tagName: .image,
                                      attributes: [:],
                                      childNodes: [])
        imgNode.attributes["style"] = imageInlineCSSDescription()
        if let imageData = image?.optimizedPngData() {
            imgNode.attributes["src"] = "data:image/png;base64,\(imageData.base64EncodedString())"
        }

        // Create and return the container div
        return ElementNodeData(id: viewDetails.viewId,
                               tagName: .div,
                               attributes: ["id": viewDetails.cssSelector],
                               childNodes: [.element(imgNode)])
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
        
        // Update container div attributes if needed
        var containerAttributes = [String: String]()
        containerAttributes["style"] = typedOther.inlineCSSDescription()
        
        if !containerAttributes.isEmpty {
            let containerAttributeRecord = RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: containerAttributes)
            mutations.append(containerAttributeRecord)
        }
        
        // Update img element attributes if needed
        var imgAttributes = [String: String]()
        imgAttributes["style"] = typedOther.imageInlineCSSDescription()

        if !typedOther.isMasked {
            if !UIImageViewThingy.imagesAreLikelyEqual(self.image, typedOther.image) {
                if let imageData = typedOther.image?.optimizedPngData() {
                    imgAttributes["src"] = "data:image/png;base64,\(imageData.base64EncodedString())"
                }
            }
        }
            
        if !imgAttributes.isEmpty {
            let imgAttributeRecord = RRWebMutationData.AttributeRecord(id: viewDetails.viewId + 1000000, attributes: imgAttributes)
            mutations.append(imgAttributeRecord)
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

extension UIImageViewThingy {
    private static func contentModeToCSS(contentMode: UIView.ContentMode) -> [String: String] {
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


