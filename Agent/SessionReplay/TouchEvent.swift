//
//  TouchEventDetail.swift
//  Agent
//
//  Created by Steve Malsam on 4/2/25.
//  Copyright © 2025 New Relic. All rights reserved.
//


import Foundation
import UIKit
import OSLog
import NewRelicPrivate

class TouchEvent {
        var startTouch: Detail
        var moveTouches: [Detail] = []
        var endTouch: Detail?
        let id: Int
        
        struct Detail {
            let location: CGPoint
            let phase: UITouch.Phase
            let date: TimeInterval
            
            init(location: CGPoint, phase: UITouch.Phase, date: TimeInterval) {
                self.location = location
                self.phase = phase
                self.date = date
            }
        }
        
        init(startTouch: Detail, with id: Int) {
            self.startTouch = startTouch
            self.id = id
        }
    }
