//
//  UIViewThingy.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 2/5/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit

let DestOutView = "DestOutView"

class UIViewThingy: SessionReplayViewThingy {
    var isMasked: Bool
    var isBlocked: Bool

    var subviews = [any SessionReplayViewThingy]()

    var shouldRecordSubviews: Bool {
        true
    }

    var viewDetails: ViewDetails
    
    init(view: UIView, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        self.isMasked = viewDetails.isMasked ?? false
        self.isBlocked = viewDetails.blockView ?? false
        
        #if os(iOS)
        if #available(iOS 26.0, *), self.viewDetails.viewName.contains(DestOutView) {
            self.viewDetails.backgroundColor = .clear
        }
        #endif
    }

    init(viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        self.isMasked = viewDetails.isMasked ?? false
        self.isBlocked = viewDetails.blockView ?? false
    }
    
    func cssDescription() -> String {
        return "#\(viewDetails.cssSelector) {\(generateBaseCSSStyle())} "
    }
    
    func generateRRWebNode() -> ElementNodeData {
        return ElementNodeData(id: viewDetails.viewId,
                               tagName: .div,
                               attributes: ["id":viewDetails.cssSelector],
                               childNodes: [])
    }
    
    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        let node = generateRRWebNode()
        node.attributes["style"] = generateBaseCSSStyle()
        let addNode: RRWebMutationData.AddRecord = .init(parentId: parentNodeId, nextId: viewDetails.nextId, node: .element(node))
        
        return [addNode]
    }
    
    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? UIViewThingy else {
            return []
        }
        var mutations = [MutationRecord]()
        var allAttributes = [String: String]()
        
        allAttributes["style"] = typedOther.generateBaseCSSStyle()
        
        if !allAttributes.isEmpty {
            let attributeRecord = RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: allAttributes)
            mutations.append(attributeRecord)
        }
        
        return mutations
    }
}

extension UIViewThingy: Equatable {
    static func == (lhs: UIViewThingy, rhs: UIViewThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails
    }
}

extension UIViewThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
    }
}

// MARK: - RasterizedViewThingy

/// Fallback captor for unrecognized UIKit *leaf* views that draw pixels but
/// expose no extractable fill — e.g. custom `draw(_:)`, `CAShapeLayer`-backed
/// views, charts, map tiles, GL/Metal-hosted leaves.
///
/// Without this, such views fall through to `UIViewThingy`, whose only visual
/// property is `viewDetails.backgroundColor`. For these views that color is
/// `nil`/`.clear`, so the replay emits a transparent `<div>` and the content
/// disappears. We instead snapshot the view into a bitmap and emit it as a
/// base64 `<img>`, reusing the same div + img node shape as `UIImageViewThingy`.
///
/// The snapshot is taken once, at capture time, because that is the only point
/// where the live `UIView` is available (`ViewDetails` does not retain it).
///
/// Scope and safeguards live in `shouldRasterize(view:viewDetails:)`:
///   - leaves only (never containers — avoids snapshotting whole subtrees or
///     baking masked descendants into pixels),
///   - never masked or blocked,
///   - only when there is no extractable fill (otherwise `UIViewThingy` is fine),
///   - only when the view actually draws content,
///   - bounded by a per-edge size budget for CPU and payload.
class RasterizedViewThingy: SessionReplayViewThingy {
    // Longest edge of the encoded bitmap. Bounds base64 payload while keeping
    // custom content legible (the 25px `optimizedPngData` default is far too low).
    static let maxEncodedDimension: CGFloat = 400
    // Skip leaves larger than this on either edge — almost certainly containers,
    // and expensive/low-value to rasterize.
    static let maxRasterizableEdge: CGFloat = 1024

    var isMasked: Bool
    var isBlocked: Bool
    var viewDetails: ViewDetails
    var image: UIImage?
    var subviews: [any SessionReplayViewThingy] = []

    // A rasterized leaf is terminal: its pixels already capture everything, so
    // the walk must not descend into (any) subviews and double-record them.
    var shouldRecordSubviews: Bool { false }

    init(viewDetails: ViewDetails, image: UIImage?) {
        self.viewDetails = viewDetails
        self.isMasked = viewDetails.isMasked ?? false
        self.isBlocked = viewDetails.blockView ?? false
        self.image = image
    }

    func cssDescription() -> String {
        return "#\(viewDetails.cssSelector) { \(inlineCSSDescription()) }"
    }

    func inlineCSSDescription() -> String {
        return "\(generateBaseCSSStyle()) display: block;"
    }

    func imageInlineCSSDescription() -> String {
        // The bitmap was captured at the view's bounds, so fill the div exactly.
        return "\(generateBaseCSSStyle()) object-fit: fill; object-position: center;"
    }

    private func encodedImageSrc() -> String? {
        guard let data = image?.optimizedPngData(maxDimension: Self.maxEncodedDimension) else {
            return nil
        }
        return "data:image/png;base64,\(data.base64EncodedString())"
    }

    func generateRRWebNode() -> ElementNodeData {
        let imgNode = ElementNodeData(id: viewDetails.viewId + 1000000, // offset to avoid ID conflicts
                                      tagName: .image,
                                      attributes: [:],
                                      childNodes: [])
        imgNode.attributes["style"] = imageInlineCSSDescription()
        if let src = encodedImageSrc() {
            imgNode.attributes["src"] = src
        }

        return ElementNodeData(id: viewDetails.viewId,
                               tagName: .div,
                               attributes: ["id": viewDetails.cssSelector],
                               childNodes: [.element(imgNode)])
    }

    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        let imgNode = ElementNodeData(id: viewDetails.viewId + 1000000,
                                      tagName: .image,
                                      attributes: [:],
                                      childNodes: [])
        imgNode.attributes["style"] = imageInlineCSSDescription()
        if let src = encodedImageSrc() {
            imgNode.attributes["src"] = src
        }

        let containerNode = ElementNodeData(id: viewDetails.viewId,
                                            tagName: .div,
                                            attributes: ["id": viewDetails.cssSelector],
                                            childNodes: [])
        containerNode.attributes["style"] = inlineCSSDescription()

        let addDivNode: RRWebMutationData.AddRecord = .init(parentId: parentNodeId, nextId: viewDetails.nextId, node: .element(containerNode))
        let addImgNode: RRWebMutationData.AddRecord = .init(parentId: viewDetails.viewId, nextId: nil, node: .element(imgNode))

        return [addDivNode, addImgNode]
    }

    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? RasterizedViewThingy else {
            return []
        }
        var mutations = [MutationRecord]()

        let containerAttributes = ["style": typedOther.inlineCSSDescription()]
        mutations.append(RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: containerAttributes))

        var imgAttributes = ["style": typedOther.imageInlineCSSDescription()]
        if !RasterizedViewThingy.imagesAreLikelyEqual(self.image, typedOther.image),
           let src = typedOther.encodedImageSrc() {
            imgAttributes["src"] = src
        }
        mutations.append(RRWebMutationData.AttributeRecord(id: viewDetails.viewId + 1000000, attributes: imgAttributes))

        return mutations
    }

    static func imagesAreLikelyEqual(_ lhs: UIImage?, _ rhs: UIImage?) -> Bool {
        guard let lhs = lhs, let rhs = rhs else { return lhs == nil && rhs == nil }
        return lhs.optimizedPngData(maxDimension: maxEncodedDimension) == rhs.optimizedPngData(maxDimension: maxEncodedDimension)
    }
}

extension RasterizedViewThingy: Equatable {
    static func == (lhs: RasterizedViewThingy, rhs: RasterizedViewThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails && imagesAreLikelyEqual(lhs.image, rhs.image)
    }
}

extension RasterizedViewThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
        hasher.combine(image?.hashValue ?? 0)
    }
}

// MARK: - Capture-time rasterization (must run on the main thread)

extension RasterizedViewThingy {
    /// Whether an unrecognized view should be rasterized instead of emitted as a
    /// (likely invisible) styled div by `UIViewThingy`. Conservative by design:
    /// every clause below narrows the set so we only pay the snapshot cost when
    /// the view would otherwise vanish from the replay.
    static func shouldRasterize(view: UIView, viewDetails: ViewDetails) -> Bool {
        // Leaves only. A container may hold masked content, and rasterizing it
        // would bake that content into pixels and bloat the frame.
        guard view.subviews.isEmpty else { return false }

        // Never rasterize masked or blocked content.
        guard viewDetails.isMasked != true, viewDetails.blockView != true else { return false }

        // Only when there is no extractable fill. With a real background color,
        // UIViewThingy already reproduces the view as a styled div.
        let hasExtractableFill = viewDetails.backgroundColor != nil && viewDetails.backgroundColor != .clear
        guard !hasExtractableFill else { return false }

        // Per-edge size budget: skip oversized leaves (likely containers; also a
        // CPU/payload guard).
        let frame = viewDetails.frame
        guard frame.width >= 1, frame.height >= 1,
              frame.width <= maxRasterizableEdge, frame.height <= maxRasterizableEdge else {
            return false
        }

        // Must actually draw pixels.
        return viewDrawsContent(view)
    }

    /// Cheap pre-check: does this leaf have any rendered content worth capturing?
    /// Avoids snapshotting empty spacers, gesture overlays, and layout shims.
    private static func viewDrawsContent(_ view: UIView) -> Bool {
        // Backing bitmap from draw(_:) / displayLayer / explicit CGImage contents.
        if view.layer.contents != nil { return true }

        // Vector drawing via a custom layerClass.
        if view.layer is CAShapeLayer || view.layer is CAGradientLayer || view.layer is CATextLayer {
            return true
        }

        // Vector drawing via sublayers.
        if let sublayers = view.layer.sublayers {
            for layer in sublayers where layer is CAShapeLayer || layer is CAGradientLayer || layer is CATextLayer {
                return true
            }
        }

        return false
    }

    /// Snapshot `view` at its current on-screen appearance. Returns nil if the
    /// view has no usable size so the caller can fall back to `UIViewThingy`.
    static func rasterize(view: UIView) -> UIImage? {
        let size = view.bounds.size
        guard size.width >= 1, size.height >= 1 else { return nil }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // afterScreenUpdates:false renders the current presentation without
            // forcing a layout pass — avoids re-entrancy during the capture walk.
            if !view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: false) {
                // Fallback for views drawHierarchy can't snapshot (e.g. layer-only
                // drawing not yet committed to the render server).
                view.layer.render(in: context.cgContext)
            }
        }
    }
}
