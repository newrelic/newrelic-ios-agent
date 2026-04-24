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
    
    // Cache for consistent SwiftUI content IDs with access tracking
    private static var contentIdCache: [ContentCacheKey: CacheEntry] = [:]
    private static let cacheQueue = DispatchQueue(label: "swiftui.contentid.cache", attributes: .concurrent)
    
    // Cache configuration
    private static let cacheCleanupInterval: TimeInterval = 60.0 // Check every 60 seconds
    private static let cacheEntryTTL: TimeInterval = 300.0 // Remove entries not accessed for 5 minutes
    private static var lastCleanupTime: Date = Date()
    
    private struct CacheEntry {
        let contentId: Int
        var lastAccessTime: Date
        
        init(contentId: Int) {
            self.contentId = contentId
            self.lastAccessTime = Date()
        }
        
        mutating func updateAccessTime() {
            self.lastAccessTime = Date()
        }
    }
    
    private struct ContentCacheKey: Hashable {
        let seed: UInt16
        let identity: UInt32
        let contentType: String
        /// Ties this key to a specific _UIHostingView instance so that two different
        /// hosting views (e.g. separate NavigationStack destination screens) never
        /// share content IDs even when SwiftUI happens to assign the same seed/identity
        /// values in their independent display lists.
        let hostingViewId: ObjectIdentifier

        init(content: SwiftUIDisplayList.Content, identity: SwiftUIDisplayList.Identity, hostingView: UIView) {
            self.seed = content.seed.value
            self.identity = identity.value
            self.hostingViewId = ObjectIdentifier(hostingView)

            // Create a type identifier based on the content value
            switch content.value {
            case .text(_, _):
                self.contentType = "text"
            case .image:
                self.contentType = "image"
            case .drawing:
                self.contentType = "drawing"
            case .shape( _, _, _):
                self.contentType = "shape"
            case .platformView:
                self.contentType = "platformView"
            case .color:
                self.contentType = "color"
            case .unknown:
                self.contentType = "unknown"
            }
        }
    }

    private static func getContentId(for content: SwiftUIDisplayList.Content, identity: SwiftUIDisplayList.Identity, hostingView: UIView) -> Int {
        let cacheKey = ContentCacheKey(content: content, identity: identity, hostingView: hostingView)
        
        return cacheQueue.sync {
            // Check if cleanup is needed
            let now = Date()
            if now.timeIntervalSince(lastCleanupTime) > cacheCleanupInterval {
                cacheQueue.async(flags: .barrier) {
                    performCacheCleanup()
                }
            }
            
            if var existingEntry = contentIdCache[cacheKey] {
                // Update access time and return existing ID
                existingEntry.updateAccessTime()
                cacheQueue.async(flags: .barrier) {
                    contentIdCache[cacheKey] = existingEntry
                }
                return existingEntry.contentId
            } else {
                let newId = IDGenerator.shared.getId()
                let newEntry = CacheEntry(contentId: newId)
                cacheQueue.async(flags: .barrier) {
                    contentIdCache[cacheKey] = newEntry
                }
                return newId
            }
        }
    }
    
    /// Performs automatic cleanup of cache entries that haven't been accessed recently
    private static func performCacheCleanup() {
        let now = Date()
        let expiredKeys = contentIdCache.compactMap { (key, entry) in
            now.timeIntervalSince(entry.lastAccessTime) > cacheEntryTTL ? key : nil
        }
        
        for key in expiredKeys {
            contentIdCache.removeValue(forKey: key)
        }
        
        lastCleanupTime = now
        
        if !expiredKeys.isEmpty {
            NRLOG_DEBUG("SwiftUI cache cleanup: removed \(expiredKeys.count) expired entries, \(contentIdCache.count) entries remaining")
        }
    }

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
                                   parentId: Int,
                                   buildSubtreeCallback: ((UIView, inout any SessionReplayViewThingy) -> Void)? = nil) -> [any SessionReplayViewThingy] {

        let viewClassName = NSStringFromClass(type(of: view))
        //print("🟢 [Orchestrator] swiftUIViewThingys ENTRY for \(viewClassName) parentId=\(parentId) contextFrame=\(context.frame)")

        if let cls = _UIGraphicsViewClass, type(of: view).isSubclass(of: cls) {
           // print("🟡 [Orchestrator] Skipping _UIGraphicsView subclass")
            return []
        }

        do {
            guard let rendererObj = getViewRenderer(from: view, keyPath: rendererKeyPath) else {
               // print("🔴 [Orchestrator] No renderer found for \(viewClassName)")
                return []
            }

            let xray = XrayDecoder(subject: rendererObj as Any)
            let viewRenderer = try SwiftUIDisplayList.ViewRenderer(xray: xray)

            guard let xrayedList = try? viewRenderer.renderer.lastList.lazyXRAY() else {
                //print("🔴 [Orchestrator] No display list for \(viewClassName)")
                NRLOG_DEBUG("Unable to extract SwiftUI ViewThingys - no display list")
                return []
            }

           // print("🟢 [Orchestrator] Display list has \(xrayedList.items.count) top-level items")

            let results = traverseDisplayList(items: xrayedList.items,
                                       context: context,
                                       renderer: viewRenderer,
                                       viewAttributes: viewAttributes,
                                       parentId: parentId,
                                       originalView: view,
                                       buildSubtreeCallback: buildSubtreeCallback)
           // print("🟢 [Orchestrator] Returning \(results.count) thingys from \(viewClassName)")
            return results
        } catch {
            //print("🔴 [Orchestrator] Error extracting SwiftUI ViewThingys: \(error)")
            return []
        }
    }
    
    // Track traversal depth for indented logging
    private static var traversalDepth: Int = 0

    // Unified traversal for content + effects
    private static func traverseDisplayList(items: [SwiftUIDisplayList.DisplayListItem],
                                            context: SwiftUIContext,
                                            renderer: SwiftUIDisplayList.ViewRenderer,
                                            viewAttributes: SwiftUIViewAttributes,
                                            parentId: Int,
                                            originalView: UIView,
                                            buildSubtreeCallback: ((UIView, inout any SessionReplayViewThingy) -> Void)? = nil) -> [any SessionReplayViewThingy] {

        guard !items.isEmpty else { return [] }

        let indent = String(repeating: "\t", count: traversalDepth)
        //print("\(indent)📋 [Traverse] \(items.count) items at depth=\(traversalDepth) contextFrame=\(context.frame)")

        var collected: [any SessionReplayViewThingy] = []
        collected.reserveCapacity(items.count)

        for (idx, item) in items.enumerated() {
            switch item.value {
            case .content(let content):
                let contentType: String
                switch content.value {
                case .text(_, _):    contentType = "text"
                case .image:         contentType = "image"
                case .drawing:       contentType = "drawing"
                case .shape:         contentType = "shape"
                case .platformView:  contentType = "platformView"
                case .color:         contentType = "color"
                case .unknown:       contentType = "unknown"
                }
                //print("\(indent)\t[\(idx)] CONTENT type=\(contentType) frame=\(item.frame) seed=\(content.seed.value) identity=\(item.identity.value)")

                if let built = buildContentThingy(item: item,
                                                  content: content,
                                                  baseContext: context,
                                                  renderer: renderer,
                                                  viewAttributes: viewAttributes,
                                                  parentId: parentId,
                                                  originalView: originalView,
                                                  buildSubtreeCallback: buildSubtreeCallback) {
                    let f = built.viewDetails.frame
                    let vis = built.viewDetails.isVisible
                    //print("\(indent)\t\t→ built \(built.viewDetails.viewName) id=\(built.viewDetails.viewId) frame=(\(Int(f.origin.x)),\(Int(f.origin.y)),\(Int(f.width)),\(Int(f.height))) visible=\(vis)")
                    if vis {
                        collected.append(built)
                    }
                    else {
                        //print("\(indent)\t\t⚠️ NOT VISIBLE, skipping")
                    }
                } else {
                   // print("\(indent)\t\t→ build returned nil")
                }

            case .effect(let effect, let nestedList):
                var nextContext = context
                nextContext.frame = context.convert(frame: item.frame)

                let effectName: String
                switch effect {
                case .platformGroup:
                    effectName = "platformGroup"
                    let displayListId = SwiftUIDisplayList.Index.ID(identity: item.identity)
                    if let viewInfo = renderer.renderer.viewCache.map[.init(id: displayListId)] {
                        nextContext.convert(to: viewInfo.frame)
                        //print("\(indent)\t[\(idx)] EFFECT platformGroup → resolved viewCache frame=\(viewInfo.frame)")
                    } else {
                        //print("\(indent)\t[\(idx)] EFFECT platformGroup → no viewCache entry")
                    }
                case .clip(let path, _):
                    effectName = "clip"
                    let clipRect = nextContext.convert(frame: path.boundingRect)
                    nextContext.clip = nextContext.clip.intersection(clipRect)
                    //print("\(indent)\t[\(idx)] EFFECT clip boundingRect=\(path.boundingRect) → clip=\(nextContext.clip)")
                case .filter(.colorMultiply(let color)):
                    effectName = "colorMultiply"
                    nextContext.setTintColor(from: color)
                    //print("\(indent)\t[\(idx)] EFFECT colorMultiply")
                case .identify:
                    effectName = "identify"
                    //print("\(indent)\t[\(idx)] EFFECT identify")
                case .filter:
                    effectName = "filter(other)"
                    //print("\(indent)\t[\(idx)] EFFECT filter(other)")
                case .unknown:
                    effectName = "unknown"
                    //print("\(indent)\t[\(idx)] EFFECT unknown")
                }

                //print("\(indent)\t\t↳ nested items=\(nestedList.items.count) effectName=\(effectName)")
                traversalDepth += 2
                let nested = traverseDisplayList(items: nestedList.items,
                                                 context: nextContext,
                                                 renderer: renderer,
                                                 viewAttributes: viewAttributes,
                                                 parentId: parentId,
                                                 originalView: originalView,
                                                 buildSubtreeCallback: buildSubtreeCallback)
                traversalDepth -= 2
                //print("\(indent)\t\t↳ nested returned \(nested.count) thingys")
                collected.append(contentsOf: nested)

            case .unknown:
                //print("\(indent)\t[\(idx)] UNKNOWN item, skipping")
                continue
            }
        }

        //print("\(indent)📋 [Traverse] returning \(collected.count) items from depth=\(traversalDepth)")
        return collected
    }
    
    // Consolidated content handling
    private static func buildContentThingy(item: SwiftUIDisplayList.DisplayListItem,
                                           content: SwiftUIDisplayList.Content,
                                           baseContext: SwiftUIContext,
                                           renderer: SwiftUIDisplayList.ViewRenderer,
                                           viewAttributes: SwiftUIViewAttributes,
                                           parentId: Int,
                                           originalView: UIView,
                                           buildSubtreeCallback: ((UIView, inout any SessionReplayViewThingy) -> Void)? = nil) -> (any SessionReplayViewThingy)? {

        let buildIndent = String(repeating: "\t", count: traversalDepth + 2)

        // Use the hash-based cache to get a consistent ID for this content
        var contentId: Int?

        let frame = baseContext.convert(frame: item.frame)
        var viewName = "SwiftUIView"

        //print("\(buildIndent)🏗️ buildContent: itemFrame=\(item.frame) → convertedFrame=\(frame) seed=\(content.seed.value)")

        func makeDetails(widthOffset: CGFloat = 0, alphaOverride: CGFloat? = nil) -> ViewDetails {
                    let adjustedFrame = CGRect(x: frame.origin.x,
                                               y: frame.origin.y,
                                               width: frame.size.width + widthOffset,
                                               height: frame.size.height)
            var bgColor: UIColor? = UIColor(cgColor: viewAttributes.backgroundColor ?? UIColor.clear.cgColor)
            if viewName == "HostingView" {
                bgColor = UIColor.clear
            }
                    return ViewDetails(frame: adjustedFrame,
                                clip: viewAttributes.clip,
                                       backgroundColor: bgColor ?? UIColor.clear,
                                alpha: alphaOverride ?? viewAttributes.alpha,
                                isHidden: viewAttributes.isHidden,
                                viewName: viewName,
                                parentId: parentId,
                                cornerRadius: viewAttributes.layerCornerRadius,
                                borderWidth: viewAttributes.layerBorderWidth,
                                borderColor: UIColor(cgColor:viewAttributes.layerBorderColor ?? UIColor.clear.cgColor),
                                viewId: contentId,
                                view: originalView,
                                maskApplicationText: viewAttributes.maskApplicationText,
                                maskUserInputText: viewAttributes.maskUserInputText,
                                maskAllImages: viewAttributes.maskAllImages,
                                maskAllUserTouches: viewAttributes.maskAllUserTouches,
                                blockView: viewAttributes.blockView,
                                sessionReplayIdentifier: viewAttributes.sessionReplayIdentifier)
        }
        
        switch content.value {
        case let SwiftUIDisplayList.Content.Value.shape(path, fillColor, fillStyle):
            contentId = getContentId(for: content, identity: item.identity, hostingView: originalView)
            viewName = "SwiftUIShapeView"
            //print("\(buildIndent)\t🔷 SHAPE id=\(contentId ?? -1) fillColor=\(fillColor) bounds=\(path.boundingRect)")
            var details = makeDetails()
            details.backgroundColor = .clear

            return SwiftUIShapeThingy(viewDetails: details,
                                     path: path,
                                     fillColor: fillColor,
                                     fillStyle: fillStyle,
                                     fallbackTintColor: baseContext.tintColor)
        case SwiftUIDisplayList.Content.Value.text(let textView, _):
            let storage = textView.text.storage
            let rawString = storage.string

            // 1. Split the string into lines
            let lines = rawString.components(separatedBy: .newlines)

            // 2. Find the line with the maximum number of spaces
            let maxSpacesOnOneLine = lines.map { line in
                line.filter { $0 == " " }.count
            }.max() ?? 0
            // 3. Calculate offset (max spaces * 2)
            let calculatedOffset = CGFloat(maxSpacesOnOneLine * 2)

            contentId = getContentId(for: content, identity: item.identity, hostingView: originalView)
            viewName = "SwiftUITextView"
            let truncatedText = rawString.prefix(60).replacingOccurrences(of: "\n", with: "\\n")
            
            //print("\(buildIndent)\t📝 TEXT id=\(contentId ?? -1) \"\(truncatedText)\" widthOffset=\(calculatedOffset)")
            
            let details = makeDetails(widthOffset: calculatedOffset)

            let iOS15 = ProcessInfo.processInfo.operatingSystemVersion.majorVersion <= 15
            if iOS15 {
                return UILabelThingy(viewDetails: details,
                                     attributedText: storage, iOS15Override:true)
            }
            else {
                return UILabelThingy(viewDetails: details,
                                     attributedText: storage)
            }


        case let SwiftUIDisplayList.Content.Value.color(colorData):
            contentId = getContentId(for: content, identity: item.identity, hostingView: originalView)
            viewName = "SwiftUIColorView"
            
            //print("\(buildIndent)\t🎨 COLOR id=\(contentId ?? -1) color=\(colorData.uiColor)")
            
            var details = makeDetails()
            details.backgroundColor = colorData.uiColor
            return UIViewThingy(viewDetails: details)
        case let SwiftUIDisplayList.Content.Value.image(swiftUIImage):
            var image: CGImage?
            switch swiftUIImage.contents {
            case .cgImage(let cgImage):
                image = cgImage
            case .unknown:
                break
            }

            contentId = getContentId(for: content, identity: item.identity, hostingView: originalView)

            viewName = "SwiftUIImageView"
            let imgSize = image.map { "(\($0.width)x\($0.height))" } ?? "(nil)"
            
            //print("\(buildIndent)\t🖼️ IMAGE id=\(contentId ?? -1) size=\(imgSize) scale=\(swiftUIImage.scale)")
            
            var details = makeDetails()
            details.backgroundColor = .clear

            return UIImageViewThingy(viewDetails: details,
                                     cgImage: image,
                                     swiftUIImage: swiftUIImage,
                                     contentMode: .scaleToFill)
        case SwiftUIDisplayList.Content.Value.drawing(let erasedDrawing):
            contentId = getContentId(for: content, identity: item.identity, hostingView: originalView)
            viewName = "SwiftUIDrawingView"
            
            //print("\(buildIndent)\t✏️ DRAWING id=\(contentId ?? -1)")
            
            var details = makeDetails()
            details.backgroundColor = .clear

            // Convert drawing to UIImage
            guard let image = erasedDrawing.makeSwiftUIImage(),
                  let cgImage = image.cgImage else {
               // print("\(buildIndent)\t\t⚠️ Drawing → image conversion failed")
                return nil
            }

            // Get tint color from context (foreground color from colorMultiply filter)
            let maskColor: Color._ResFoundColor? = if let tintColor = baseContext.tintColor {
                Color._ResFoundColor(
                    linearRed: Float(tintColor.cgColor.components?[0] ?? 0),
                    linearGreen: Float(tintColor.cgColor.components?[1] ?? 0),
                    linearBlue: Float(tintColor.cgColor.components?[2] ?? 0),
                    opacity: Float(tintColor.cgColor.alpha)
                )
            } else {
                nil
            }

            // Create SwiftUIGraphicsImage from the generated CGImage
            let swiftUIImage = SwiftUIGraphicsImage(
                contents: .cgImage(cgImage),
                scale: image.scale,
                maskClr: maskColor,
                orientation: .up
            )

            return UIImageViewThingy(viewDetails: details,
                                     cgImage: cgImage,
                                     swiftUIImage: swiftUIImage,
                                     contentMode: .scaleToFill)
        case SwiftUIDisplayList.Content.Value.platformView:
            contentId = getContentId(for: content, identity: item.identity, hostingView: originalView)
            viewName = "SwiftUIPlatformView"
            var details = makeDetails()
            //print("\(buildIndent)\t📱 PLATFORM_VIEW id=\(contentId ?? -1) frame=\(frame)")

            let displayListId = SwiftUIDisplayList.Index.ID(identity: item.identity)
            let viewInfo = renderer.renderer.viewCache.map[.init(id: displayListId)]
            if let bgColor = viewInfo?.backgroundColor {
                details.backgroundColor = UIColor(cgColor: bgColor)
            } else {
                details.backgroundColor = .clear
            }

            var thingy: any SessionReplayViewThingy = UIViewThingy(viewDetails: details)
            if let platformUIView = viewInfo?.uiView, let callback = buildSubtreeCallback {
                //print("\(buildIndent)\t\t🔗 PLATFORM_VIEW bridging into UIKit subtree for \(NSStringFromClass(type(of: platformUIView)))")
                callback(platformUIView, &thingy)
            }
            return thingy
        case SwiftUIDisplayList.Content.Value.unknown:
            contentId = getContentId(for: content, identity: item.identity, hostingView: originalView)
            //print("\(buildIndent)\t❓ UNKNOWN content id=\(contentId ?? -1) frame=\(frame)")
            var details = makeDetails()
            details.backgroundColor = .clear
            return UIViewThingy(viewDetails: details)
        }
    }
}

@available(iOS 13.0, *)
extension SwiftUI.Image.Orientation {
    func toUIImageOrientation() -> UIImage.Orientation {
        switch self {
        case .up:
            return .up
        case .upMirrored:
            return .upMirrored
        case .down:
            return .down
        case .downMirrored:
            return .downMirrored
        case .left:
            return .left
        case .leftMirrored:
            return .leftMirrored
        case .right:
            return .right
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            return .up
        }
    }
}
