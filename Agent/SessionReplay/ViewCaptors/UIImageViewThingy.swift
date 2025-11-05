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

    var imageURL: URL?
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
        else if let maskAllImages = viewDetails.maskAllImages {
            self.isMasked = maskAllImages
        }
        else {
            self.isMasked = NRMAHarvestController.configuration()?.session_replay_maskAllImages ?? true
        }
        if !self.isMasked {
            if let url = view.image?.NRSessionReplayImageURL {
                imageURL = url
            } else {
                self.image = view.image
            }
        }
        
        self.contentMode = UIImageViewThingy.contentModeToCSS(contentMode: view.contentMode)
    }
    
    init(viewDetails: ViewDetails, cgImage: CGImage?, swiftUIImage: SwiftUIGraphicsImage, contentMode: UIView.ContentMode) {
        self.viewDetails = viewDetails

        if let isMasked = viewDetails.isMasked {
            self.isMasked = isMasked
        }
        else if let maskAllImages = viewDetails.maskAllImages {
            self.isMasked = maskAllImages
        }
        else {
            self.isMasked = NRMAHarvestController.configuration()?.session_replay_maskAllImages ?? true
        }
        if !self.isMasked {
            if let cgImage = cgImage {
                if let url = cgImage.NRSessionReplayImageURL {
                    imageURL = url
                } else {
                    let uiImage = UIImage(cgImage: cgImage, scale: swiftUIImage.scale, orientation: swiftUIImage.orientation.toUIImageOrientation())
                    self.image = uiImage
                }
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
        let elementNode = ElementNodeData(id: viewDetails.viewId,
                                          tagName: .image,
                                   attributes: ["id":viewDetails.cssSelector],
                                   childNodes: [])
        elementNode.attributes["style"] = inlineCSSDescription()
        // Create the img element
        let imgNode = ElementNodeData(id: viewDetails.viewId + 1000000, // Use offset to avoid ID conflicts
                                      tagName: .image,
                                      attributes: [:],
                                      childNodes: [])
        imgNode.attributes["style"] = imageInlineCSSDescription()
        if !isMasked {
            if let url = imageURL {
                imgNode.attributes["src"] = url.absoluteString
            } else if let imageData = image?.optimizedPngData() {
                imgNode.attributes["src"] = "data:image/png;base64,\(imageData.base64EncodedString())"
            }
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
        if let url = imageURL {
            imgNode.attributes["src"] = url.absoluteString
        } else {
            if let imageData = image?.optimizedPngData() {
               imgNode.attributes["src"] = "data:image/png;base64,\(imageData.base64EncodedString())"
            }
        }

        // Create and return the container div
        return ElementNodeData(id: viewDetails.viewId,
                               tagName: .div,
                               attributes: ["id": viewDetails.cssSelector],
                               childNodes: [.element(imgNode)])
    }
    
    // Helper to produce stable src representation
    private func currentSrcRepresentation() -> String? {
        guard !isMasked else { return nil }
        if let url = imageURL { return url.absoluteString }
        if let data = image?.optimizedPngData() { return "data:image/png;base64,\(data.base64EncodedString())" }
        return nil
    }
    
    static func imagesOrURLsAreLikelyEqual(lhs: UIImageViewThingy, rhs: UIImageViewThingy) -> Bool {
        if lhs.isMasked && rhs.isMasked { return true }
        if lhs.isMasked != rhs.isMasked { return false }
        if let lURL = lhs.imageURL, let rURL = rhs.imageURL { return lURL == rURL }
        // Fallback: compare optimized PNG data representations
        let ld = lhs.image?.optimizedPngData()
        let rd = rhs.image?.optimizedPngData()
        return ld == rd
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
            let oldSrc = self.currentSrcRepresentation()
            let newSrc = typedOther.currentSrcRepresentation()
            if oldSrc != newSrc, let newSrc = newSrc {
                imgAttributes["src"] = newSrc
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
        return lhs.viewDetails == rhs.viewDetails && UIImageViewThingy.imagesOrURLsAreLikelyEqual(lhs: lhs, rhs: rhs)
    }
}

extension UIImageViewThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
        if let url = imageURL {
            hasher.combine(url.absoluteString)
        } else {
            hasher.combine(image?.hashValue ?? 0)
        }
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


fileprivate var associatedSessionReplayImageURLKey: String = "NRSessionReplayImageURL"

extension UIImage {
    /// Public hook allowing host apps to supply the original remote image URL so Session Replay can reference
    /// the URL instead of embedding base64 image data when possible.
    @objc public var NRSessionReplayImageURL: URL? {
        set {
            withUnsafePointer(to: &associatedSessionReplayImageURLKey) {
                objc_setAssociatedObject(self, $0, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            self.cgImage?.NRSessionReplayImageURL = newValue
        }
        
        get {
            withUnsafePointer(to: &associatedSessionReplayImageURLKey) {
                objc_getAssociatedObject(self, $0) as? URL
            }
        }
    }
}

extension CGImage {
    
    var NRSessionReplayImageURL: URL? {
        set {
            withUnsafePointer(to: &associatedSessionReplayImageURLKey) {
                objc_setAssociatedObject(self, $0, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
        
        get {
            withUnsafePointer(to: &associatedSessionReplayImageURLKey) {
                objc_getAssociatedObject(self, $0) as? URL
            }
        }
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
