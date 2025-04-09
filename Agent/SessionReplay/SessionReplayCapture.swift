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
    
    @MainActor
    public func recordFrom(rootView:UIView) -> SessionReplayFrame {
        struct ViewPair {
            let view:UIView
            let parentRecorder:SessionReplayViewThingy
        }
        
        var viewStack = ContiguousArray<ViewPair>()
        let rootThingy = findRecorderForView(view: rootView)
        
        viewStack.append(ViewPair(view: rootView, parentRecorder: rootThingy))
        
        while let pair = viewStack.popLast() {
            let currentView = pair.view
            var currentParentThingy = pair.parentRecorder
            
            for subview in currentView.subviews {
                if (shouldRecord(view: subview)) {
                    let childThingy = findRecorderForView(view: subview)
                    currentParentThingy.subviews.append(childThingy)
                    viewStack.append(ViewPair(view: subview, parentRecorder: childThingy))
                } else {
                    viewStack.append(ViewPair(view: subview, parentRecorder: currentParentThingy))
                }
            }
        }
        
        return SessionReplayFrame(date: Date(), views: rootThingy)
    }
    
    func recursivelyRecord(from view:UIView) -> SessionReplayViewThingy {
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
        case let imageView as UIImageView:
            return UIImageViewThingy(view: imageView, viewDetails: ViewDetails(view: imageView))
        default:
            return UIViewThingy(view: originalView, viewDetails: ViewDetails(view: originalView))
        }
    }
    
    private func shouldRecord(view: UIView) -> Bool {
        guard let superview = view.superview else {
            return true
        }
        
        let areFramesTheSame = CGRectEqualToRect(view.frame, superview.frame)
        let isClear = (view.alpha == 0 || view.alpha == 1)
        
        return !(areFramesTheSame && isClear)
    }
}
