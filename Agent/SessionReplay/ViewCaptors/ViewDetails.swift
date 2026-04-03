//
//  NRMAUIViewDetails.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 1/16/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit
@_implementationOnly import NewRelicPrivate

struct ViewDetails {
    var viewId: Int
    var frame: CGRect
    var backgroundColor: UIColor?
    let alpha: CGFloat
    let isHidden: Bool
    let cornerRadius: CGFloat
    let maskedCorners: CACornerMask
    let borderWidth: CGFloat
    let borderColor: UIColor?
    let viewName: String
    let parentId: Int?
    var nextId: Int?
    let clip: CGRect

    // Indicates if this view should have its content masked in session replay
    var isMasked: Bool?

    // swiftUI masking support
    var maskApplicationText: Bool?
    var maskUserInputText: Bool?
    var maskAllImages: Bool?
    var maskAllUserTouches: Bool?
    var blockView: Bool?

    // Custom identifier for the view (from NRMaskingView view)
    var viewIdentifier: String?

    var cssSelector: String {
        return "\(self.viewName)-\(self.viewId)"
    }
    
    static private func sanitizeViewNameForCSS(_ viewName: String) -> String {
        // First, simplify common SwiftUI and framework prefixes
        var sanitized = viewName
            .replacingOccurrences(of: "SwiftUI.", with: "")
            .replacingOccurrences(of: "NewRelic.", with: "NR")
            .replacingOccurrences(of: "UIKit.", with: "UI")
        
        // Use regex to replace all invalid CSS identifier characters with underscores
        // Valid CSS identifiers can contain: letters, digits, hyphens, underscores
        // But cannot start with a digit or hyphen
        sanitized = sanitized.replacingOccurrences(
            of: "[^a-zA-Z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        
        // Remove consecutive underscores and hyphens
        sanitized = sanitized.replacingOccurrences(
            of: "[_-]+",
            with: "_",
            options: .regularExpression
        )
        
        // Trim leading/trailing underscores and hyphens
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        
        // Ensure it doesn't start with a number or hyphen (invalid CSS identifier)
        if sanitized.isEmpty || sanitized.first?.isNumber == true || sanitized.hasPrefix("-") {
            sanitized = "view_\(sanitized)"
        }
        
        // Limit length to prevent extremely long IDs that could cause performance issues
        let maxLength = 50
        if sanitized.count > maxLength {
            sanitized = String(sanitized.prefix(maxLength))
        }
        
        // Fallback if somehow we end up with empty string
        return sanitized.isEmpty ? "view" : sanitized
    }

    /// CSS string for corner radius, respecting `maskedCorners`.
    /// When all four corners are masked (default) emits `border-radius: Xpx;`.
    /// When only a subset is masked, emits individual per-corner properties.
    var cornerRadiusCSS: String {
        let allCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                                        .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        let r = String(format: "%.2f", cornerRadius)
        if maskedCorners == allCorners {
            return "border-radius: \(r)px;"
        }
        let tl = maskedCorners.contains(.layerMinXMinYCorner) ? r : "0"
        let tr = maskedCorners.contains(.layerMaxXMinYCorner) ? r : "0"
        let bl = maskedCorners.contains(.layerMinXMaxYCorner) ? r : "0"
        let br = maskedCorners.contains(.layerMaxXMaxYCorner) ? r : "0"
        return "border-top-left-radius: \(tl)px; border-top-right-radius: \(tr)px; border-bottom-left-radius: \(bl)px; border-bottom-right-radius: \(br)px;"
    }

    /// Writes per-corner border-radius entries into `dict` for mutation diffing.
    func applyCornerRadiusDifferences(to dict: inout [String: String]) {
        let allCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                                        .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        let r = "\(String(format: "%.2f", cornerRadius))px"
        if maskedCorners == allCorners {
            dict["border-radius"] = r
        } else {
            dict["border-top-left-radius"]     = maskedCorners.contains(.layerMinXMinYCorner) ? r : "0px"
            dict["border-top-right-radius"]    = maskedCorners.contains(.layerMaxXMinYCorner) ? r : "0px"
            dict["border-bottom-left-radius"]  = maskedCorners.contains(.layerMinXMaxYCorner) ? r : "0px"
            dict["border-bottom-right-radius"] = maskedCorners.contains(.layerMaxXMaxYCorner) ? r : "0px"
        }
    }

    var isVisible: Bool {
        !isHidden &&
        alpha > 0 &&
        frame != .zero &&
        !frame.intersection(clip).isEmpty
    }

    var isClear: Bool {
        backgroundColor == .clear || alpha == 0
    }

    init(view: UIView) {
        if let superview = view.superview, let window = view.window {
            let rawFrame = superview.convert(view.frame, to: window)
            let clippingRect = ViewDetails.getClippingRect(for: view, in: window)
            
            let visibleFrame = rawFrame.intersection(clippingRect)
            
            self.frame = visibleFrame.isNull ? .zero : visibleFrame
            self.clip = clippingRect
        }
        else {
            self.frame = view.frame
            self.clip = view.bounds
        }
        backgroundColor = view.backgroundColor
        alpha = view.alpha
        isHidden = view.isHidden
        let layerCornerRadius = view.layer.effectiveCornerRadius
        // UICollectionView list cells render section-card corner rounding via Core Graphics
        // (not CALayer.cornerRadius), so we synthesize it from the cell's section position.
        if layerCornerRadius == 0,
           let (synthesized, synthesizedMask) = ViewDetails.listCellCornerRadius(for: view) {
            cornerRadius = synthesized
            maskedCorners = synthesizedMask
        } else {
            cornerRadius = layerCornerRadius
            maskedCorners = view.layer.effectiveMaskedCorners
        }
        borderWidth = view.layer.borderWidth

        // Checking if we have a border, because asking for the layer's
        // border color will always give us something
        if view.layer.borderWidth > 0, let borderColor = view.layer.borderColor {
            self.borderColor = UIColor(cgColor: borderColor)
        }
        else {
            self.borderColor = nil
        }

        let sanitizedViewName = ViewDetails.sanitizeViewNameForCSS(String(describing: type(of: view)))
        viewName = sanitizedViewName

        if let identifier = view.sessionReplayIdentifier {
            viewId = identifier
        }
        else {
            viewId = IDGenerator.shared.getId()
            view.sessionReplayIdentifier = viewId
        }
        
        self.parentId = view.superview?.sessionReplayIdentifier
        
        if let maskApplicationText = ViewDetails.checkMaskApplicationText(view: view) {
            self.maskApplicationText = maskApplicationText
            view.maskApplicationText = maskApplicationText
        }

        if let maskUserInputText = ViewDetails.checkMaskUserInputText(view: view) {
            self.maskUserInputText = maskUserInputText
            view.maskUserInputText = maskUserInputText
        }
        
        if let maskAllImages = ViewDetails.checkMaskAllImages(view: view) {
            self.maskAllImages = maskAllImages
            view.maskAllImages = maskAllImages
        }
        
        if let maskAllUserTouches = ViewDetails.checkMaskAllUserTouches(view: view) {
            self.maskAllUserTouches = maskAllUserTouches
            view.maskAllUserTouches = maskAllUserTouches
        }

        if let blockView = ViewDetails.checkBlockView(view: view) {
            self.blockView = blockView
            view.blockView = blockView
        }

        if let shouldMask = ViewDetails.checkIsMasked(view: view, viewName: viewName) {
            self.isMasked = shouldMask
            view.sessionReplayMaskState = shouldMask
        }
    }
    
    init(frame: CGRect, clip: CGRect, backgroundColor: UIColor, alpha: CGFloat, isHidden: Bool, viewName: String, parentId: Int, cornerRadius: CGFloat, borderWidth: CGFloat, borderColor: UIColor? = nil, viewId: Int?, view: UIView? = nil,
          maskedCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner],
          maskApplicationText: Bool?,
          maskUserInputText: Bool?,
          maskAllImages: Bool?,
          maskAllUserTouches: Bool?,
          blockView: Bool?,
          sessionReplayIdentifier: String?) {

        let visibleFrame = frame.intersection(clip)

        self.frame = visibleFrame.isNull ? .zero : visibleFrame
        self.clip = clip

        self.backgroundColor = backgroundColor
        self.alpha = alpha
        self.isHidden = isHidden
        self.cornerRadius = cornerRadius
        self.maskedCorners = maskedCorners
        self.borderWidth = borderWidth

        self.borderColor = borderColor

        self.viewName = viewName

        if let identifier = viewId {
            self.viewId = identifier
        }
        else {
            self.viewId = IDGenerator.shared.getId()
        }

        self.parentId = parentId
        
        self.maskApplicationText = maskApplicationText
        self.maskUserInputText = maskUserInputText
        self.maskAllImages = maskAllImages
        self.maskAllUserTouches = maskAllUserTouches
        self.blockView = blockView

        if let sessionReplayIdentifier = sessionReplayIdentifier {
            guard let agent = NewRelicAgentInternal.sharedInstance() else { return }
            // Check for accessibility identifier in the unmasking list
            if agent.isAccessibilityIdentifierUnmasked(sessionReplayIdentifier) {
                self.isMasked = false
            }
            // Check for accessibility identifier in the masking list
            if agent.isAccessibilityIdentifierMasked(sessionReplayIdentifier) {
                self.isMasked = true
            }
        }
    }

    
    // This function checks if there are any specfic masking rules assigned to a view. If it returns nils, the masking value will be assigned based on the value of the global based on it's type later.
    private static func checkIsMasked(view: UIView, viewName: String) -> Bool? {
        // Determine if this view should be masked
        guard let agent = NewRelicAgentInternal.sharedInstance() else { return true }
        guard let config = NRMAHarvestController.configuration() else { return true }

        // If masking is in default mode we want to use the default value which is determined by the global for it's type.
        if config.session_replay_mode as SessionReplayMaskingMode == SessionReplayMaskingMode.default {
            return nil
        }
        
        // Handle decision for masking based on accessibility identifier in this section.
        if let accessibilityId = view.accessibilityIdentifier,
           accessibilityId.count > 0,
           accessibilityId == "nr-mask" || accessibilityId.hasSuffix(".nr-mask") {
            //This view is explicitly marked to be masked.
            return true
        }

        // Check for accessibility identifier in the masking list
        if let accessibilityId = view.accessibilityIdentifier,
           agent.isAccessibilityIdentifierMasked(accessibilityId) {
            return true
        }
        
        // Check for class name in the masking list if not already masked
        if agent.isClassNameMasked(viewName) {
            return true
        }

        // Handle decision for masking based on accessibility identifier in this section.
        if let accessibilityId = view.accessibilityIdentifier,
           accessibilityId.count > 0,
           accessibilityId == "nr-unmask" || accessibilityId.hasSuffix(".nr-unmask") {
            //This view is explicitly marked to not be masked.
            return false
        }
        
        // Check for accessibility identifier in the masking list
        if let accessibilityId = view.accessibilityIdentifier,
           agent.isAccessibilityIdentifierUnmasked(accessibilityId) {
            return false
        }
        
        // Check for class name in the unmasking list
        if agent.isClassNameUnmasked(viewName) {
            return false
        }
        
        // Check if parent is marked as masked or unmasked (propagate masking status to children)
        if let parentView = view.superview,
           let parentMasked = parentView.sessionReplayMaskState {
            return parentMasked
        }
        
        // Return nil if no custom masked setting is found
        return nil
    }
    
    private static func checkMaskApplicationText(view: UIView) -> Bool? {
        
        if let maskApplicationText = view.maskApplicationText {
            return maskApplicationText
        }
        
        if let parentView = view.superview,
           let parentMasked = parentView.maskApplicationText {
            return parentMasked
        }
        
        return nil
    }
    
    private static func checkMaskUserInputText(view: UIView) -> Bool? {
        
        if let maskUserInputText = view.maskUserInputText {
            return maskUserInputText
        }
        
        if let parentView = view.superview,
           let parentMasked = parentView.maskUserInputText {
            return parentMasked
        }
        
        return nil
    }
    
    private static func checkMaskAllImages(view: UIView) -> Bool? {
        
        if let maskAllImages = view.maskAllImages {
            return maskAllImages
        }
        
        if let parentView = view.superview,
           let parentMasked = parentView.maskAllImages {
            return parentMasked
        }
        
        return nil
    }
    
    private static func checkMaskAllUserTouches(view: UIView) -> Bool? {

        if let maskAllUserTouches = view.maskAllUserTouches{
            return maskAllUserTouches
        }

        if let parentView = view.superview,
           let parentMasked = parentView.maskAllUserTouches {
            return parentMasked
        }

        return nil
    }

    private static func checkBlockView(view: UIView) -> Bool? {
        // Check for explicit blockView flag first
        if let blockView = view.blockView {
            return blockView
        }

        // Check for "nr-block" accessibility identifier
        if let accessibilityId = view.accessibilityIdentifier,
           accessibilityId.count > 0,
           accessibilityId == "nr-block" || accessibilityId.hasSuffix(".nr-block") {
            return true
        }

        // Recursively check parent view hierarchy for blockView inheritance
        if let parentView = view.superview {
            // Check if parent has explicit blockView flag
            if let parentBlockView = parentView.blockView, parentBlockView {
                return true
            }

            // Check if parent has "nr-block" accessibility identifier
            if let parentAccessibilityId = parentView.accessibilityIdentifier,
               parentAccessibilityId.count > 0,
               parentAccessibilityId == "nr-block" || parentAccessibilityId.hasSuffix(".nr-block") {
                return true
            }

            // Recursively check parent's ancestors
            if let ancestorBlocked = checkBlockView(view: parentView), ancestorBlocked {
                return true
            }
        }

        return nil
    }
    
    /// Synthesizes per-corner corner radius for UICollectionViewListCell background views.
    /// SwiftUI List cells draw their section-card rounded corners via Core Graphics
    /// (in UICollectionViewListLayoutSectionBackgroundColorDecorationView.draw(rect:)),
    /// NOT via CALayer.cornerRadius. This helper detects first/last cells in a section
    /// and returns a synthesized radius + mask so the replay HTML looks correct.
    private static func listCellCornerRadius(for view: UIView) -> (CGFloat, CACornerMask)? {
        let className = String(describing: type(of: view))

        // The section-level decoration view (_UICollectionViewListLayoutSectionBackgroundColorDecorationView)
        // IS the card that the user sees — it has backgroundColor but draws rounded corners via Core
        // Graphics, not CALayer.cornerRadius. Always give it all-four-corners radius.
        if className.contains("SectionBackground") {
            return (10.0, [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                           .layerMinXMaxYCorner, .layerMaxXMaxYCorner])
        }

        // Propagate synthesized corner radius to UIView children of UISystemBackgroundView.
        // The hierarchy is: ListCollectionViewCell → UISystemBackgroundView → UIView.
        // The UIView has no CALayer cornerRadius itself, but it shares the same visible
        // shape as its parent background view, so it should carry the same radius.
        if className == "UIView",
           let parent = view.superview,
           String(describing: type(of: parent)).contains("SystemBackground") {
            return listCellCornerRadius(for: parent)
        }

        guard className.contains("SystemBackground") else { return nil }

        var current: UIView? = view.superview
        var cell: UICollectionViewCell? = nil
        var collectionView: UICollectionView? = nil
        while let c = current {
            if cell == nil, let cv = c as? UICollectionViewCell {
                cell = cv
            } else if let cv = c as? UICollectionView {
                collectionView = cv
                break
            }
            current = c.superview
        }

        guard let cell = cell,
              let collectionView = collectionView,
              let indexPath = collectionView.indexPath(for: cell) else { return nil }

        let item = indexPath.item
        let itemCount = collectionView.numberOfItems(inSection: indexPath.section)
        let isFirst = item == 0
        let isLast = item == itemCount - 1
        guard isFirst || isLast else { return nil }

        let radius: CGFloat = 10.0
        if isFirst && isLast {
            return (radius, [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                             .layerMinXMaxYCorner, .layerMaxXMaxYCorner])
        } else if isFirst {
            return (radius, [.layerMinXMinYCorner, .layerMaxXMinYCorner])
        } else {
            return (radius, [.layerMinXMaxYCorner, .layerMaxXMaxYCorner])
        }
    }

    private static func getClippingRect(for view: UIView, in window: UIWindow) -> CGRect {
        // Check if this view has skipAggressiveClipping flag
        if view.skipAggressiveClipping == true {
            return window.frame
        }

        // Original clipping logic
        var clippingView: UIView? = view.superview
        while clippingView != nil {
            if clippingView is UIScrollView || clippingView?.clipsToBounds == true {
                break
            }
            clippingView = clippingView?.superview
        }
        
        if let clippingView = clippingView {
            return clippingView.convert(clippingView.bounds, to: window)
        }
        
        return window.frame // Default to window bounds if no clipping view is found
    }
    
    // Helper method to find scrollview ancestor
    static func findScrollViewAncestor(for view: UIView) -> UIScrollView? {
        var current: UIView? = view.superview
        while current != nil {
            if let scrollView = current as? UIScrollView {
                return scrollView
            }
            current = current?.superview
        }
        return nil
    }
}

extension ViewDetails: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewId)
        hasher.combine(frame.origin.x)
        hasher.combine(frame.origin.y)
        hasher.combine(frame.size.width)
        hasher.combine(frame.size.height)
        hasher.combine(alpha)
        hasher.combine(isHidden)
        hasher.combine(cornerRadius)
        hasher.combine(maskedCorners.rawValue)
        hasher.combine(borderWidth)
        hasher.combine(viewName)
        hasher.combine(parentId)
        hasher.combine(nextId)
        hasher.combine(clip.origin.x)
        hasher.combine(clip.origin.y)
        hasher.combine(clip.size.width)
        hasher.combine(clip.size.height)
        hasher.combine(isMasked)
        hasher.combine(maskApplicationText)
        hasher.combine(maskUserInputText)
        hasher.combine(maskAllImages)
        hasher.combine(maskAllUserTouches)
        hasher.combine(blockView)
        hasher.combine(viewIdentifier)

        // Convert UIColors to hex strings before hashing to ensure thread safety
        if let bgColor = backgroundColor {
            hasher.combine(bgColor.toHexString(includingAlpha: true))
        }
        if let bColor = borderColor {
            hasher.combine(bColor.toHexString(includingAlpha: true))
        }
    }
}

fileprivate var associatedSessionReplayViewIDKey: String = "SessionReplayID"
fileprivate var associatedSessionReplayMaskStateKey: String = "SessionReplayMasked"
fileprivate var associatedSwiftUISessionReplayIdentifierKey: String = "SessionReplayIdentifier"

internal extension UIView {
    var sessionReplayIdentifier: Int? {
        set {
            withUnsafePointer(to: &associatedSessionReplayViewIDKey) {
                objc_setAssociatedObject(self, $0, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }

        get {
            withUnsafePointer(to: &associatedSessionReplayViewIDKey) {
                objc_getAssociatedObject(self, $0) as? Int
            }
        }
    }

    var sessionReplayMaskState: Bool? {
        set {
            withUnsafePointer(to: &associatedSessionReplayMaskStateKey) {
                objc_setAssociatedObject(self, $0, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }

        get {
            withUnsafePointer(to: &associatedSessionReplayMaskStateKey) {
                objc_getAssociatedObject(self, $0) as? Bool
            }
        }
    }
    
    var swiftUISessionReplayIdentifier: String? {
        set {
            withUnsafePointer(to: &associatedSwiftUISessionReplayIdentifierKey) {
                objc_setAssociatedObject(self, $0, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }

        get {
            withUnsafePointer(to: &associatedSwiftUISessionReplayIdentifierKey) {
                objc_getAssociatedObject(self, $0) as? String
            }
        }
    }
}
