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


// potentially remove this annotation once the feature goes to Swift

// available in ioS13 and up
@objcMembers
@available(iOS 14.0, *)
class SessionReplayCapture {
    
    @MainActor
    public func recordFrom(rootView:UIView) async -> SessionReplayFrame {
        let effectiveViewController = findRootViewController(rootView: rootView)
        var rootViewControllerID:String?
        if let rootViewController = effectiveViewController {
            rootViewControllerID = String(describing: type(of: rootViewController))
        }
        
        struct ViewPair {
            let view:UIView
            let parentRecorder:any SessionReplayViewThingy
        }
        
        var viewStack = ContiguousArray<ViewPair>()
        
        let rootThingy = await findRecorderForView(view: rootView)
        
        viewStack.append(ViewPair(view: rootView, parentRecorder: rootThingy))
        
        while let pair = viewStack.popLast() {
            let currentView = pair.view
            var currentParentThingy = pair.parentRecorder
            
            for subview in currentView.subviews {
                if (shouldRecord(view: subview)) {
                    let childThingy = await findRecorderForView(view: subview)
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
                currentParentThingy.subviews.append(textViewThingy)// Adding text to the bottom of a UITextFieldThingy because the _UITextFieldRoundedRectBackgroundViewNeue covers it.
            }
            var nextId:Int? = nil
            for var childView in currentParentThingy.subviews.reversed() {
                childView.viewDetails.nextId = nextId
                nextId = childView.viewDetails.viewId
            }
        }
        
        return SessionReplayFrame(date: Date(), views: rootThingy, rootViewControllerId: rootViewControllerID, size: rootView.frame.size)
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
    
    @MainActor private func findRecorderForView(view originalView: UIView) async -> any SessionReplayViewThingy {
        
        let viewType = String(describing: type(of: originalView))
        //print("Finding recorder for view type: \(viewType)")
        if viewType.starts(with: "_UIHostingView"),
           let swiftUIRoot = extractSwiftUIRootView(from: originalView) as? (any View) {
            
            // Decompile SwiftUI views with introspection data
           // let swiftUIViews = [String: DecompiledView]()//SwiftUIViewHierarchyRecorder.decompile(swiftUIRoot: swiftUIRoot)
            let swiftUIViews = SwiftUIViewHierarchyRecorder.decompile(swiftUIRoot: swiftUIRoot)

//            print("Decompiled \(swiftUIViews.count) SwiftUI views")
//            print("SwiftUI Views: \(swiftUIViews)")
            // Convert SwiftUI metadata -> thingies
            let swiftUISubThingies: [any SessionReplayViewThingy] = swiftUIViews
                .sorted(by: { $0.key < $1.key })
                .compactMap { (path, decompiledView) in
                    // Create unique ViewDetails using SwiftUI path for unique ID generation
                    let viewDetails = ViewDetails(swiftUIPath: path, frame: decompiledView.frame, baseView: originalView)

                    // Try to get introspected UIKit data for this view
                    let introspectedData = IntrospectedDataManager.shared.getIntrospectedData(for: path)

                    switch decompiledView.kind {
                    case .text(let text):
                        if let introspected = introspectedData,
                           let font = introspected.properties["font"] as? UIFont,
                           let textColor = introspected.properties["textColor"] as? UIColor,
                           let actualText = introspected.properties["text"] as? String {
                            return UILabelThingy(view: UILabel(),
                                viewDetails: viewDetails
                            )
                        }
                        else {
                            return UILabelThingy(view: UILabel(),
                                viewDetails: viewDetails
                            )
                        }

                    case .image:
                        return UIImageViewThingy(view: UIImageView(), viewDetails: viewDetails)

                    case .textField:
                        if let introspected = introspectedData,
                           let isSecure = introspected.properties["isSecureTextEntry"] as? Bool {
                            return SwiftUITextFieldThingy(isSecure: isSecure, viewDetails: viewDetails)
                        } else {
                            return SwiftUITextFieldThingy(isSecure: false, viewDetails: viewDetails)
                        }

                    case .button:
                        if let introspected = introspectedData,
                           let title = introspected.properties["title"] as? String {
                            return SwiftUIButtonThingy(title: title, viewDetails: viewDetails)
                        } else {
                            return SwiftUIButtonThingy(title: "Button", viewDetails: viewDetails)
                        }

                    case .list, .scrollView, .toggle, .slider, .stepper, .datePicker, .picker, .table:
                        return UIViewThingy(view: originalView, viewDetails: viewDetails)

                    case .other(let name):
                        return UIViewThingy(view: originalView, viewDetails: viewDetails)
                    }
                }
            
            print("Decompiled \(swiftUISubThingies.count) swiftUISubThingies")

            // Establish parent-child relationships using path hierarchy
            var swiftUISubThingiesWithPaths = Array(zip(swiftUIViews.sorted(by: { $0.key < $1.key }), swiftUISubThingies))
            establishSwiftUIParentChildRelationships(thingiesWithPaths: &swiftUISubThingiesWithPaths)

            for thingy in swiftUISubThingies {
                // print all info about thingy
                print("swiftUISubThingy: \(thingy), frame: \(thingy.viewDetails.frame), id: \(thingy.viewDetails.viewId), parentId: \(thingy.viewDetails.parentId ?? -1), nextId: \(thingy.viewDetails.nextId ?? -1), isVisible: \(thingy.viewDetails.isVisible)")
            }


            let hostingThingy = UIViewThingy(view: originalView,
                                             viewDetails: ViewDetails(view: originalView))
            // print("SwiftUI Subthingies count: \(swiftUISubThingies.count)")
            hostingThingy.subviews.append(contentsOf: swiftUISubThingies)
            return hostingThingy
        }
        else {
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
    }
    
    private func shouldRecord(view: UIView) -> Bool {
        guard let superview = view.superview else {
            return true
        }
        
        let areFramesTheSame = CGRectEqualToRect(view.frame, superview.frame)
        let isClear = (view.alpha == 0)
        
        return !(areFramesTheSame && isClear)
    }
    
    private func extractSwiftUIRootView(from hostingSubview: UIView) -> Any? {
        var responder: UIResponder? = hostingSubview
        while let current = responder {
            if let hosting = current as? AnyHostingController {
                return hosting.anyRootView
            }
            responder = current.next
        }
        return nil
    }

    @MainActor private func establishSwiftUIParentChildRelationships( thingiesWithPaths: inout [((key: String, value: DecompiledView), any SessionReplayViewThingy)]) {
        // Create a map from path to thingy for fast lookup
        var pathToThingy: [String: any SessionReplayViewThingy] = [:]

        for ((path, _), thingy) in thingiesWithPaths {
            pathToThingy[path] = thingy
        }

        // For each thingy, find its parent and set the parent ID
        for ((path, _), thingy) in thingiesWithPaths {
            var thingy = thingy
            if let parentPath = PathGenerator.shared.getParent(for: path),
               let parentThingy = pathToThingy[parentPath] {
                thingy.viewDetails.parentId = parentThingy.viewDetails.viewId
                print("[ParentChild] \(path) -> parent: \(parentPath), parentId: \(parentThingy.viewDetails.viewId)")
            } else {
                // Root level views have no parent
                thingy.viewDetails.parentId = nil
                print("[ParentChild] \(path) -> no parent (root level)")
            }
        }
    }
}
private protocol AnyHostingController {
    var anyRootView: Any { get }
}

@available(iOS 13.0, *)
extension UIHostingController: AnyHostingController {
    var anyRootView: Any { rootView }
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
