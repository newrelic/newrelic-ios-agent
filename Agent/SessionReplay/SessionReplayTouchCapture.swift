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

import NewRelicPrivate

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
            
            switch(touch.phase) {
            case .began:
                let location = touch.location(in: touch.window)
                let touchedView = touch.window?.hitTest(location, with: nil)
                let viewID = touchedView?.sessionReplayIdentifier ?? 0
                let touchDetail = TouchEvent.Detail(location: location, phase: .began, date: Date().timeIntervalSince1970)
                let touchTracker = TouchEvent(startTouch: touchDetail, with: viewID)
                
                touch.touchTracker = touchTracker
            case .moved:
                guard let touchTracker = touch.touchTracker else {
                    NRLogger.agentLogError( "ERROR: Touch Tracker not associated with Touch!")
                    continue
                }
                
                let location = touch.location(in: touch.window)
                let touchDetail = TouchEvent.Detail(location: location, phase: .moved, date: Date().timeIntervalSince1970)
                touchTracker.moveTouches.append(touchDetail)
                
            case .ended:
                guard let touchTracker = touch.touchTracker else {
                    NRLogger.agentLogError( "ERROR: Touch Tracker not associated with Touch!")
                    continue
                }
                
                let location = touch.location(in: touch.window)
                let touchDetail = TouchEvent.Detail(location: location, phase: .ended, date: Date().timeIntervalSince1970)
                touchTracker.endTouch = touchDetail
                
                self.touchEvents.append(touchTracker)
                NRMAAssociate.remove(from: touch, with: "TouchTracker")
                
            default:
                continue
            }
        }
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
