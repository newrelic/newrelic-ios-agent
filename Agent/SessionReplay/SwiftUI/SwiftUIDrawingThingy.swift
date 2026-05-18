//
//  SwiftUIDrawingThingy.swift
//  Agent
//
//  Created by Chris Dillard on 9/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import CoreGraphics
import Foundation
import UIKit

//@available(iOS 13.0, tvOS 13.0, *)
internal struct SwiftUIDrawingThingy: SwiftUIImageRepresentable {
    
    private let contents: NSObject
    private let origin: CGPoint
    private let scale: CGFloat
    
    fileprivate var bounds: CGRect? {
        contents.value(forKey: DrawingConstants.boundingRectKey) as? CGRect
    }
    
    init?(contents: NSObject, origin: CGPoint, scale: CGFloat = UIScreen.main.scale) {
        guard let klass = DrawingConstants.targetClass, type(of: contents).isSubclass(of: klass),
            contents.responds(to: DrawingConstants.renderSelector) else {
            return nil
        }
        self.contents = contents
        self.origin = origin
        self.scale = scale
    }
    
    fileprivate func render(_ ctx: CGContext) {
        contents.perform(
            DrawingConstants.renderSelector,
            with: ctx,
            with: [DrawingConstants.rasterScaleKey: scale]
        )
    }
    
    static func == (lhs: SwiftUIDrawingThingy,
                    rhs: SwiftUIDrawingThingy) -> Bool {
        lhs.contents.isEqual(rhs.contents) && lhs.origin == rhs.origin
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(contents.hash)
        hasher.combine(origin.x)
        hasher.combine(origin.y)
        hasher.combine(scale)
    }
    
    func makeSwiftUIImage() -> UIImage? {
        guard let rect = bounds, rect.width > 0, rect.height > 0 else {
            return nil
        }

        // Calculate the full extent by unioning the bounds rect with the origin point
        // Cache min calculations to avoid redundant comparisons
        let minX = min(rect.origin.x, origin.x)
        let minY = min(rect.origin.y, origin.y)

        let fullRect = CGRect(
            x: minX,
            y: minY,
            width: max(rect.maxX, origin.x) - minX,
            height: max(rect.maxY, origin.y) - minY
        )

        // Calculate dimensions and apply scaling if needed to fit within maxSize
        var adjustedScale = scale
        var w = Int((fullRect.width + 1.5) * scale)
        var h = Int((fullRect.height + 1.5) * scale)

        if w > DrawingConstants.maxSize || h > DrawingConstants.maxSize {
            let scaleFactor = min(
                CGFloat(DrawingConstants.maxSize) / CGFloat(w),
                CGFloat(DrawingConstants.maxSize) / CGFloat(h)
            )
            adjustedScale *= scaleFactor
            w = Int((fullRect.width + 1.5) * adjustedScale)
            h = Int((fullRect.height + 1.5) * adjustedScale)
        }

        guard w >= 1, h >= 1,
              let ctx = CGContext(
                data: nil,
                width: w,
                height: h,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        // Apply translation to position content and flip Y axis for correct orientation
        ctx.translateBy(x: -fullRect.origin.x * adjustedScale,
                       y: CGFloat(h) + fullRect.origin.y * adjustedScale)
        ctx.scaleBy(x: adjustedScale, y: -adjustedScale)
        render(ctx)

        return ctx.makeImage().map { UIImage(cgImage: $0, scale: adjustedScale, orientation: .up) }
    }
}
