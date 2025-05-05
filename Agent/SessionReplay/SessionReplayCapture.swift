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
        var effectiveViewController = findRootViewController(rootView: rootView)
        var rootViewControllerID:String?
        if let rootViewController = effectiveViewController {
            rootViewControllerID = String(describing: type(of: rootViewController))
        }
        
        struct ViewPair {
            let view:UIView
            let parentRecorder:any SessionReplayViewThingy
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
        
        return SessionReplayFrame(date: Date(), views: rootThingy, rootViewControllerId: rootViewControllerID)
    }
    
    private func findRootViewController(rootView: UIView) -> UIViewController? {
        var initialViewController: UIViewController? = nil
        if let foundViewController = rootView.parentViewController {
            initialViewController = foundViewController
        } else if let window = rootView.window, let rootViewController = window.rootViewController {
            initialViewController = rootViewController
        }
        
        var effectiveViewController = initialViewController
                
        while true {
            guard let currentViewController = effectiveViewController else {
                break
            }
            
            if let navigationController = currentViewController as? UINavigationController {
                if let visibleViewController = navigationController.visibleViewController {
                    effectiveViewController = visibleViewController
                } else {
                    break
                }
            } else if let tabBarController = currentViewController as? UITabBarController {
                if let selectedViewController = tabBarController.selectedViewController {
                    effectiveViewController = selectedViewController
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        return effectiveViewController
    }
    
    private func findRecorderForView(view originalView: UIView) -> any SessionReplayViewThingy {
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
        let isClear = (view.alpha == 0)
        
        return !(areFramesTheSame && isClear)
    }
}

extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while let responder = parentResponder {
            if let viewController = responder as? UIViewController {
                return viewController
            }
            parentResponder = responder.next
        }
        return nil
    }
}
