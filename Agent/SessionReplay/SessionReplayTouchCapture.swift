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
        guard event.type == .touches,
              let touches = event.touches(for: window) else {
                  return
              }

        for touch in touches {
            let location = touch.location(in: touch.window)
            let touchedView = touch.window?.hitTest(location, with: nil)
            
            switch(touch.phase) {
            case .began:
                // Only start tracking if the initial touch is on an unmasked view
                if !shouldMaskTouchesForView(touchedView) {
                    let viewID = touchedView?.sessionReplayIdentifier ?? 0
                    let touchDetail = TouchEvent.Detail(location: location, phase: .began, date: Date().timeIntervalSince1970)
                    let touchTracker = TouchEvent(startTouch: touchDetail, with: viewID)
                    
                    touch.touchTracker = touchTracker
                }
                
            case .moved:
                guard let touchTracker = touch.touchTracker else {
                    // This touch is either already masked or missing tracker
                    continue
                }
                
                // Check if the touch has moved to a masked view
                if shouldMaskTouchesForView(touchedView) {
                    // End tracking this touch as it's entered a masked area
                    let touchDetail = TouchEvent.Detail(location: touchTracker.moveTouches.last?.location ?? location,
                                                       phase: .ended,
                                                       date: Date().timeIntervalSince1970)
                    touchTracker.endTouch = touchDetail
                    self.touchEvents.append(touchTracker)
                    NRMAAssociate.remove(from: touch, with: "TouchTracker")
                    continue
                }
                
                // Continue tracking in unmasked area
                let touchDetail = TouchEvent.Detail(location: location, phase: .moved, date: Date().timeIntervalSince1970)
                touchTracker.moveTouches.append(touchDetail)
                
            case .ended:
                guard let touchTracker = touch.touchTracker else {
                    // This touch is either masked or missing tracker
                    continue
                }
                
                // Record end location only if it's in an unmasked view
                if !shouldMaskTouchesForView(touchedView) {
                    let touchDetail = TouchEvent.Detail(location: location, phase: .ended, date: Date().timeIntervalSince1970)
                    touchTracker.endTouch = touchDetail
                } else {
                    // Use the last known unmasked location as the end point
                    let lastLocation = touchTracker.moveTouches.last?.location ?? touchTracker.startTouch.location
                    let touchDetail = TouchEvent.Detail(location: lastLocation, phase: .ended, date: Date().timeIntervalSince1970)
                    touchTracker.endTouch = touchDetail
                }
                
                self.touchEvents.append(touchTracker)
                NRMAAssociate.remove(from: touch, with: "TouchTracker")
                
            default:
                continue
            }
        }
    }
    
    // Determines if touches for a specific view should be masked based on configuration
    private func shouldMaskTouchesForView(_ view: UIView?) -> Bool {
        guard let view = view else {
            return true
        }
        
        if let maskState = view.sessionReplayMaskState {
            return maskState
        }
        
        return NRMAHarvestController.configuration().session_replay_maskAllUserTouches
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
