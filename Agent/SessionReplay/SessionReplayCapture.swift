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
    private var layoutContainerViewCount: Int = 0
    private var navigationStackDepth: Int = 0
    private var rootSwiftUIViewID: Int? = nil
    
    @MainActor
    public func recordFrom(rootView:UIView) -> SessionReplayFrame {
        let effectiveViewController = findRootViewController(rootView: rootView)
        var rootViewControllerID:String?
        if let rootViewController = effectiveViewController {
            rootViewControllerID = String(describing: type(of: rootViewController))
        }

        var rootThingy = findRecorderForView(view: rootView)

        // Reset counters for this frame capture
        layoutContainerViewCount = 0
        navigationStackDepth = 0
        rootSwiftUIViewID = nil

        // Log the UIKit view hierarchy before building the tree
        //logUIKitViewHierarchy(rootView)

        // Build tree using recursive approach to properly handle value semantics
        buildViewTree(for: rootView, into: &rootThingy)

        //NRLOG_DEBUG("START THINGYS")

        // Log the built thingy tree after construction
        //logThingyTree(rootThingy, depth: 0)

        //NRLOG_DEBUG("END THINGYS")

        // Set nextId for all views after tree is built
        setNextIdRecursively(for: &rootThingy)

        return SessionReplayFrame(date: Date(), views: rootThingy, rootViewControllerId: rootViewControllerID, rootSwiftUIViewId: rootSwiftUIViewID, size: rootView.frame.size, layoutContainerViewCount: layoutContainerViewCount, navigationStackDepth: navigationStackDepth)
    }

    // MARK: - Hierarchy Logging

    @MainActor
    private func logUIKitViewHierarchy(_ view: UIView, depth: Int = 0) {
        let indent = String(repeating: "\t", count: depth)
        let className = NSStringFromClass(type(of: view))
        let frame = view.frame
        let hidden = view.isHidden ? " [HIDDEN]" : ""
        let alpha = view.alpha < 1.0 ? " alpha=\(String(format: "%.2f", view.alpha))" : ""
        let accessId = view.accessibilityIdentifier.map { " id=\"\($0)\"" } ?? ""
        let vcInfo: String
        if let vc = view.parentViewController {
            vcInfo = " vc=\(type(of: vc))"
        } else {
            vcInfo = ""
        }

        print("\(indent)📐 \(className)\(accessId)\(vcInfo) frame=(\(Int(frame.origin.x)),\(Int(frame.origin.y)),\(Int(frame.width)),\(Int(frame.height)))\(hidden)\(alpha) subviews=\(view.subviews.count)")

        for subview in view.subviews {
            logUIKitViewHierarchy(subview, depth: depth + 1)
        }
    }

    private func logThingyTree(_ thingy: any SessionReplayViewThingy, depth: Int) {
        let indent = String(repeating: "\t", count: depth)
        let details = thingy.viewDetails
        let frame = details.frame
        let visible = details.isVisible ? "" : " [NOT VISIBLE]"
        let bg = details.backgroundColor != .clear ? " bg=\(details.backgroundColor)" : ""

        print("\(indent)🧩 \(details.viewName) id=\(details.viewId) parent=\(details.parentId ?? -1) frame=(\(Int(frame.origin.x)),\(Int(frame.origin.y)),\(Int(frame.width)),\(Int(frame.height)))\(visible)\(bg) children=\(thingy.subviews.count)")

        for child in thingy.subviews {
            logThingyTree(child, depth: depth + 1)
        }
    }
    
    private var buildTreeDepth: Int = 0

    private func buildViewTree(for currentView: UIView, into parentThingy: inout any SessionReplayViewThingy) {
        let indent = String(repeating: "\t", count: buildTreeDepth)
        let currentClassName = NSStringFromClass(type(of: currentView))

        //print("\(indent)🔨 buildViewTree: \(currentClassName) (subviews=\(currentView.subviews.count), shouldRecord=\(parentThingy.shouldRecordSubviewsComputed), parentThingy=\(parentThingy.viewDetails.viewName))")

        // Process UIKit subviews only if current view should record subviews
        if parentThingy.shouldRecordSubviewsComputed {
            for (idx, subview) in currentView.subviews.enumerated() {
                let subClassName = NSStringFromClass(type(of: subview))
                let shouldRec = shouldRecord(view: subview)

                //print("\(indent)\t[\(idx)] \(subClassName) frame=\(subview.frame) shouldRecord=\(shouldRec)")

                if shouldRec {
                    var childThingy = findRecorderForView(view: subview)
                    let isVisible = childThingy.viewDetails.isVisible

                    //print("\(indent)\t\t→ thingy=\(childThingy.viewDetails.viewName) visible=\(isVisible)")

                    if isVisible {
                        buildTreeDepth += 2
                        buildViewTree(for: subview, into: &childThingy)
                        buildTreeDepth -= 2

                        parentThingy.subviews.append(childThingy)
                        //print("\(indent)\t\t✅ appended \(childThingy.viewDetails.viewName) (id=\(childThingy.viewDetails.viewId)) to parent \(parentThingy.viewDetails.viewName) (id=\(parentThingy.viewDetails.viewId)), parent now has \(parentThingy.subviews.count) children")
                    }
                } else {
                    //print("\(indent)\t\t⏭️ skipping \(subClassName), recursing into its children with same parent")
                    buildTreeDepth += 2
                    buildViewTree(for: subview, into: &parentThingy)
                    buildTreeDepth -= 2
                }
            }
        } else {
            //print("\(indent)\t⛔ shouldRecordSubviews=false, skipping UIKit subviews")
        }
        let className = NSStringFromClass(type(of: currentView))

        // Handle SwiftUI hosting views.
        if let viewController = extractVC(from: currentView) {
            let vcType = ControllerTypeDetector(from: NSStringFromClass(type(of: viewController)))
            //print("\(indent)🎭 Found VC: \(type(of: viewController)) vcType=\(vcType)")
            
            if vcType == .hostingController || vcType == .navigationStackHostingController {
                //print("\(indent)\t🏠 Hosting view detected: \(className)")
                
                if className.contains("_UIHostingView") || className.hasSuffix("HostingView") {
                    rootSwiftUIViewID = parentThingy.viewDetails.viewId
                    //print("\(indent)\t\t🌳 Set rootSwiftUIViewID=\(parentThingy.viewDetails.viewId)")
                    if vcType == .navigationStackHostingController {
                        navigationStackDepth += 1
                        //print("\(indent)\t\t📚 NavigationStack depth now: \(navigationStackDepth)")
                    }
                }
            }


                let viewAttributes = SwiftUIViewAttributes(frame: parentThingy.viewDetails.frame,
                                                           clip: parentThingy.viewDetails.clip,
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
                                                           maskAllUserTouches: currentView.maskAllUserTouches,
                                                           blockView: currentView.blockView,
                                                           sessionReplayIdentifier: currentView.swiftUISessionReplayIdentifier
                )

                let context = SwiftUIContext(frame: parentThingy.viewDetails.frame, clip: parentThingy.viewDetails.clip)

                //print("\(indent)\t\t🔍 Extracting SwiftUI display list from \(className)...")
                let subviewCallback: (UIView, inout any SessionReplayViewThingy) -> Void = { [weak self] (platformView, thingy) in
                    self?.buildViewTree(for: platformView, into: &thingy)
                }
                let thingys = UIHostingViewRecordOrchestrator.swiftUIViewThingys(currentView, context: context, viewAttributes: viewAttributes, parentId: parentThingy.viewDetails.viewId, buildSubtreeCallback: subviewCallback)
          
                //print("\(indent)\t\t📦 Got \(thingys.count) SwiftUI thingys from display list")
//                for (i, t) in thingys.enumerated() {
//                    let f = t.viewDetails.frame
//                    print("\(indent)\t\t\t[\(i)] \(t.viewDetails.viewName) id=\(t.viewDetails.viewId) frame=(\(Int(f.origin.x)),\(Int(f.origin.y)),\(Int(f.width)),\(Int(f.height))) visible=\(t.viewDetails.isVisible)")
//                }

                if !thingys.isEmpty {
                    var colorViews: [any SessionReplayViewThingy] = []
                    var otherViews: [any SessionReplayViewThingy] = []

                    for thingy in thingys {
                        if thingy.viewDetails.viewName == "SwiftUIColorView"
                            || thingy.viewDetails.viewName == "SwiftUIPlatformView" {
                            colorViews.append(thingy)
                        } else {
                            otherViews.append(thingy)
                        }
                    }

                    //print("\(indent)\t\t🎨 Sorted: \(colorViews.count) color views (→ front of array), \(otherViews.count) other views (→ end)")

                    if parentThingy.shouldRecordSubviewsComputed {
                        parentThingy.subviews.insert(contentsOf: colorViews, at: 0)
                        parentThingy.subviews.append(contentsOf: otherViews)
                        //print("\(indent)\t\t✅ Parent \(parentThingy.viewDetails.viewName) now has \(parentThingy.subviews.count) total children after SwiftUI merge")
                    }
                }
            }

        // Handle UITextField custom text overlay
        if parentThingy.shouldRecordSubviewsComputed, let textView = currentView as? UITextField {
            let textViewThingy = CustomTextThingy(view: textView, viewDetails: ViewDetails(view: currentView))
            parentThingy.subviews.append(textViewThingy)
        }
        // Count UILayoutContainerViews if we're inside a UIPanelControllerContentView
        if let parentView = currentView.superview {
            let parentClassName = NSStringFromClass(type(of: parentView))
            if parentClassName.contains("UIPanelControllerContentView") && parentThingy.viewDetails.viewName.contains("UILayoutContainerView") {
                layoutContainerViewCount += 1
            }
        }
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

        #if os(iOS)
        case let datePicker as UIDatePicker:
            return UIDatePickerThingy(view: datePicker, viewDetails: ViewDetails(view: datePicker))

        case let switchControl as UISwitch:
            return UISwitchThingy(view: switchControl, viewDetails: ViewDetails(view: switchControl))
        #endif

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

        if areFramesTheSame && isClear {
            // Still record navigation bar internal views and SwiftUI platform view hosts.
            let className = NSStringFromClass(type(of: view))
            if className.contains("NavigationBar") || className.contains("LargeTitle")
                || className.contains("UIKitPlatformViewHost") {
                return true
            }
            return false
        }
        return true
    }
    
    private func setNextIdRecursively(for thingy: inout any SessionReplayViewThingy) {
        // Process children in reverse order to build the nextId linked list
        var nextId: Int? = nil
        for i in stride(from: thingy.subviews.count - 1, through: 0, by: -1) {
            // Recursively process this child's subviews first
            setNextIdRecursively(for: &thingy.subviews[i])
            
            // Then set this child's nextId
            thingy.subviews[i].viewDetails.nextId = nextId
            nextId = thingy.subviews[i].viewDetails.viewId
        }
    }
}

