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
    let backgroundColor: UIColor?
    let alpha: CGFloat
    let isHidden: Bool
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let borderColor: UIColor?
    let viewName: String
    let clip: CGRect

    // Indicates if this view should have its content masked in session replay
    let isMasked: Bool

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

        // Determine if this view should be masked
        var shouldMask = false
        let agent = NewRelicAgentInternal.sharedInstance()

        // Handle decision for masking based on accessibility identifier in this section.
        // Check for accessibility identifier in the masking list
        if let accessibilityId = view.accessibilityIdentifier,
        agent.isAccessibilityIdentifierMasked(accessibilityId) {
            shouldMask = true
        }

        // Check if parent is masked (propagate masking to children)
        if !shouldMask,
           let parentView = view.superview,
           let parentMasked = parentView.sessionReplayMaskState,
           parentMasked {
            shouldMask = true
        }

        if let accessibilityId = view.accessibilityIdentifier,
           accessibilityId == "nr-unmask" {
               //This view is explicitly marked to not be masked. If its parent is not masked, unmask it.
               if let parentView = view.superview,
                  let parentMasked = parentView.sessionReplayMaskState,
               !parentMasked {
                   shouldMask = false
                  }
        }

        if let accessibilityId = view.accessibilityIdentifier,
           accessibilityId == "nr-mask" {
            //This view is explicitly marked to not be masked.
            shouldMask = true
        }
        // END Handle decision for masking based on accessibility identifier in this section.

        // Handle decision for masking based on class names in this section.

        // Check for class name in the masking list if not already masked
        if !shouldMask,
           agent.isClassNameMasked(viewName) {
            shouldMask = true
        }
           
        // END Handle decision for masking based on class names in this section.

        // Store masking state for children to inherit
        view.sessionReplayMaskState = shouldMask

        isMasked = shouldMask

       // NRLOG_DEBUG("Session Replay: isMask = \(shouldMask) for view \(viewName) with id \(viewId)")
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
