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
            //NRLOG_DEBUG("Error extracting SwiftUI ViewThingys: \(error)")
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
                    nextContext.tintColor = color
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
        let viewName = "SwiftUIView"

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
                        borderColor: UIColor(cgColor:viewAttributes.layerBorderColor ?? UIColor.clear.cgColor),//Int(content.seed.value),
                        viewId: contentId,
                        view: originalView,
                        maskApplicationText: viewAttributes.maskApplicationText,
                        maskUserInputText: viewAttributes.maskUserInputText,
                        maskAllImages: viewAttributes.maskAllImages,
                        maskAllUserTouches: viewAttributes.maskAllUserTouches,
                        sessionReplayIdentifier: viewAttributes.sessionReplayIdentifier) // viewAttributes.maskUserInput
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
            
            contentId = getContentId(for: content, identity: item.identity)
            // Extract masking state from the view
            let details = makeDetails()
            
            var outputText = ""
            if details.isMasked ?? false {
                outputText = String(repeating: "*", count: storage.string.count)
            }
            else {
                outputText = storage.string
            }
            
            return UILabelThingy(viewDetails: details,
                                 text: outputText,
                                 textAlignment: alignment.stringValue(),
                                 fontSize: font?.pointSize ?? 10,
                                 fontName: font?.fontName ?? "SFUI-Bold",
                                 fontFamily: font?.familyName ?? "AppleSystemUIFont",
                                 textColor: foregroundColor)
            
        case SwiftUIDisplayList.Content.Value.color:
            return nil // TODO: Colors
        case let SwiftUIDisplayList.Content.Value.image(swiftUIImage):
            // Extract UIImage from SwiftUIGraphicsImage
            var image: CGImage?
            switch swiftUIImage.contents {
            case .cgImage(let cgImage):
                image = cgImage
            case .unknown:
                break
            }
            
            if let id = image?.swiftUISessionReplayIdentifier {
                contentId = id
            } else {
                contentId = IDGenerator.shared.getId()
                image?.swiftUISessionReplayIdentifier = contentId
            }
            
            var details = makeDetails()
            if details.isMasked == nil {
                details.isMasked = viewAttributes.maskAllImages
            }
            details.backgroundColor = .clear // Images should not have a bg color by default
            
            return UIImageViewThingy(viewDetails: details,
                                     cgImage: image,
                                     swiftUIImage: swiftUIImage,
                                     contentMode: .scaleToFill)
        case SwiftUIDisplayList.Content.Value.drawing:
            return nil // TODO: Drawings
        case SwiftUIDisplayList.Content.Value.platformView:
            contentId = getContentId(for: content, identity: item.identity)
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

fileprivate var associatedSwiftUISessionReplayIdentifierKey: String = "SessionReplayIdentifier"

extension CGImage {
    var swiftUISessionReplayIdentifier: Int? {
        set {
            withUnsafePointer(to: &associatedSwiftUISessionReplayIdentifierKey) {
                objc_setAssociatedObject(self, $0, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }

        get {
            withUnsafePointer(to: &associatedSwiftUISessionReplayIdentifierKey) {
                objc_getAssociatedObject(self, $0) as? Int
            }
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
