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

@objcMembers
public class NRMASessionReplayTouchCapture: NSObject {
    public var touchDetails: [TouchDetail] = []
    let window: UIWindow
    private var idCounter: Int = 0

    // potentially move this to a struct once all Swift
    @objc
    public class TouchDetail: NSObject {
        @objc public let location: CGPoint
        @objc public let phase: UITouch.Phase
        @objc public let date: Date
        @objc public let id: Int
        
        init(location: CGPoint, phase: UITouch.Phase, date: Date, id: Int) {
            self.location = location
            self.phase = phase
            self.date = date
            self.id = id
        }
    }
    
    @objc public init(window: UIWindow) {
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
            touchDetails.append(TouchDetail(location: touch.location(in: window),
                                            phase: touch.phase,
                                            date: Date(),
                                            id: idCounter))
            idCounter += 1
        }
    }
}
