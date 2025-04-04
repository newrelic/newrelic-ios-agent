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
    
    public func captureSendEventTouches(event: UIEvent) {
        guard event.type == .touches,
              let touches = event.touches(for: window) else {
                  return
              }
        
        if #available(iOS 14.0, *) {
            os_log("Touch Swizzle. Event: \(event)")
        } else {
            // Fallback on earlier versions
        }

        for touch in touches {
            
            switch(touch.phase) {
            case .began:
                let location = touch.location(in: touch.window)
                let touchedView = touch.window?.hitTest(location, with: nil)
                let viewID = touchedView?.sessionReplayIdentifier ?? 0
                let touchDetail = TouchEvent.Detail(location: location, phase: .began, date: touch.timestamp)
                let touchTracker = TouchEvent(startTouch: touchDetail, with: viewID)
                
                NRMAAssociate.attach(touchTracker, to: touch, with: "TouchTracker")
            case .moved:
                guard let touchTracker = NRMAAssociate.retrieve(from: touch, with: "TouchTracker") as? TouchEvent else {
                    os_log( "ERROR: Touch Tracker not associated with Touch!")
                    continue
                }
                
                let location = touch.location(in: touch.window)
                let touchDetail = TouchEvent.Detail(location: location, phase: .moved, date: touch.timestamp)
                touchTracker.moveTouches.append(touchDetail)
                
            case .ended:
                guard let touchTracker = NRMAAssociate.retrieve(from: touch, with: "TouchTracker") as? TouchEvent else {
                    os_log( "ERROR: Touch Tracker not associated with Touch!")
                    continue
                }
                
                let location = touch.location(in: touch.window)
                let touchDetail = TouchEvent.Detail(location: location, phase: .ended, date: touch.timestamp)
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
