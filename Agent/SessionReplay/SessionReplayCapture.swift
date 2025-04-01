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
    
    public func recordFrom(rootView:UIView) -> SessionReplayFrame {
        let rootNode = recursivelyRecord(from: rootView)
        
        return SessionReplayFrame(date: Date(), views: rootNode)
    }
    
    func recursivelyRecord(from view:UIView) -> SessionReplayViewThingy {
        
        // Get type of view and it's view thingy
        // It might be worthwhile splitting this out to a new function.
        
        var viewThingy = findRecorderForView(view: view)
        var subviewThingies = [SessionReplayViewThingy]()
        
        for subview in view.subviews {
            let subviewDetails = recursivelyRecord(from: subview)
            subviewThingies.append(subviewDetails)
        }
        viewThingy.subviews = subviewThingies
        
        return viewThingy
    }
    
    private func findRecorderForView(view originalView: UIView) -> SessionReplayViewThingy {
        switch originalView {
        case let view as UILabel:
            return UILabelThingy(view: view, viewDetails: ViewDetails(view: view))
        default:
            return UIViewThingy(view: originalView, viewDetails: ViewDetails(view: originalView))
        }
    }
}
