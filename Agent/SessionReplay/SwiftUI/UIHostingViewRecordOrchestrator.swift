//
//  UIHostingViewRecorder.swift
//  Agent
//
//  Created by Chris Dillard on 9/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

@available(iOS 13.0, *)
final class UIHostingViewRecordOrchestrator {
    
    // Original static metadata
    static let _UIGraphicsViewClass: AnyClass? = NSClassFromString(SwiftUIConstants.UIGraphicsView.rawValue)
    
    private static let rendererKeyPath: [String] = {
        var keys = ["renderer"]
        if #available(iOS 18.1, tvOS 18.1, *) { keys.insert("_base", at: 0) }
        if #available(iOS 26, tvOS 26, *) { keys.insert("viewGraph", at: keys.count - 1) }
        return keys
    }()
    
    // Entry point (renamed for clarity; keep old name if externally referenced)
    static func swiftUIViewThingys(_ view: UIView,
                                   context: SwiftUIContext,
                                   viewAttributes: SwiftUIViewAttributes,
                                   parentId: Int) -> [any SessionReplayViewThingy] {
        
        if let cls = _UIGraphicsViewClass, type(of: view).isSubclass(of: cls) { return [] }
        
        do {
            guard let rendererObj = try? getViewRenderer(from: view, keyPath: rendererKeyPath) else { return [] }
            let xray = XrayDecoder(subject: rendererObj as Any)
            let viewRenderer = try SwiftUIDisplayList.ViewRenderer(xray: xray)
            
            guard let xrayedList = try? viewRenderer.renderer.lastList.lazyXRAY() else {
                NRLOG_DEBUG("Unable to extract SwiftUI ViewThingys - no display list")
                return []
            }
            
            return traverseDisplayList(items: xrayedList.items,
                                       context: context,
                                       renderer: viewRenderer,
                                       viewAttributes: viewAttributes,
                                       parentId: parentId)
        } catch {
            //NRLOG_DEBUG("Error extracting SwiftUI ViewThingys: \(error)")
            return []
        }
    }
    
    // Unified traversal for content + effects
    private static func traverseDisplayList(items: [SwiftUIDisplayList.Item],
                                            context: SwiftUIContext,
                                            renderer: SwiftUIDisplayList.ViewRenderer,
                                            viewAttributes: SwiftUIViewAttributes,
                                            parentId: Int) -> [any SessionReplayViewThingy] {
        
        guard !items.isEmpty else { return [] }
        
        var collected: [any SessionReplayViewThingy] = []
        collected.reserveCapacity(items.count)
        
        for item in items {
            switch item.value {
            case .content(let content):
                if let built = buildContentThingy(item: item,
                                                  content: content,
                                                  baseContext: context,
                                                  renderer: renderer,
                                                  viewAttributes: viewAttributes,
                                                  parentId: parentId) {
                    collected.append(built)
                }
                
            case .effect(let effect, let nestedList):
                var nextContext = context
                nextContext.frame = context.convert(frame: item.frame)
                
                switch effect {
                case .platformGroup:
                    let displayListId = SwiftUIDisplayList.Index.ID(identity: item.identity)
                    if let viewInfo = renderer.renderer.viewCache.map[.init(id: displayListId)] {
                        nextContext.convert(to: viewInfo.frame)
                    }
                case .clip(let path, _):
                    let clipRect = nextContext.convert(frame: path.boundingRect)
                    nextContext.clip = nextContext.clip.intersection(clipRect)
                case .filter(.colorMultiply(let color)):
                    nextContext.tintColor = color
                case .identify, .filter, .unknown:
                    break
                }
                
                let nested = traverseDisplayList(items: nestedList.items,
                                                 context: nextContext,
                                                 renderer: renderer,
                                                 viewAttributes: viewAttributes,
                                                 parentId: parentId)
                collected.append(contentsOf: nested)
                
            case .unknown:
                continue
            }
        }
        
        return collected
    }
    
    // Consolidated content handling
    private static func buildContentThingy(item: SwiftUIDisplayList.Item,
                                           content: SwiftUIDisplayList.Content,
                                           baseContext: SwiftUIContext,
                                           renderer: SwiftUIDisplayList.ViewRenderer,
                                           viewAttributes: SwiftUIViewAttributes,
                                           parentId: Int) -> (any SessionReplayViewThingy)? {
        
        let displayListId = Int(SwiftUIDisplayList.Index.ID(identity: item.identity).identity.value)
        let frame = baseContext.convert(frame: item.frame)
        let viewName = randomString()
                
        func makeDetails() -> ViewDetails {
            ViewDetails(frame: frame,
                        clip: viewAttributes.clip,
                        backgroundColor: UIColor(cgColor: viewAttributes.backgroundColor ?? UIColor.clear.cgColor),
                        alpha: viewAttributes.alpha,
                        isHidden: viewAttributes.isHidden,
                        viewName: viewName,
                        parentId: parentId,
                        cornerRadius: viewAttributes.layerCornerRadius,
                        borderWidth: viewAttributes.layerBorderWidth,
                        viewId: displayListId)
        }
        
        switch content.value {
        case SwiftUIDisplayList.Content.Value.shape:
            return nil // TODO: Shapes
        case SwiftUIDisplayList.Content.Value.text(let textView, _):
            let storage = textView.text.storage

            let foregroundColor =
            storage.attribute(NSAttributedString.Key.foregroundColor, at: 0, effectiveRange: nil) as? UIColor ?? .clear
            let font =
            storage.attribute(NSAttributedString.Key.font, at: 0, effectiveRange: nil) as? UIFont

            var alignment: NSTextAlignment = .left
            if let style = storage.attribute(NSAttributedString.Key.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
                alignment = style.alignment
                _ = style.lineSpacing
                _ = style.lineBreakMode
            }

            // Extract accessibility identifier via deep reflection on original view
//            NRLOG_DEBUG("═══════════════════════════════════════════")
//            NRLOG_DEBUG("🔍 Attempting to extract accessibility info from text view")
//            SwiftUIDeepReflector.debugPrintTopLevel(of: textView.originalSubject, label: "Text View Original Subject")

            //let accessibilityInfo = SwiftUIDeepReflector.extractAccessibilityInfo(from: textView.originalSubject)
            //NRLOG_DEBUG("Final result - acc info = \(String(describing: accessibilityInfo))")
            // TODO: FIx AccessibilityIdentifier getting
            var accessibilityIdentifier: String? //accessibilityInfo?.identifier

            var details = makeDetails()

            // Apply masking based on accessibility identifier
            if let identifier = accessibilityIdentifier {
                if identifier == "nr-mask" || identifier.hasSuffix(".nr-mask") {
                    details.isMasked = true
                } else if identifier == "nr-unmask" || identifier.hasSuffix(".nr-unmask") {
                    details.isMasked = false
                }
                // TODO: Check against global masking lists
                // else {
                //     if let agent = NewRelicAgentInternal.sharedInstance() {
                //         if agent.isAccessibilityIdentifierMasked(identifier) {
                //             details.isMasked = true
                //         } else if agent.isAccessibilityIdentifierUnmasked(identifier) {
                //             details.isMasked = false
                //         }
                //     }
                // }
            }

            return UILabelThingy(viewDetails: details,
                                 text: storage.string,
                                 textAlignment: alignment.stringValue(),
                                 fontSize: font?.pointSize ?? 10,
                                 fontName: font?.fontName ?? ".SFUI-Bold",
                                 fontFamily: font?.familyName ?? ".AppleSystemUIFont",
                                 textColor: foregroundColor)
            
        case SwiftUIDisplayList.Content.Value.color:
            return nil // TODO: Colors
        case let SwiftUIDisplayList.Content.Value.image(resolved):  // TODO: Images
            return UIViewThingy(viewDetails: makeDetails())
        case SwiftUIDisplayList.Content.Value.drawing:
            return nil // TODO: Drawings
        case SwiftUIDisplayList.Content.Value.platformView:
            return UIViewThingy(viewDetails: makeDetails())
        case SwiftUIDisplayList.Content.Value.unknown:
            return UIViewThingy(viewDetails: makeDetails())
        }
    }
}
