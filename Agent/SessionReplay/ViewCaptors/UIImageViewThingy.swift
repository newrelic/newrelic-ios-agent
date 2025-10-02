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
        } else {
            self.isMasked = NRMAHarvestController.configuration()?.session_replay_maskAllImages ?? true
        }
        if !self.isMasked {
            if let url = view.image?.NRSessionReplayImageURL {
                imageURL = url
            } else {
                self.image = (view.image ?? nil)
            }
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
        if !isMasked {
            if let url = imageURL {
                elementNode.attributes["src"] = url.absoluteString
            } else if let imageData = image?.optimizedPngData() {
                elementNode.attributes["src"] = "data:image/png;base64,\(imageData.base64EncodedString())"
            }
        }
        
        let addElementNode: RRWebMutationData.AddRecord = .init(parentId: parentNodeId, nextId: viewDetails.nextId, node: .element(elementNode))

        return [addElementNode]
    }
    
    func generateRRWebNode() -> ElementNodeData {
        if isMasked {
            return ElementNodeData(id: viewDetails.viewId,
                                   tagName: .image,
                                   attributes: ["id":viewDetails.cssSelector],
                                   childNodes: [])
        }
        if let url = imageURL {
            return ElementNodeData(id: viewDetails.viewId,
                                   tagName: .image,
                                   attributes: ["id":viewDetails.cssSelector, "src": url.absoluteString],
                                   childNodes: [])
        } else if let imageData = image?.optimizedPngData() {
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
        var allAttributes = [String: String]()
        
        allAttributes["style"] = typedOther.inlineCSSDescription()

        if !typedOther.isMasked {
            let oldSrc = self.currentSrcRepresentation()
            let newSrc = typedOther.currentSrcRepresentation()
            if oldSrc != newSrc, let newSrc = newSrc {
                allAttributes["src"] = newSrc
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


fileprivate var associatedSessionReplayImageURLKey: String = "NRSessionReplayImageURL"

extension UIImage {
    /// Public hook allowing host apps to supply the original remote image URL so Session Replay can reference
    /// the URL instead of embedding base64 image data when possible.
    public var NRSessionReplayImageURL: URL? {
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
