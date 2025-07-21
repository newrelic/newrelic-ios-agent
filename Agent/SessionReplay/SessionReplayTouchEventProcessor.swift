//
//  SessionReplayTouchEventProcessor.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 4/2/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

class TouchEventProcessor {
    
    func processTouches(_ touchEvents: [TouchEvent]) -> [IncrementalEvent] {
        var processedTouches: [IncrementalEvent] = []
        for touchEvent in touchEvents {
            processedTouches.append(contentsOf: processTouch(touchEvent))
        }
        return processedTouches
    }
    
    func processTouch(_ touchEvent: TouchEvent) -> [IncrementalEvent] {
        var RRWebTouchEvents = [IncrementalEvent]()
        
        // Start touch
        let startTouchData = RRWebMouseInteractionData(type: .touchStart,
                                                   id: touchEvent.id,
                                                   x: touchEvent.startTouch.location.x,
                                                   y: touchEvent.startTouch.location.y)
        
        let startTouch = IncrementalEvent(timestamp: touchEvent.startTouch.date * 1000, data: .mouseInteraction(startTouchData))
        RRWebTouchEvents.append(startTouch)
        
        if !touchEvent.moveTouches.isEmpty,
           let lastTimestamp = touchEvent.moveTouches.last?.date {
            let touchMoveData = RRWebTouchMoveData(positions: touchEvent.moveTouches.map {
                RRWebTouchPosition(x: $0.location.x,
                                   y: $0.location.y,
                                   id: touchEvent.id,
                                   timeOffset: ($0.date - lastTimestamp))
            })
            
            RRWebTouchEvents.append(IncrementalEvent(timestamp: lastTimestamp * 1000, data: .touchMove(touchMoveData)))
        }
        
        if let endTouch = touchEvent.endTouch {
            let endTouchData = RRWebMouseInteractionData(type: .touchEnd,
                                                         id: touchEvent.id,
                                                         x: endTouch.location.x,
                                                         y: endTouch.location.y)
            RRWebTouchEvents.append(IncrementalEvent(timestamp: endTouch.date * 1000, data: .mouseInteraction(endTouchData)))
        }
        
        return RRWebTouchEvents
    }
}
