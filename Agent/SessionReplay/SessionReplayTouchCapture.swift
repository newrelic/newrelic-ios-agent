//
//  NRMASessionReplayTouchCapture.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 1/13/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit

import OSLog

@_implementationOnly import NewRelicPrivate

class SessionReplayTouchCapture: NSObject {
    var touchEvents: [TouchEvent] = []
    var earliestDate: TimeInterval?
    let window: UIWindow
    
    // potentially move this to a struct once all Swift

    init(window: UIWindow) {
        self.window = window
    }
    
    @objc dynamic
    public func captureSendEventTouches(event: UIEvent) {
        // Only handle real touch events
        guard event.type == .touches,
              let allTouches = event.allTouches, !allTouches.isEmpty else {
            return
        }

        // Only consider touches that belong to this capture's window
        let touches = allTouches.filter { $0.window === self.window }
        guard !touches.isEmpty else { return }

        for touch in touches {
            guard let win = touch.window else { continue }

            let location = touch.location(in: win)
            let touchedView = win.hitTest(location, with: nil)

            switch touch.phase {
            case .began:
                if !shouldMaskTouchesForView(touchedView) {
                    let viewID = touchedView?.sessionReplayIdentifier ?? 0
                    let touchDetail = TouchEvent.Detail(location: location, phase: .began, date: Date().timeIntervalSince1970)
                    let touchTracker = TouchEvent(startTouch: touchDetail, with: viewID)
                    touch.touchTracker = touchTracker
                }

            case .moved:
                if let touchTracker = touch.touchTracker {
                    let touchDetail = TouchEvent.Detail(location: location, phase: .moved, date: Date().timeIntervalSince1970)
                    touchTracker.moveTouches.append(touchDetail)
                }

            case .ended, .cancelled:
                if let touchTracker = touch.touchTracker {
                    let touchDetail = TouchEvent.Detail(location: location, phase: .ended, date: Date().timeIntervalSince1970)
                    touchTracker.endTouch = touchDetail
                    self.touchEvents.append(touchTracker)
                    NRMAAssociate.remove(from: touch, with: "TouchTracker")
                }

            default:
                break
            }
        }
    }
    
    // Determines if touches for a specific view should be masked based on configuration
    private func shouldMaskTouchesForView(_ view: UIView?) -> Bool {
        guard let view = view else {
            return true
        }

        // Check if the view or any ancestor is blocked - block touches for blocked views
        if shouldBlockTouchesForView(view) {
            return true
        }

        // Check for explicit view-level maskAllUserTouches setting
        if let maskAllUserTouches = view.maskAllUserTouches {
            return maskAllUserTouches
        }

        // Check for explicit session replay mask state
        if let maskState = view.sessionReplayMaskState {
            return maskState
        }

        // Fall back to global configuration
        return NRMAHarvestController.configuration()?.session_replay_maskAllUserTouches ?? true
    }

    // Checks if touches should be blocked due to blockView settings on this view or ancestors
    private func shouldBlockTouchesForView(_ view: UIView) -> Bool {
        // Check current view for explicit blockView flag
        if let blockView = view.blockView, blockView {
            return true
        }

        // Check current view for "nr-block" accessibility identifier
        if let accessibilityId = view.accessibilityIdentifier,
           accessibilityId.count > 0,
           accessibilityId == "nr-block" || accessibilityId.hasSuffix(".nr-block") {
            return true
        }

        // Recursively check parent view hierarchy
        if let parentView = view.superview {
            return shouldBlockTouchesForView(parentView)
        }

        return false
    }
    
    public func resetEvents() {
        self.touchEvents.removeAll()
        self.earliestDate = nil
    }
}

fileprivate var associatedTouchTrackerIDKey: String = "TouchTracker"

internal extension UITouch {
    var touchTracker: TouchEvent? {
        set {
            withUnsafePointer(to: &associatedTouchTrackerIDKey) {
                objc_setAssociatedObject(self, $0, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
        
        get {
            withUnsafePointer(to: &associatedTouchTrackerIDKey) {
                objc_getAssociatedObject(self, $0) as? TouchEvent
            }
        }
        
    }
}
