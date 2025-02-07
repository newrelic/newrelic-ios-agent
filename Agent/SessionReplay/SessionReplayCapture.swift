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
    let idGenerator = IDGenerator()
    
    public func recordFrom(rootView:UIView) -> SessionReplayFrame {
        var nodes: [any SessionReplayViewThingy] = []
        
        recursivelyRecord(from: rootView, withNodes: &nodes)
        
        return SessionReplayFrame(date: Date(), views: nodes)
    }
    
    func recursivelyRecord(from view:UIView, withNodes nodes: inout [any SessionReplayViewThingy]) {
        
        // Get type of view and it's view thingy
        // It might be worthwhile splitting this out to a new function.
        
        let viewDetails = ViewDetails(view: view, idGenerator: self.idGenerator)
        let viewThingy: SessionReplayViewThingy = UIViewThingy(view: view, viewDetails: viewDetails)
        
        nodes.append(viewThingy)
        
        for subview in view.subviews {
            recursivelyRecord(from: subview, withNodes: &nodes)
        }
    }
}
