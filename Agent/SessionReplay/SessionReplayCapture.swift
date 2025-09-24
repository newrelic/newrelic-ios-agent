//
//  NRMASessionReplayCapture.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 1/15/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit
@_implementationOnly import NewRelicPrivate
import SwiftUI

// potentially remove this annotation once the feature goes to Swift
@available(iOS 13.0, *)
@objcMembers
class SessionReplayCapture {
    
    @MainActor
     public func recordFrom(rootView: UIView) -> SessionReplayFrame {
         let effectiveViewController = findRootViewController(rootView: rootView)

         var rootViewControllerID: String?
         if let rootViewController = effectiveViewController {
             rootViewControllerID = String(describing: type(of: rootViewController))
         }

         // Detect root SwiftUI host and capture an ID for the frame
         let rootSwiftUIViewID = findRootSwiftUIViewId(rootView: rootView,
                                                       effectiveViewController: effectiveViewController)

         struct ViewPair {
             let view: UIView
             let parentRecorder: any SessionReplayViewThingy
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
                     if childThingy.viewDetails.isVisible {
                         currentParentThingy.subviews.append(childThingy)
                     }
                     viewStack.append(ViewPair(view: subview, parentRecorder: childThingy))
                 } else {
                     viewStack.append(ViewPair(view: subview, parentRecorder: currentParentThingy))
                 }
             }

             if let textView = currentView as? UITextField {
                 let textViewThingy = CustomTextThingy(view: textView, viewDetails: ViewDetails(view: currentView))
                 currentParentThingy.subviews.append(textViewThingy)
             }

             var nextId: Int? = nil
             for var childView in currentParentThingy.subviews.reversed() {
                 childView.viewDetails.nextId = nextId
                 nextId = childView.viewDetails.viewId
             }
         }

         return SessionReplayFrame(
             date: Date(),
             views: rootThingy,
             rootViewControllerId: rootViewControllerID,
             rootSwiftUIViewId: rootSwiftUIViewID,
             size: rootView.frame.size
         )
     }
    
    private func findRootViewController(rootView: UIView) -> UIViewController? {
        var initialViewController: UIViewController? = nil
        if let foundViewController = rootView.parentViewController {
            initialViewController = foundViewController
        } else if let window = rootView.window, let rootViewController = window.rootViewController {
            initialViewController = rootViewController
        } else if let window = rootView as? UIWindow, let rootViewController = window.rootViewController {
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
    
    @MainActor private func findRecorderForView(view originalView: UIView) -> any SessionReplayViewThingy {

        // 1. Skip internal marker views entirely
        if originalView is SRTagMarkerView {
            return UIViewThingy(view: originalView, viewDetails: ViewDetails(view: originalView))
        }

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
            // React Native paragraph special-case first
            if let rctParagraphClass = NSClassFromString(RCTParagraphComponentView),
               originalView.isKind(of: rctParagraphClass) {
                return UILabelThingy(view: originalView, viewDetails: ViewDetails(view: originalView))
            }
            // SwiftUI heuristics: only attempt if class name indicates SwiftUI & size is non-zero
            if SwiftUIThingyHeuristics.isLikelySwiftUIView(originalView), originalView.bounds.size != .zero {
                // Try to extract text first (cheap)
                if let text = SwiftUIThingyHeuristics.extractText(from: originalView), !text.isEmpty {
                    return SwiftUITextThingy(view: originalView, viewDetails: ViewDetails(view: originalView), text: text)
                }
                // Otherwise try an image snapshot (avoid if very large to reduce cost)
                if let image = SwiftUIThingyHeuristics.snapshotIfReasonable(view: originalView) {
                    return SwiftUIImageThingy(view: originalView, viewDetails: ViewDetails(view: originalView), image: image)
                }
            }
            return UIViewThingy(view: originalView, viewDetails: ViewDetails(view: originalView))
        }
    }
    
    private func shouldRecord(view: UIView) -> Bool {
        if view is SRTagMarkerView { return false }
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

@available(iOS 13.0, *)
extension SessionReplayCapture {

    // MARK: - SwiftUI root host detection (Navigation-aware)

    fileprivate func findRootSwiftUIViewId(rootView: UIView,
                                           effectiveViewController: UIViewController?) -> String? {
        // 1) Find the top-most visible VC (follows presented/nav/tab/split and SwiftUI child stacks)
        let baseVC = effectiveViewController ?? rootView.window?.rootViewController
        if let topVC = topMostViewController(from: baseVC) {
            // Try to read the SwiftUI root type from a visible hosting controller
            if let id = reflectSwiftUIRootType(from: topVC) {
                return id
            }
            // If topVC is not a hosting controller, search its children for a visible hosting controller
            if let hostingVC = findHostingController(in: topVC),
               let id = reflectSwiftUIRootType(from: hostingVC) {
                return id
            }
        }

        // 2) Fallback: scan the UIView tree for known SwiftUI host/container views
        var queue: [UIView] = [rootView]
        while !queue.isEmpty {
            let v = queue.removeFirst()
            let name = NSStringFromClass(type(of: v))
            if isSwiftUIHostViewName(name) {
                return name
            }
            queue.append(contentsOf: v.subviews)
        }

        return nil
    }

    // Walk to the visible UIViewController the user is currently seeing.
    fileprivate func topMostViewController(from base: UIViewController?) -> UIViewController? {
        guard let base = base else { return nil }

        // Follow presented chain first
        if let presented = base.presentedViewController {
            return topMostViewController(from: presented)
        }

        // UINavigationController (used by SwiftUI NavigationView/NavigationStack)
        if let nav = base as? UINavigationController {
            return topMostViewController(from: nav.visibleViewController ?? nav.topViewController) ?? nav
        }

        // UITabBarController
        if let tab = base as? UITabBarController {
            return topMostViewController(from: tab.selectedViewController) ?? tab
        }

        // UISplitViewController
        if let split = base as? UISplitViewController {
            // Prefer the detail (last), else primary (first)
            return topMostViewController(from: split.viewControllers.last ?? split.viewControllers.first) ?? split
        }

        // SwiftUI embeds controllers as children; prefer deepest visible child
        for child in base.children.reversed() {
            if let top = topMostViewController(from: child) {
                return top
            }
        }

        return base
    }

    // Try to read the SwiftUI root view type from a hosting controller-like VC via reflection.
    fileprivate func reflectSwiftUIRootType(from viewController: UIViewController) -> String? {
        let vcName = NSStringFromClass(type(of: viewController))
        // SwiftUI hosting controllers often contain "UIHostingController"/"Hosting"
        if vcName.contains("UIHostingController") || vcName.contains("Hosting") {
            let mirror = Mirror(reflecting: viewController)
            if let rv = mirror.descendant("rootView") {
                return String(describing: type(of: rv))
            }
            // If we cannot access rootView, return the VC class name as a fallback
            return vcName
        }
        return nil
    }

    // DFS search for a hosting controller within a VC subtree.
    fileprivate func findHostingController(in vc: UIViewController) -> UIViewController? {
        let name = NSStringFromClass(type(of: vc))
        if name.contains("UIHostingController") || name.contains("Hosting") {
            return vc
        }

        // Check container types
        if let nav = vc as? UINavigationController {
            if let vis = nav.visibleViewController,
               let found = findHostingController(in: vis) {
                return found
            }
            for child in nav.viewControllers.reversed() {
                if let found = findHostingController(in: child) { return found }
            }
        } else if let tab = vc as? UITabBarController {
            if let sel = tab.selectedViewController,
               let found = findHostingController(in: sel) {
                return found
            }
            for child in tab.viewControllers?.reversed() ?? [] {
                if let found = findHostingController(in: child) { return found }
            }
        } else if let split = vc as? UISplitViewController {
            for child in split.viewControllers.reversed() {
                if let found = findHostingController(in: child) { return found }
            }
        }

        // Presented controller
        if let presented = vc.presentedViewController,
           let found = findHostingController(in: presented) {
            return found
        }

        // Regular children
        for child in vc.children.reversed() {
            if let found = findHostingController(in: child) {
                return found
            }
        }

        return nil
    }

    // Known SwiftUI host view class name tokens across iOS versions.
    fileprivate func isSwiftUIHostViewName(_ className: String) -> Bool {
        let tokens = [
            "UIHostingView",
            "_UIHostingView",
            "PlatformViewHost",
            "ViewHost",
            "HostingScrollView",
            "HostingView",
            "_TtGC7SwiftUI" // mangled SwiftUI types
        ]
        return tokens.contains { className.contains($0) }
    }
}
