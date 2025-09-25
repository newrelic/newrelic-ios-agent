//
//  SwiftUIThingyHeuristics.swift
//  Agent
//
//  Lightweight heuristics to detect SwiftUI-hosted UIViews and extract basic
//  semantic data (text) or fallback image snapshots for Session Replay.
//  NOTE: This deliberately avoids private API. SwiftUI internal view class
//  names are implementation details and may change; we keep logic conservative
//  and cheap. If detection fails we simply fall back to generic UIViewThingy.
//
//

import Foundation
import UIKit
import QuartzCore
import CoreText

public struct ExtractedTextInfo {
    public let labelText: String
    public let fontSize: CGFloat
    public let fontName: String
    public let fontFamily: String
    public let textAlignment: String
    public let textColor: UIColor
    
    var isEmpty: Bool {
        labelText.isEmpty
    }
}

@available(iOS 13.0, *)
enum SwiftUIThingyHeuristics {
    private static let maxSnapshotArea: CGFloat = 1_000_000
    private static let minDimension: CGFloat = 2

    static func isLikelySwiftUIView(_ view: UIView) -> Bool {
        if view is UILabel || view is UIImageView || view is UITextView || view is UITextField || view is UIVisualEffectView { return false }
        let name = NSStringFromClass(type(of: view))
        if name.contains("UIKitNavigationBar") { return false } // UINavigationBar wrapper
        if name.contains("SwiftUI") { return true }
        if name.hasPrefix("_Tt") && name.contains("SwiftUI") { return true }
        if name.contains("UIHosting") { return true }
        return false
    }

    // New: return full text info (text + style)
    static func extractText(from view: UIView) -> ExtractedTextInfo? {
        // 0) Direct, typed UIKit fast-path on the root view
        if let info = textInfoForUIKit(view: view) { return info }

        // 1) Shallow CATextLayer content on the root view’s layer
        if let info = textInfoFromTextLayers(of: view.layer) { return info }

        // 2) Descendant search for common UIKit text-bearing views
        if let info = findDescendantTextInfo(in: view, maxDepth: 3) { return info }

        // 3) Accessibility fallback on self, then descendants
        if let lbl = nonEmpty(view.accessibilityLabel) ?? nonEmpty(view.accessibilityValue) {
            return buildInfo(text: lbl, font: nil, alignment: nil, color: nil)
        }
        if let info = findDescendantAccessibilityText(in: view, maxDepth: 2) { return info }

        return nil
    }

    @MainActor
    static func snapshotIfReasonable(view: UIView) -> UIImage? {
        let size = view.bounds.size
        guard size.width >= minDimension, size.height >= minDimension else { return nil }
        let area = size.width * size.height * UIScreen.main.scale * UIScreen.main.scale
        guard area <= maxSnapshotArea else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            view.layer.render(in: ctx.cgContext)
        }
    }

    // MARK: - UIKit direct extraction

    private static func textInfoForUIKit(view: UIView) -> ExtractedTextInfo? {
        switch view {
        case let label as UILabel:
            let text = preferredString(text: label.text, attributed: label.attributedText)
            return buildInfo(text: text, font: label.font, alignment: label.textAlignment, color: label.textColor)

        case let tv as UITextView:
            let text = preferredString(text: tv.text, attributed: tv.attributedText)
            // UITextView.textColor can be nil; default if needed
            return buildInfo(text: text, font: tv.font, alignment: tv.textAlignment, color: tv.textColor)

        case let tf as UITextField:
            let text = nonEmpty(tf.text) ?? nonEmpty(tf.placeholder) ?? ""
            return buildInfo(text: text, font: tf.font, alignment: tf.textAlignment, color: tf.textColor)

        case let btn as UIButton:
            let text = preferredString(text: btn.currentTitle, attributed: btn.currentAttributedTitle)
            let font = btn.titleLabel?.font
            let align = btn.titleLabel?.textAlignment
            let color = btn.currentTitleColor
            return buildInfo(text: text, font: font, alignment: align, color: color)

        case let seg as UISegmentedControl:
            let idx = seg.selectedSegmentIndex
            var text = ""
            if idx >= 0, idx < seg.numberOfSegments, let t = seg.titleForSegment(at: idx), let ne = nonEmpty(t) {
                text = ne
            } else {
                var titles: [String] = []
                for i in 0..<min(seg.numberOfSegments, 4) {
                    if let t = seg.titleForSegment(at: i), let ne = nonEmpty(t) { titles.append(ne) }
                }
                text = titles.joined(separator: " · ")
            }
            // UISegmentedControl doesn’t expose font/alignment per segment; use defaults
            return buildInfo(text: text, font: nil, alignment: nil, color: nil)

        case let sb as UISearchBar:
            // Try the embedded UITextField for font/color/alignment
            let textField = sb.subviews
                .flatMap { $0.subviews }
                .compactMap { $0 as? UITextField }
                .first
            let text = nonEmpty(sb.text) ?? nonEmpty(sb.placeholder) ?? ""
            return buildInfo(text: text, font: textField?.font, alignment: textField?.textAlignment, color: textField?.textColor)

        default:
            break
        }
        return nil
    }

    // Prefer attributed string’s visible string; otherwise plain text; otherwise empty
    private static func preferredString(text: String?, attributed: NSAttributedString?) -> String {
        if let a = attributed, let s = nonEmpty(a.string) {
            return s
        }
        return nonEmpty(text) ?? ""
    }

    // Use attributed text attributes when available
    private static func textInfoFromAttributed(_ attributed: NSAttributedString?, fallbackFont: UIFont?, fallbackAlign: NSTextAlignment?, fallbackColor: UIColor?) -> (UIFont?, NSTextAlignment?, UIColor?) {
        guard let attributed = attributed, attributed.length > 0 else {
            return (fallbackFont, fallbackAlign, fallbackColor)
        }
        var effectiveRange = NSRange(location: 0, length: 0)
        let attrs = attributed.attributes(at: 0, effectiveRange: &effectiveRange)
        let font = (attrs[.font] as? UIFont) ?? fallbackFont
        let color = (attrs[.foregroundColor] as? UIColor) ?? fallbackColor
        var align = fallbackAlign
        if let paragraph = attrs[.paragraphStyle] as? NSParagraphStyle {
            align = paragraph.alignment
        }
        return (font, align, color)
    }

    // MARK: - CATextLayer extraction

    private static func textInfoFromTextLayers(of layer: CALayer) -> ExtractedTextInfo? {
        guard let sublayers = layer.sublayers, !sublayers.isEmpty else { return nil }
        for sub in sublayers {
            guard let tl = sub as? CATextLayer else { continue }
            let text: String
            if let s = tl.string as? String, let ne = nonEmpty(s) {
                text = ne
            } else if let a = tl.string as? NSAttributedString, let ne = nonEmpty(a.string) {
                text = ne
            } else {
                continue
            }
            // Font
            let fontAndFamily = fontFromCATextLayer(tl)
            // Alignment
            let alignment = tl.alignmentMode
            let alignStr: String
            switch alignment {
            case .left: alignStr = "left"
            case .right: alignStr = "right"
            case .center: alignStr = "center"
            case .justified: alignStr = "justified"
            case .natural: alignStr = "natural"
            default: alignStr = "natural"
            }
            // Color
            let color = (tl.foregroundColor.map { UIColor(cgColor: $0) }) ?? UIColor.label
            let font = UIFont(name: fontAndFamily.name, size: tl.fontSize) ?? UIFont.systemFont(ofSize: tl.fontSize)
            return ExtractedTextInfo(
                labelText: text,
                fontSize: font.pointSize,
                fontName: font.fontName,
                fontFamily: fontAndFamily.family,
                textAlignment: alignStr,
                textColor: color
            )
        }
        return nil
    }

    private static func fontFromCATextLayer(_ tl: CATextLayer) -> (name: String, family: String) {
        guard let anyFont = tl.font else {
            let sys = UIFont.systemFont(ofSize: tl.fontSize)
            return (sys.fontName, sys.familyName)
        }

        let typeID = CFGetTypeID(anyFont)

        if typeID == CTFontGetTypeID() {
            let ct: CTFont = unsafeBitCast(anyFont, to: CTFont.self)
            let name = CTFontCopyPostScriptName(ct) as String
            let family = CTFontCopyFamilyName(ct) as String
            return (name, family)
        } else if typeID == CGFont.typeID {
            let cg: CGFont = unsafeBitCast(anyFont, to: CGFont.self)
            let postScript = (cg.postScriptName as String?) ?? ""
            if let ui = UIFont(name: postScript, size: tl.fontSize) {
                return (ui.fontName, ui.familyName)
            }
            return (postScript, familyNameFrom(fontName: postScript))
        } else if typeID == CFStringGetTypeID() {
            let cf: CFString = unsafeBitCast(anyFont, to: CFString.self)
            let name = cf as String
            if let ui = UIFont(name: name, size: tl.fontSize) {
                return (ui.fontName, ui.familyName)
            }
            return (name, familyNameFrom(fontName: name))
        } else {
            let sys = UIFont.systemFont(ofSize: tl.fontSize)
            return (sys.fontName, sys.familyName)
        }
    }

    // MARK: - Descendant search

    private static func findDescendantTextInfo(in root: UIView, maxDepth: Int) -> ExtractedTextInfo? {
        if maxDepth < 0 { return nil }
        if let info = textInfoForUIKit(view: root) { return info }
        if let info = textInfoFromTextLayers(of: root.layer) { return info }
        guard maxDepth > 0 else { return nil }
        for sub in root.subviews {
            if let info = findDescendantTextInfo(in: sub, maxDepth: maxDepth - 1) { return info }
        }
        return nil
    }

    private static func findDescendantAccessibilityText(in root: UIView, maxDepth: Int) -> ExtractedTextInfo? {
        if maxDepth < 0 { return nil }
        if let lbl = nonEmpty(root.accessibilityLabel) ?? nonEmpty(root.accessibilityValue) {
            return buildInfo(text: lbl, font: nil, alignment: nil, color: nil)
        }
        guard maxDepth > 0 else { return nil }
        for sub in root.subviews {
            if let info = findDescendantAccessibilityText(in: sub, maxDepth: maxDepth - 1) { return info }
        }
        return nil
    }

    // MARK: - Utils

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }

    private static func alignmentString(for align: NSTextAlignment) -> String {
        switch align {
        case .left: return "left"
        case .center: return "center"
        case .right: return "right"
        case .justified: return "justified"
        case .natural: return "natural"
        @unknown default: return "natural"
        }
    }

    private static func familyNameFrom(fontName: String) -> String {
        // Try to construct UIFont to get its family; else split on '-'
        if let f = UIFont(name: fontName, size: 12) { return f.familyName }
        return fontName.split(separator: "-").first.map(String.init) ?? fontName
    }

    private static func buildInfo(text: String, font: UIFont?, alignment: NSTextAlignment?, color: UIColor?) -> ExtractedTextInfo {
        let resolvedFont = font ?? UIFont.preferredFont(forTextStyle: .body)
        let resolvedColor = color ?? UIColor.label
        let alignStr = alignment.map(alignmentString(for:)) ?? "natural"
        return ExtractedTextInfo(
            labelText: text,
            fontSize: resolvedFont.pointSize,
            fontName: resolvedFont.fontName,
            fontFamily: resolvedFont.familyName,
            textAlignment: alignStr,
            textColor: resolvedColor
        )
    }
}
