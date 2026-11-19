//
//  ReactNativeStyle.swift
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation
import UIKit

/// Borders and corner radii a React Native view draws itself rather than through the
/// `CALayer` border properties the recorders read, rendered as CSS. NR-652282.
struct ReactNativeBorderStyle: Hashable {
    struct Edge: Hashable {
        var width: CGFloat
        var color: String
    }

    /// RN's own border bitmap (New Architecture), applied as a CSS `border-image`.
    struct BorderImage: Hashable {
        var dataURL: String
        /// Slice insets into the bitmap, in pixels: top, right, bottom, left.
        var slice: [CGFloat]
        /// The same insets in points.
        var widths: [CGFloat]
        var isResizable: Bool
    }

    /// Top, right, bottom, left.
    var edges: [Edge]?
    var borderImage: BorderImage?
    /// Top-left, top-right, bottom-right, bottom-left.
    var cornerRadii: [CGFloat]?

    func cssDescription() -> String {
        var css = ""
        if let cornerRadii {
            css += " border-radius: \(cornerRadii.map { String(format: "%.2fpx", $0) }.joined(separator: " "));"
        }
        if let edges {
            css += " box-sizing: border-box;"
            for (side, edge) in zip(["top", "right", "bottom", "left"], edges) where edge.width > 0 {
                css += " border-\(side): \(String(format: "%.2f", edge.width))px solid \(edge.color);"
            }
        }
        if let borderImage {
            if borderImage.isResizable {
                let slice = borderImage.slice.map { String(format: "%.0f", $0) }.joined(separator: " ")
                let widths = borderImage.widths.map { String(format: "%.2fpx", $0) }.joined(separator: " ")
                css += " box-sizing: border-box; border-style: solid; border-color: transparent; border-width: \(widths);"
                css += " border-image: url('\(borderImage.dataURL)') \(slice) fill / \(widths) stretch;"
            } else {
                css += " background-image: url('\(borderImage.dataURL)'); background-size: 100% 100%;"
            }
        }
        return css
    }
}

/// Reads the styling React Native keeps outside the UIKit properties the recorders use.
/// Every lookup is by class name and guarded, since the agent doesn't link React Native.
enum ReactNativeStyle {
    // Old architecture (Paper) view and text classes.
    private static let paperViewClass: AnyClass? = NSClassFromString("RCTView")
    private static let paperTextViewClass: AnyClass? = NSClassFromString("RCTTextView")
    // New Architecture (Fabric) view and text classes.
    private static let fabricViewClass: AnyClass? = NSClassFromString("RCTViewComponentView")
    private static let fabricParagraphClass: AnyClass? = NSClassFromString("RCTParagraphComponentView")
    // react-native-svg's root view, the same class on both architectures.
    private static let svgViewClass: AnyClass? = NSClassFromString("RNSVGSvgView")

    // RCTViewComponentView puts its background and border layers at these z positions
    // (BACKGROUND_COLOR_ZPOSITION, and one above it).
    static let fabricBackgroundLayerZPosition: CGFloat = -1024
    static let fabricBorderLayerZPosition: CGFloat = -1023

    static func isSVGView(_ view: UIView) -> Bool {
        guard let svgViewClass else { return false }
        return view.isKind(of: svgViewClass)
    }

    static func borderStyle(for view: UIView) -> ReactNativeBorderStyle? {
        if let paperViewClass, view.isKind(of: paperViewClass) {
            return paperBorderStyle(for: view)
        }
        if let fabricViewClass, view.isKind(of: fabricViewClass) {
            return fabricBorderStyle(for: view)
        }
        return nil
    }

    // MARK: Old architecture

    // RCTView applies uniform borders and radii through the CALayer border properties,
    // which ViewDetails already records. Anything else (per-edge borders, per-corner radii,
    // or a visible border on a view that doesn't clip) it draws into layer.contents,
    // leaving the CALayer border width and corner radius at 0, so read RCTView's own
    // border props instead.
    private static func paperBorderStyle(for view: UIView) -> ReactNativeBorderStyle? {
        guard view.layer.contents != nil else { return nil }

        func number(_ key: String) -> CGFloat? {
            guard view.responds(to: NSSelectorFromString(key)) else { return nil }
            return (view.value(forKey: key) as? NSNumber).map { CGFloat($0.doubleValue) }
        }
        func color(_ key: String) -> UIColor? {
            guard view.responds(to: NSSelectorFromString(key)), let value = view.value(forKey: key) else { return nil }
            if let color = value as? UIColor {
                return color
            }
            // RN before 0.71 stored border colors as CGColorRef.
            if CFGetTypeID(value as CFTypeRef) == CGColor.typeID {
                return UIColor(cgColor: value as! CGColor)
            }
            return nil
        }
        // RCTView uses -1 for "not set": fall back to the next more general prop.
        func resolved(_ values: CGFloat?...) -> CGFloat {
            for value in values {
                if let value, value >= 0 { return value }
            }
            return 0
        }

        let borderWidth = number("borderWidth")
        let widths = [
            resolved(number("borderTopWidth"), borderWidth),
            resolved(number("borderRightWidth"), number("borderEndWidth"), borderWidth),
            resolved(number("borderBottomWidth"), borderWidth),
            resolved(number("borderLeftWidth"), number("borderStartWidth"), borderWidth),
        ]
        let borderColor = color("borderColor")
        let colors = [
            color("borderTopColor") ?? borderColor,
            color("borderRightColor") ?? color("borderEndColor") ?? borderColor,
            color("borderBottomColor") ?? borderColor,
            color("borderLeftColor") ?? color("borderStartColor") ?? borderColor,
        ]
        let borderRadius = number("borderRadius")
        let radii = [
            resolved(number("borderTopLeftRadius"), borderRadius),
            resolved(number("borderTopRightRadius"), borderRadius),
            resolved(number("borderBottomRightRadius"), borderRadius),
            resolved(number("borderBottomLeftRadius"), borderRadius),
        ]

        var style = ReactNativeBorderStyle()
        if radii.contains(where: { $0 > 0 }) {
            style.cornerRadii = radii
        }
        // RN draws no border for an edge without a color (or with a clear one).
        let edges = zip(widths, colors).map { width, color -> ReactNativeBorderStyle.Edge in
            guard let color, color.cgColor.alpha > 0 else {
                return ReactNativeBorderStyle.Edge(width: 0, color: "")
            }
            return ReactNativeBorderStyle.Edge(width: width, color: color.toHexString(includingAlpha: true))
        }
        if edges.contains(where: { $0.width > 0 }) {
            style.edges = edges
        }
        return (style.edges == nil && style.cornerRadii == nil) ? nil : style
    }

    // MARK: New Architecture

    // RCTViewComponentView draws non-CALayer borders into a bitmap on a border sublayer
    // and shapes a separate background sublayer, again leaving the view's own layer
    // border width and corner radius at 0. The bitmap is a 9-slice image (contentsCenter),
    // which CSS border-image reproduces, including dashed borders and per-corner radii.
    private static func fabricBorderStyle(for view: UIView) -> ReactNativeBorderStyle? {
        guard let sublayers = view.layer.sublayers else { return nil }

        var style = ReactNativeBorderStyle()
        if let backgroundLayer = sublayers.first(where: { $0.zPosition == fabricBackgroundLayerZPosition }),
           backgroundLayer.cornerRadius > 0 {
            style.cornerRadii = Array(repeating: backgroundLayer.cornerRadius, count: 4)
        }
        if let borderLayer = sublayers.first(where: { $0.zPosition == fabricBorderLayerZPosition }),
           let contents = borderLayer.contents,
           CFGetTypeID(contents as CFTypeRef) == CGImage.typeID {
            style.borderImage = borderImage(of: borderLayer, image: contents as! CGImage)
        }
        return (style.borderImage == nil && style.cornerRadii == nil) ? nil : style
    }

    private static func borderImage(of layer: CALayer, image: CGImage) -> ReactNativeBorderStyle.BorderImage? {
        // RN builds a new bitmap on every layout; keep the encoded one while it's the same image.
        if let cached = layer.sessionReplayBorderImageCache, cached.image === image {
            return cached.borderImage
        }
        guard let png = UIImage(cgImage: image).pngData() else { return nil }

        let width = CGFloat(image.width), height = CGFloat(image.height)
        let center = layer.contentsCenter
        let isResizable = center != CGRect(x: 0, y: 0, width: 1, height: 1)
        let slice = [
            (center.minY * height).rounded(),
            ((1 - center.maxX) * width).rounded(),
            ((1 - center.maxY) * height).rounded(),
            (center.minX * width).rounded(),
        ]
        let scale = layer.contentsScale > 0 ? layer.contentsScale : 1
        let borderImage = ReactNativeBorderStyle.BorderImage(dataURL: "data:image/png;base64,\(png.base64EncodedString())",
                                                             slice: slice,
                                                             widths: slice.map { $0 / scale },
                                                             isResizable: isResizable)
        layer.sessionReplayBorderImageCache = BorderImageCache(image: image, borderImage: borderImage)
        return borderImage
    }

    // MARK: Text

    /// The rect, in the text view's own coordinates, that RN draws the text in: its
    /// bounds inset by the Text's padding (and border).
    static func textContentFrame(of view: UIView) -> CGRect? {
        if let paperTextViewClass, view.isKind(of: paperTextViewClass),
           class_getInstanceVariable(type(of: view), "_contentFrame") != nil,
           let value = view.value(forKey: "contentFrame") as? NSValue {
            return value.cgRectValue
        }
        if let fabricParagraphClass, view.isKind(of: fabricParagraphClass),
           view.responds(to: NSSelectorFromString("contentView")),
           let contentView = view.value(forKey: "contentView") as? UIView,
           contentView.superview === view {
            return contentView.frame
        }
        return nil
    }

    // MARK: SVG

    /// Rasterizes a react-native-svg view, which draws its whole tree in drawRect.
    /// Returns the previous image while the drawing is unchanged, so it isn't re-encoded
    /// or re-sent every frame.
    static func renderedImage(of view: UIView) -> UIImage? {
        let size = view.bounds.size
        guard size.width > 0, size.height > 0 else { return nil }

        let image = UIGraphicsImageRenderer(size: size).image { context in
            view.layer.render(in: context.cgContext)
        }
        guard let pixels = image.cgImage?.dataProvider?.data as Data? else { return image }
        var hasher = Hasher()
        pixels.withUnsafeBytes { hasher.combine(bytes: $0) }
        let fingerprint = hasher.finalize()
        if let cached = view.sessionReplaySVGSnapshot, cached.fingerprint == fingerprint, cached.image.size == size {
            return cached.image
        }
        view.sessionReplaySVGSnapshot = SVGSnapshot(fingerprint: fingerprint, image: image)
        return image
    }
}

private final class BorderImageCache {
    let image: CGImage
    let borderImage: ReactNativeBorderStyle.BorderImage

    init(image: CGImage, borderImage: ReactNativeBorderStyle.BorderImage) {
        self.image = image
        self.borderImage = borderImage
    }
}

private final class SVGSnapshot {
    let fingerprint: Int
    let image: UIImage

    init(fingerprint: Int, image: UIImage) {
        self.fingerprint = fingerprint
        self.image = image
    }
}

fileprivate var associatedBorderImageCacheKey: String = "SessionReplayRNBorderImage"
fileprivate var associatedSVGSnapshotKey: String = "SessionReplayRNSVGSnapshot"

private extension CALayer {
    var sessionReplayBorderImageCache: BorderImageCache? {
        get {
            withUnsafePointer(to: &associatedBorderImageCacheKey) {
                objc_getAssociatedObject(self, $0) as? BorderImageCache
            }
        }
        set {
            withUnsafePointer(to: &associatedBorderImageCacheKey) {
                objc_setAssociatedObject(self, $0, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
}

private extension UIView {
    var sessionReplaySVGSnapshot: SVGSnapshot? {
        get {
            withUnsafePointer(to: &associatedSVGSnapshotKey) {
                objc_getAssociatedObject(self, $0) as? SVGSnapshot
            }
        }
        set {
            withUnsafePointer(to: &associatedSVGSnapshotKey) {
                objc_setAssociatedObject(self, $0, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
}
