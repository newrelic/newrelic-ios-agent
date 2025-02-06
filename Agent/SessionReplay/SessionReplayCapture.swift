//
//  NRMASessionReplayCapture.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 1/15/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit


// potentially remove this annotation once the feature goes to Swift
@objcMembers
class SessionReplayCapture {
//    public func recordFrom(rootView:UIView) -> [NRMAUIViewDetailsObjC] {
//        
//    }
    
    public func recordFrom(rootView:UIView) -> SessionReplayFrame {
        var nodes: [any SessionReplayViewThingy] = []
        
        recursivelyRecord(from: rootView, withNodes: &nodes)
        
        return SessionReplayFrame(date: Date(), views: nodes)
    }
    
    func recursivelyRecord(from rootView:UIView, withNodes: inout [any SessionReplayViewThingy]) {
        
    }
}
