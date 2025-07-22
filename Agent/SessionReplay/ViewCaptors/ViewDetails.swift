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
    let viewId: Int
    let frame: CGRect
    var backgroundColor: UIColor?
    let alpha: CGFloat
    let isHidden: Bool
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let borderColor: UIColor?
    let viewName: String
    let clip: CGRect

    // Indicates if this view should have its content masked in session replay
    var isMasked: Bool?

    var cssSelector: String {
        "\(self.viewName)-\(self.viewId)"
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
        } else {
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
        } else {
            self.borderColor = nil
        }

        viewName = String(describing: type(of: view))

        if let identifier = view.sessionReplayIdentifier {
            viewId = identifier
        } else {
            viewId = IDGenerator.shared.getId()
            view.sessionReplayIdentifier = viewId
        }

        if let shouldMask = ViewDetails.checkIsMasked(view: view, viewName: viewName) {
            self.isMasked = shouldMask
            view.sessionReplayMaskState = shouldMask
        }
    }
    
    // This function checks if there are any specfic masking rules assigned to a view. If it returns nils, the masking value will be assigned based on the value of the global based on it's type later.
    private static func checkIsMasked(view: UIView, viewName: String) -> Bool? {
        // Determine if this view should be masked
        let agent = NewRelicAgentInternal.sharedInstance()
        guard let agent = agent else { return true }

        // If masking is in default mode we want to use the default value which is determined by the global for it's type.
        if NRMAHarvestController.configuration().session_replay_mode as SessionReplayMaskingMode == SessionReplayMaskingMode.default {
            return nil
        }
        
        if let accessibilityId = view.accessibilityIdentifier,
           accessibilityId.count > 0,
           accessibilityId == "nr-mask" || accessibilityId.hasSuffix(".nr-mask") {
            //This view is explicitly marked to not be masked.
            return true
        }

        // Handle decision for masking based on accessibility identifier in this section.
        // Check for accessibility identifier in the masking list
        if let accessibilityId = view.accessibilityIdentifier,
           agent.isAccessibilityIdentifierMasked(accessibilityId) {
            return true
        }
        
        // Check for class name in the masking list if not already masked
        if agent.isClassNameMasked(viewName) {
            return true
        }
        
        // Check if parent is masked (propagate masking to children)
        if let parentView = view.superview,
           let parentMasked = parentView.sessionReplayMaskState,
           parentMasked {
            return true
        }

        if let accessibilityId = view.accessibilityIdentifier,
           accessibilityId.count > 0,
           accessibilityId == "nr-unmask" || accessibilityId.hasSuffix(".nr-unmask") {
            return false
        }
        
        if let accessibilityId = view.accessibilityIdentifier,
           agent.isAccessibilityIdentifierUnmasked(accessibilityId) {
            return false
        }
        
        // Check for class name in the unmasking list
        if agent.isClassNameUnmasked(viewName) {
            return false
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
}
