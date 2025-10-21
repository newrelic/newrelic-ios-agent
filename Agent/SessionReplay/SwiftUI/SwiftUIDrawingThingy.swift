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
        guard let rect = bounds else { return nil }
        
        let w = Int((rect.width + 1.5) * scale)
        let h = Int((rect.height + 1.5) * scale)
        
        guard (1...DrawingConstants.maxSize).contains(w),
              (1...DrawingConstants.maxSize).contains(h) else { return nil }
        
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        else {
            return nil
        }
        
        ctx.translateBy(x: 0, y: CGFloat(h) + origin.y)
        ctx.scaleBy(x: scale, y: -scale)
        render(ctx)
        
        guard let cg = ctx.makeImage() else { return nil }
        return UIImage(cgImage: cg, scale: scale, orientation: .up)
    }
}
