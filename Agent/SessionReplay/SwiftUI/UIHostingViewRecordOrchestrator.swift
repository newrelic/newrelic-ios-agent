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
        
        init(content: SwiftUIDisplayList.Content, identity: SwiftUIDisplayList.Identity) {
            self.seed = content.seed.value
            self.identity = identity.value
            
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
    
    private static func getContentId(for content: SwiftUIDisplayList.Content, identity: SwiftUIDisplayList.Identity) -> Int {
        let cacheKey = ContentCacheKey(content: content, identity: identity)
        
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
                                   parentId: Int) -> [any SessionReplayViewThingy] {


        
        if let cls = _UIGraphicsViewClass, type(of: view).isSubclass(of: cls) { return [] }
        
        do {
            guard let rendererObj = getViewRenderer(from: view, keyPath: rendererKeyPath) else { return [] }
                        
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
                                       parentId: parentId,
                                       originalView: view)
        } catch {
            //NRLOG_AGENT_DEBUG("Error extracting SwiftUI ViewThingys: \(error)")
            return []
        }
    }
    
    // Unified traversal for content + effects
    private static func traverseDisplayList(items: [SwiftUIDisplayList.DisplayListItem],
                                            context: SwiftUIContext,
                                            renderer: SwiftUIDisplayList.ViewRenderer,
                                            viewAttributes: SwiftUIViewAttributes,
                                            parentId: Int,
                                            originalView: UIView) -> [any SessionReplayViewThingy] {
        
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
                                                  parentId: parentId,
                                                  originalView: originalView) {
                    if built.viewDetails.isVisible {
                        collected.append(built)
                    }
                }
                
            case .effect(let effect, let nestedList):
                var nextContext = context
                nextContext.frame = context.convert(frame: item.frame)
                
                switch effect {
                case .platformGroup:
                    let displayListId = SwiftUIDisplayList.Index.ID(identity: item.identity)
                   // print("encountered displayListId \(displayListId)")

                    if let viewInfo = renderer.renderer.viewCache.map[.init(id: displayListId)] {
                        nextContext.convert(to: viewInfo.frame)
                    }
                case .clip(let path, _):
                    let clipRect = nextContext.convert(frame: path.boundingRect)
                    nextContext.clip = nextContext.clip.intersection(clipRect)
                case .filter(.colorMultiply(let color)):
                    nextContext.setTintColor(from: color)
                case .identify, .filter, .unknown:
                    break
                }
                
                let nested = traverseDisplayList(items: nestedList.items,
                                                 context: nextContext,
                                                 renderer: renderer,
                                                 viewAttributes: viewAttributes,
                                                 parentId: parentId,
                                                 originalView: originalView)
                collected.append(contentsOf: nested)
                
            case .unknown:
                continue
            }
        }
        
        return collected
    }
    
    // Consolidated content handling
    private static func buildContentThingy(item: SwiftUIDisplayList.DisplayListItem,
                                           content: SwiftUIDisplayList.Content,
                                           baseContext: SwiftUIContext,
                                           renderer: SwiftUIDisplayList.ViewRenderer,
                                           viewAttributes: SwiftUIViewAttributes,
                                           parentId: Int,
                                           originalView: UIView) -> (any SessionReplayViewThingy)? {
        
        // Use the hash-based cache to get a consistent ID for this content
        var contentId: Int?
        
        let frame = baseContext.convert(frame: item.frame)
        var viewName = "SwiftUIView"

        func makeDetails(widthOffset: CGFloat = 0) -> ViewDetails {
                    let adjustedFrame = CGRect(x: frame.origin.x,
                                               y: frame.origin.y,
                                               width: frame.size.width + widthOffset,
                                               height: frame.size.height)
                    
                    return ViewDetails(frame: adjustedFrame,
                                clip: viewAttributes.clip,
                                backgroundColor: UIColor(cgColor: viewAttributes.backgroundColor ?? UIColor.clear.cgColor),
                                alpha: viewAttributes.alpha,
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
            contentId = getContentId(for: content, identity: item.identity)
            viewName = "SwiftUIShapeView"
            var details = makeDetails()
            details.backgroundColor = .clear // Shapes should not have a bg color by default

            return SwiftUIShapeThingy(viewDetails: details,
                                     path: path,
                                     fillColor: fillColor,
                                     fillStyle: fillStyle)
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
            
            contentId = getContentId(for: content, identity: item.identity)
            viewName = "SwiftUITextView"
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
            contentId = getContentId(for: content, identity: item.identity)
            viewName = "SwiftUIColorView"
            var details = makeDetails()
            // Convert the SwiftUI color data to UIColor for the background
            details.backgroundColor = colorData.uiColor
            return UIViewThingy(viewDetails: details)
        case let SwiftUIDisplayList.Content.Value.image(swiftUIImage):
            // Extract UIImage from SwiftUIGraphicsImage
            var image: CGImage?
            switch swiftUIImage.contents {
            case .cgImage(let cgImage):
                image = cgImage
            case .unknown:
                break
            }
            
            contentId = getContentId(for: content, identity: item.identity)
            
            viewName = "SwiftUIImageView"
            var details = makeDetails()
            details.backgroundColor = .clear // Images should not have a bg color by default
            
            return UIImageViewThingy(viewDetails: details,
                                     cgImage: image,
                                     swiftUIImage: swiftUIImage,
                                     contentMode: .scaleToFill)
        case SwiftUIDisplayList.Content.Value.drawing(let erasedDrawing):
            contentId = getContentId(for: content, identity: item.identity)
            viewName = "SwiftUIDrawingView"
            var details = makeDetails()
            details.backgroundColor = .clear

            // Convert drawing to UIImage
            guard let image = erasedDrawing.makeSwiftUIImage(),
                  let cgImage = image.cgImage else {
                return nil
            }

            // Create SwiftUIGraphicsImage from the generated CGImage
            let swiftUIImage = SwiftUIGraphicsImage(
                contents: .cgImage(cgImage),
                scale: image.scale,
                maskClr: nil,
                orientation: .up
            )

            return UIImageViewThingy(viewDetails: details,
                                     cgImage: cgImage,
                                     swiftUIImage: swiftUIImage,
                                     contentMode: .scaleToFill)
        case SwiftUIDisplayList.Content.Value.platformView:
            contentId = getContentId(for: content, identity: item.identity)
            viewName = "SwiftUIPlatformView"
            var details = makeDetails()
            details.backgroundColor = .clear
            return UIViewThingy(viewDetails: details)
        case SwiftUIDisplayList.Content.Value.unknown:
            contentId = getContentId(for: content, identity: item.identity)
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
