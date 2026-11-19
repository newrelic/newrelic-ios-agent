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
        /// Identifies the bitmap, so views compare and hash this rather than the data URL.
        var fingerprint: Int
        /// Slice insets into the bitmap, in pixels: top, right, bottom, left.
        var slice: [CGFloat]
        /// The same insets in points.
        var widths: [CGFloat]
        var isResizable: Bool

        static func == (lhs: BorderImage, rhs: BorderImage) -> Bool {
            lhs.fingerprint == rhs.fingerprint && lhs.slice == rhs.slice
                && lhs.widths == rhs.widths && lhs.isResizable == rhs.isResizable
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(fingerprint)
            hasher.combine(slice)
            hasher.combine(widths)
            hasher.combine(isResizable)
        }
    }

    /// Top, right, bottom, left.
    var edges: [Edge]?
    /// CSS `border-style` for every edge: RCTView draws them all in one style.
    var edgeStyle = "solid"
    var borderImage: BorderImage?
    /// Top-left, top-right, bottom-right, bottom-left.
    var cornerRadii: [CGFloat]?

    /// The inline style. The border bitmap is left to `bitmapCSS`.
    func cssDescription() -> String {
        var css = ""
        if let cornerRadii {
            css += " border-radius: \(cornerRadii.map { String(format: "%.2fpx", $0) }.joined(separator: " "));"
        }
        if let edges {
            css += " box-sizing: border-box;"
            for (side, edge) in zip(["top", "right", "bottom", "left"], edges) where edge.width > 0 {
                css += " border-\(side): \(String(format: "%.2f", edge.width))px \(edgeStyle) \(edge.color);"
            }
        }
        if let borderImage, borderImage.isResizable {
            let widths = borderImage.widths.map { String(format: "%.2fpx", $0) }.joined(separator: " ")
            css += " box-sizing: border-box; border-style: solid; border-color: transparent; border-width: \(widths);"
        }
        return css
    }

    /// Draws the border bitmap, for a stylesheet rule rather than the inline style: inline, its
    /// data URL would be sent again with every other change to the view's style, such as on
    /// every frame of a scroll.
    var bitmapCSS: String? {
        guard let borderImage else { return nil }
        if borderImage.isResizable {
            let slice = borderImage.slice.map { String(format: "%.0f", $0) }.joined(separator: " ")
            let widths = borderImage.widths.map { String(format: "%.2fpx", $0) }.joined(separator: " ")
            return "border-image: url('\(borderImage.dataURL)') \(slice) fill / \(widths) stretch;"
        }
        return "background-image: url('\(borderImage.dataURL)'); background-size: 100% 100%;"
    }

    /// Undoes `bitmapCSS` once a view no longer draws its border bitmap.
    static let noBitmapCSS = "border-image: none; background-image: none;"
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
    // dashed or dotted borders, or a visible border on a view that doesn't clip) it draws
    // into layer.contents, leaving the CALayer border width and corner radius at 0, so read
    // RCTView's own border props instead and resolve them the way RCTView's -bordersAsInsets,
    // -cornerRadii and -borderColorsWithTraitCollection: do.
    private static func paperBorderStyle(for view: UIView) -> ReactNativeBorderStyle? {
        guard view.layer.contents != nil else { return nil }

        // RCTView keeps -1 for an unset width or radius.
        func number(_ key: String) -> CGFloat {
            guard view.responds(to: NSSelectorFromString(key)),
                  let value = view.value(forKey: key) as? NSNumber else { return -1 }
            return CGFloat(value.doubleValue)
        }
        func color(_ key: String) -> UIColor? {
            guard view.responds(to: NSSelectorFromString(key)), let value = view.value(forKey: key) else { return nil }
            if let color = value as? UIColor {
                return color.resolvedColor(with: view.traitCollection)
            }
            // RN before 0.71 stored border colors as CGColorRef.
            if CFGetTypeID(value as CFTypeRef) == CGColor.typeID {
                return UIColor(cgColor: value as! CGColor)
            }
            return nil
        }
        // RCTDefaultIfNegativeTo.
        func value(_ value: CGFloat, or defaultValue: CGFloat) -> CGFloat {
            value >= 0 ? value : defaultValue
        }

        let isRTL = number("reactLayoutDirection") == CGFloat(UIUserInterfaceLayoutDirection.rightToLeft.rawValue)
        // RCTI18nUtil's doLeftAndRightSwapInRTL, which RN turns on unless the app turns it off:
        // then left and right props mean start and end, and swap sides in RTL too.
        let swapsLeftAndRight = UserDefaults.standard.object(forKey: "RCTI18nUtil_makeRTLFlipLeftAndRightStyles") as? Bool ?? true

        let borderWidth = max(0, number("borderWidth"))
        let leftWidth, rightWidth: CGFloat
        if swapsLeftAndRight {
            let startWidth = value(number("borderStartWidth"), or: number("borderLeftWidth"))
            let endWidth = value(number("borderEndWidth"), or: number("borderRightWidth"))
            leftWidth = value(isRTL ? endWidth : startWidth, or: borderWidth)
            rightWidth = value(isRTL ? startWidth : endWidth, or: borderWidth)
        } else {
            leftWidth = value(value(number(isRTL ? "borderEndWidth" : "borderStartWidth"), or: number("borderLeftWidth")), or: borderWidth)
            rightWidth = value(value(number(isRTL ? "borderStartWidth" : "borderEndWidth"), or: number("borderRightWidth")), or: borderWidth)
        }
        let widths = [
            value(number("borderTopWidth"), or: borderWidth),
            rightWidth,
            value(number("borderBottomWidth"), or: borderWidth),
            leftWidth,
        ]

        let leftColor, rightColor: UIColor?
        if swapsLeftAndRight {
            let startColor = color("borderStartColor") ?? color("borderLeftColor")
            let endColor = color("borderEndColor") ?? color("borderRightColor")
            leftColor = isRTL ? endColor : startColor
            rightColor = isRTL ? startColor : endColor
        } else {
            leftColor = color(isRTL ? "borderEndColor" : "borderStartColor") ?? color("borderLeftColor")
            rightColor = color(isRTL ? "borderStartColor" : "borderEndColor") ?? color("borderRightColor")
        }
        let blockColor: UIColor? = color("borderBlockColor")
        let borderColor: UIColor? = color("borderColor")
        let topColor: UIColor? = color("borderBlockStartColor") ?? blockColor ?? color("borderTopColor")
        let bottomColor: UIColor? = color("borderBlockEndColor") ?? blockColor ?? color("borderBottomColor")
        let colors: [UIColor?] = [topColor ?? borderColor, rightColor ?? borderColor, bottomColor ?? borderColor, leftColor ?? borderColor]

        let radius = max(0, number("borderRadius"))
        let topStartRadius = value(number("borderTopStartRadius"), or: number("borderStartStartRadius"))
        let topEndRadius = value(number("borderTopEndRadius"), or: number("borderStartEndRadius"))
        let bottomStartRadius = value(number("borderBottomStartRadius"), or: number("borderEndStartRadius"))
        let bottomEndRadius = value(number("borderBottomEndRadius"), or: number("borderEndEndRadius"))
        var topLeftRadius, topRightRadius, bottomRightRadius, bottomLeftRadius: CGFloat
        if swapsLeftAndRight {
            let topStart = value(topStartRadius, or: number("borderTopLeftRadius"))
            let topEnd = value(topEndRadius, or: number("borderTopRightRadius"))
            let bottomStart = value(bottomStartRadius, or: number("borderBottomLeftRadius"))
            let bottomEnd = value(bottomEndRadius, or: number("borderBottomRightRadius"))
            topLeftRadius = value(isRTL ? topEnd : topStart, or: radius)
            topRightRadius = value(isRTL ? topStart : topEnd, or: radius)
            bottomRightRadius = value(isRTL ? bottomStart : bottomEnd, or: radius)
            bottomLeftRadius = value(isRTL ? bottomEnd : bottomStart, or: radius)
        } else {
            topLeftRadius = value(value(isRTL ? topEndRadius : topStartRadius, or: number("borderTopLeftRadius")), or: radius)
            topRightRadius = value(value(isRTL ? topStartRadius : topEndRadius, or: number("borderTopRightRadius")), or: radius)
            bottomRightRadius = value(value(isRTL ? bottomStartRadius : bottomEndRadius, or: number("borderBottomRightRadius")), or: radius)
            bottomLeftRadius = value(value(isRTL ? bottomEndRadius : bottomStartRadius, or: number("borderBottomLeftRadius")), or: radius)
        }
        // RCTView scales the radii down so adjacent corners don't overlap.
        func scale(_ length: CGFloat, _ radii: CGFloat) -> CGFloat {
            let factor = min(1, length / radii)
            return factor.isNaN ? 0 : factor
        }
        let size = view.bounds.size
        let top = scale(size.width, topLeftRadius + topRightRadius)
        let bottom = scale(size.width, bottomLeftRadius + bottomRightRadius)
        let right = scale(size.height, topRightRadius + bottomRightRadius)
        let left = scale(size.height, topLeftRadius + bottomLeftRadius)
        topLeftRadius *= min(top, left)
        topRightRadius *= min(top, right)
        bottomRightRadius *= min(bottom, right)
        bottomLeftRadius *= min(bottom, left)
        let radii = [topLeftRadius, topRightRadius, bottomRightRadius, bottomLeftRadius]

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
        // RCTBorderStyle: unset, solid, dotted, dashed.
        switch number("borderStyle") {
        case 2: style.edgeStyle = "dotted"
        case 3: style.edgeStyle = "dashed"
        default: break
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
        var hasher = Hasher()
        hasher.combine(png)

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
                                                             fingerprint: hasher.finalize(),
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
        if let fabricParagraphClass, view.isKind(of: fabricParagraphClass) {
            return fabricContentFrame(of: view)
        }
        return nil
    }

    // RCTParagraphComponentView draws the text at its layout's content frame, which only its
    // C++ `LayoutMetrics _layoutMetrics` ivar holds (its text view's frame is its whole bounds).
    // That struct opens with the frame and then the content insets, border plus padding, all
    // CGFloats; this is its type encoding up to there. Read it only while it's still laid out so.
    private static let layoutMetricsPrefix = #"{LayoutMetrics="frame"{Rect="origin"{Point="x"d"y"d}"size"{Size="width"d"height"d}}"contentInsets"{RectangleEdges<double>="left"d"top"d"right"d"bottom"d}"#
    private static var layoutMetricsOffsets = [ObjectIdentifier: Int?]()

    private static func layoutMetricsOffset(in viewClass: AnyClass) -> Int? {
        let key = ObjectIdentifier(viewClass)
        if let offset = layoutMetricsOffsets[key] {
            return offset
        }
        var offset: Int?
        if let ivar = class_getInstanceVariable(viewClass, "_layoutMetrics"),
           let encoding = ivar_getTypeEncoding(ivar),
           String(cString: encoding).hasPrefix(layoutMetricsPrefix) {
            offset = ivar_getOffset(ivar)
        }
        layoutMetricsOffsets[key] = offset
        return offset
    }

    private static func fabricContentFrame(of view: UIView) -> CGRect? {
        guard let offset = layoutMetricsOffset(in: type(of: view)) else { return nil }
        let layoutMetrics = UnsafeRawPointer(Unmanaged.passUnretained(view).toOpaque()) + offset
        func field(_ index: Int) -> CGFloat {
            layoutMetrics.load(fromByteOffset: index * MemoryLayout<CGFloat>.stride, as: CGFloat.self)
        }
        let size = CGSize(width: field(2), height: field(3))
        let left = field(4), top = field(5), right = field(6), bottom = field(7)
        let content = CGRect(x: left, y: top, width: size.width - left - right, height: size.height - top - bottom)
        // The layout RN last gave the view, or the read went wrong.
        guard abs(size.width - view.bounds.width) < 1, abs(size.height - view.bounds.height) < 1,
              min(left, top, right, bottom) >= 0, content.width >= 0, content.height >= 0 else { return nil }
        return content
    }

    // MARK: SVG

    /// Rasterizes a react-native-svg view, which draws its whole tree in drawRect.
    /// Returns the previous image while the drawing is unchanged, so it isn't re-encoded
    /// or re-sent every frame.
    static func renderedImage(of view: UIView) -> UIImage? {
        let size = view.bounds.size
        guard size.width > 0, size.height > 0 else { return nil }

        if countsSVGDraws {
            let drawCount = view.sessionReplaySVGDrawCount
            if let cached = view.sessionReplaySVGSnapshot, cached.version == drawCount, cached.image.size == size {
                return cached.image
            }
            let image = render(view, size: size)
            view.sessionReplaySVGSnapshot = SVGSnapshot(version: drawCount, image: image)
            return image
        }

        // Without the draw count, render every time and compare the pixels.
        let image = render(view, size: size)
        guard let pixels = image.cgImage?.dataProvider?.data as Data? else { return image }
        var hasher = Hasher()
        pixels.withUnsafeBytes { hasher.combine(bytes: $0) }
        let fingerprint = hasher.finalize()
        if let cached = view.sessionReplaySVGSnapshot, cached.version == fingerprint, cached.image.size == size {
            return cached.image
        }
        view.sessionReplaySVGSnapshot = SVGSnapshot(version: fingerprint, image: image)
        return image
    }

    private static func render(_ view: UIView, size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            view.layer.render(in: context.cgContext)
        }
    }

    // A redraw updates the layer's backing store in place, so nothing the recorder can see
    // cheaply changes when the drawing does. Counting the SVG view's drawRect calls tells it
    // when to rasterize again. Only when the class implements drawRect itself, so no other
    // class's drawRect is ever replaced.
    private static let countsSVGDraws: Bool = {
        let selector = #selector(UIView.draw(_:))
        guard let svgViewClass, let superclass = class_getSuperclass(svgViewClass),
              let method = class_getInstanceMethod(svgViewClass, selector),
              method_getImplementation(method) != class_getMethodImplementation(superclass, selector) else {
            return false
        }
        typealias DrawRect = @convention(c) (UIView, Selector, CGRect) -> Void
        let drawRect = unsafeBitCast(method_getImplementation(method), to: DrawRect.self)
        let countingDrawRect: @convention(block) (UIView, CGRect) -> Void = { view, rect in
            drawRect(view, selector, rect)
            view.sessionReplaySVGDrawCount &+= 1
        }
        method_setImplementation(method, imp_implementationWithBlock(countingDrawRect))
        return true
    }()
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
    /// The draw count, or the pixels' fingerprint, the image was taken at.
    let version: Int
    let image: UIImage

    init(version: Int, image: UIImage) {
        self.version = version
        self.image = image
    }
}

fileprivate var associatedBorderImageCacheKey: String = "SessionReplayRNBorderImage"
fileprivate var associatedSVGSnapshotKey: String = "SessionReplayRNSVGSnapshot"
fileprivate var associatedSVGDrawCountKey: String = "SessionReplayRNSVGDrawCount"

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
    var sessionReplaySVGDrawCount: Int {
        get {
            withUnsafePointer(to: &associatedSVGDrawCountKey) {
                (objc_getAssociatedObject(self, $0) as? NSNumber)?.intValue ?? 0
            }
        }
        set {
            withUnsafePointer(to: &associatedSVGDrawCountKey) {
                objc_setAssociatedObject(self, $0, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }

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
