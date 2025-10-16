//
//  NRMASessionReplayCapture.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 1/15/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

@available(iOS 13.0, *)
@objcMembers
class SessionReplayCapture {
    
    @MainActor
    public func recordFrom(rootView:UIView) -> SessionReplayFrame {
        let effectiveViewController = findRootViewController(rootView: rootView)
        var rootViewControllerID:String?
        if let rootViewController = effectiveViewController {
            rootViewControllerID = String(describing: type(of: rootViewController))
        }
        
        struct ViewPair {
            let view:UIView
            let parentRecorder:any SessionReplayViewThingy
        }
        
        var rootSwiftUIViewID: Int? = nil
        
        var viewStack = ContiguousArray<ViewPair>()
        let rootThingy = findRecorderForView(view: rootView)
        
        viewStack.append(ViewPair(view: rootView, parentRecorder: rootThingy))
        
        while let pair = viewStack.popLast() {
            let currentView = pair.view
            var currentParentThingy = pair.parentRecorder
            
            for subview in currentView.subviews {
                if (shouldRecord(view: subview)) {
                    let childThingy = findRecorderForView(view: subview)
                    if childThingy.viewDetails.isVisible {
                        currentParentThingy.subviews.append(childThingy)
                    }
                    viewStack.append(ViewPair(view: subview, parentRecorder: childThingy))
                }
                else {
                    viewStack.append(ViewPair(view: subview, parentRecorder: currentParentThingy))
                }
            }
            
            // Check if this is specifically SwiftUI._UIHostingView<SwiftUI.BridgedPresentation.RootView> and handle z-ordering correctly
            if let viewController = extractVC(from: currentView),
               ControllerTypeDetector(from: NSStringFromClass(type(of: viewController))) == .hostingController {
                let className = NSStringFromClass(type(of: currentView))
                if className.contains("_UIHostingView") && className.contains("RootView") {
                    rootSwiftUIViewID = currentParentThingy.viewDetails.viewId
                }
                
                let viewAttributes = SwiftUIViewAttributes(frame: currentParentThingy.viewDetails.frame,
                                                           clip: currentParentThingy.viewDetails.clip,
                                                           backgroundColor: currentView.backgroundColor?.cgColor,
                                                           layerBorderColor: currentView.layer.borderColor,
                                                           layerBorderWidth: currentView.layer.borderWidth,
                                                           layerCornerRadius: currentView.layer.cornerRadius,
                                                           alpha: currentView.alpha,
                                                           isHidden: currentView.isHidden,
                                                           intrinsicContentSize: currentView.intrinsicContentSize,
                                                           maskApplicationText: currentView.maskApplicationText,
                                                           maskUserInputText: currentView.maskUserInputText,
                                                           maskAllImages: currentView.maskAllImages,
                                                           maskAllUserTouches: currentView.maskAllUserTouches
                )
                
                let context = SwiftUIContext(frame: currentParentThingy.viewDetails.frame, clip: currentParentThingy.viewDetails.clip)
                
                let thingys = UIHostingViewRecordOrchestrator.swiftUIViewThingys(currentView, context: context, viewAttributes: viewAttributes, parentId: currentParentThingy.viewDetails.viewId)
                
                
                if !thingys.isEmpty {
                    currentParentThingy.subviews.append(contentsOf: thingys)
                }
            }
            
            if let textView = currentView as? UITextField {
                let textViewThingy = CustomTextThingy(view: textView, viewDetails: ViewDetails(view: currentView))
                currentParentThingy.subviews.append(textViewThingy) // Adding text to the bottom of a UITextFieldThingy because the _UITextFieldRoundedRectBackgroundViewNeue covers it.
            }
            var nextId:Int? = nil
            for var childView in currentParentThingy.subviews.reversed() {
                childView.viewDetails.nextId = nextId
                nextId = childView.viewDetails.viewId
            }
        }
        
        return SessionReplayFrame(date: Date(), views: rootThingy, rootViewControllerId: rootViewControllerID, rootSwiftUIViewId: rootSwiftUIViewID, size:  rootView.frame.size)
    }
    
    private func findRootViewController(rootView: UIView) -> UIViewController? {
        var initialViewController: UIViewController? = nil
        if let foundViewController = rootView.parentViewController {
            initialViewController = foundViewController
        }
        else if let window = rootView.window, let rootViewController = window.rootViewController {
            initialViewController = rootViewController
        }
        else if let window = rootView as? UIWindow, let rootViewController = window.rootViewController {
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
                }
                else {
                    break
                }
            }
            else if let tabBarController = currentViewController as? UITabBarController {
                if let selectedViewController = tabBarController.selectedViewController {
                    effectiveViewController = selectedViewController
                }
                else {
                    break
                }
            }
            else {
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
            
        case let textField as UITextField:
            return UITextFieldThingy(view: textField, viewDetails: ViewDetails(view: textField))
            
        case let textView as UITextView:
            return UITextViewThingy(view: textView, viewDetails: ViewDetails(view: textView))
            
        case let visualEffectView as UIVisualEffectView:
            return UIVisualEffectViewThingy(view: visualEffectView, viewDetails: ViewDetails(view: visualEffectView))
            
        default:
            if let rctParagraphClass = NSClassFromString(RCTParagraphComponentView),
               originalView.isKind(of: rctParagraphClass) {
                return UILabelThingy(view: originalView, viewDetails: ViewDetails(view: originalView))
            } else {
                return UIViewThingy(view: originalView, viewDetails: ViewDetails(view: originalView))
            }
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
    
//        func logThingys(_ things: [any SessionReplayViewThingy]) {
//            var lines: [String] = []
//            lines.reserveCapacity(things.count)
//    
//            for thing in things {
//                let frame = thing.viewDetails.frame
//                let viewId = thing.viewDetails.viewId
//                let parentId = thing.viewDetails.parentId ?? -1
//                let viewName = thing.viewDetails.viewName ?? "NoName"
//                let typeName = String(describing: type(of: thing))
//                let line = "\(typeName) - id:\(viewId) parent:\(parentId) name:\(viewName) frame:(\(String(format: "%.2f", frame.origin.x)), \(String(format: "%.2f", frame.origin.y)), \(String(format: "%.2f", frame.size.width)), \(String(format: "%.2f", frame.size.height)))"
//                lines.append(line)
//            }
//            let newLog = lines.joined(separator: "\n")
//            //NRLOG_DEBUG("THINGIES for SwiftUI view:")
//            //NRLOG_DEBUG(newLog)
//            //NRLOG_DEBUG("END Thingys for SwiftUI view:")
//        }
}

