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
    let borderWidth: CGFloat
    let borderColor: UIColor?
    let viewName: String
    let parentId: Int?
    var nextId: Int?
    let clip: CGRect

    // Indicates if this view should have its content masked in session replay
    var isMasked: Bool?

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
        cornerRadius = view.layer.cornerRadius
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

        if let shouldMask = ViewDetails.checkIsMasked(view: view, viewName: viewName) {
            self.isMasked = shouldMask
            view.sessionReplayMaskState = shouldMask
        }
    }
    
    init(view: UIView, parentId: Int) {
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
        cornerRadius = view.layer.cornerRadius
        borderWidth = view.layer.borderWidth

        // Checking if we have a border, because asking for the layer's
        // border color will always give us something
        if view.layer.borderWidth > 0, let borderColor = view.layer.borderColor {
            self.borderColor = UIColor(cgColor: borderColor)
        }
        else {
            self.borderColor = nil
        }

        viewName = String(describing: type(of: view))

        if let identifier = view.sessionReplayIdentifier {
            viewId = identifier
        }
        else {
            viewId = IDGenerator.shared.getId()
            view.sessionReplayIdentifier = viewId
        }
        
        self.parentId = parentId

        if let shouldMask = ViewDetails.checkIsMasked(view: view, viewName: viewName) {
            self.isMasked = shouldMask
            view.sessionReplayMaskState = shouldMask
        }
    }
    
    init(frame: CGRect, clip: CGRect, backgroundColor: UIColor, alpha: CGFloat, isHidden: Bool, viewName: String, parentId: Int, cornerRadius: CGFloat, borderWidth: CGFloat, borderColor: UIColor? = nil, viewId: Int?, view: UIView? = nil,
    
          maskApplicationText: Bool?,
          maskUserInputText: Bool?,
          maskAllImages: Bool?,
          maskAllUserTouches: Bool?,
          sessionReplayIdentifier: String?) {
        
        self.frame = frame
        self.clip = clip
        self.backgroundColor = backgroundColor
        self.alpha = alpha
        self.isHidden = isHidden
        self.cornerRadius = cornerRadius
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

        if let view = view, let shouldMask = ViewDetails.checkIsMasked(view: view, viewName: viewName, maskApplicationText:maskApplicationText,maskUserInputText:maskUserInputText,maskAllImages:maskAllImages,maskAllUserTouches:maskAllUserTouches,sessionReplayIdentifier:sessionReplayIdentifier) {
            self.isMasked = shouldMask
            view.sessionReplayMaskState = shouldMask
        }
    }

    
    // This function checks if there are any specfic masking rules assigned to a view. If it returns nils, the masking value will be assigned based on the value of the global based on it's type later.
    private static func checkIsMasked(view: UIView, viewName: String, maskApplicationText: Bool? = nil, maskUserInputText: Bool? = nil, maskAllImages: Bool? = nil, maskAllUserTouches: Bool? = nil, sessionReplayIdentifier: String? = nil) -> Bool? {
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
        
        if let maskApplicationText = maskApplicationText, !maskApplicationText {
            return false
        }
        else if let maskApplicationText = maskApplicationText, maskApplicationText {
            return true
        }
        
        if let maskUserInputText = maskUserInputText, !maskUserInputText {
            return false
        }
        else if let maskUserInputText = maskUserInputText, maskUserInputText {
            return true
        }
        
//        // Check if parent is marked as masked or unmasked (propagate masking status to children)
//        if let parentView = view.superview,
//           let parentMasked = parentView.sessionReplayMaskState {
//            return parentMasked
//        }
  
        if let sessionReplayIdentifier {
            // Check for accessibility identifier in the masking list
            if agent.isAccessibilityIdentifierMasked(sessionReplayIdentifier) {
                return true
            }

            // Check for accessibility identifier in the masking list
            if agent.isAccessibilityIdentifierUnmasked(sessionReplayIdentifier) {
                return false
            }
        }
        
        // Return nil if no custom masked setting is found
        return nil
    }
    
    private static func getClippingRect(for view: UIView, in window: UIWindow) -> CGRect {
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
