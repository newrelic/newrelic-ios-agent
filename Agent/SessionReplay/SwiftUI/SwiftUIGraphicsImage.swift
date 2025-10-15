//
//  SwiftUIGraphicsImage.swift
//  Agent
//
//  Created by Chris Dillard on 9/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import CoreGraphics
import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
internal struct SwiftUIGraphicsImage {
    let contents: Contents
    let scale: CGFloat
    let maskClr: SwiftUI.Color._ResFoundColor?
    let orientation: SwiftUI.Image.Orientation
    
    enum Contents {
        case unknown
        case cgImage(CGImage)
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIGraphicsImage: XrayConvertible {
    init(xray: XrayDecoder) throws {
        @inline(__always)
        func grab<T>(_ key: RunTimeTypeInspector.Path, as type: T.Type = T.self) throws -> T {
            try xray.extract(key)
        }

        // Core properties.
        scale       = try grab("scale")
        orientation = try grab("orientation")
        
        // Handle optional contents - if nil, default to unknown
        if let contentsXray = xray.childIfPresent("contents") {
            contents = try Contents(xray: XrayDecoder(subject: contentsXray))
        } else {
            contents = .unknown
        }

        // Defer mask resolution into a closure for clearer branching.
        maskClr = {
            if #available(iOS 26, tvOS 26, *) {
                return xray
                    .childIfPresent(type: Color._ResHighDef.self, "maskColor")?
                    .base
            } else {
                return xray.childIfPresent("maskColor")
            }
        }()
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIGraphicsImage.Contents: XrayConvertible {
    init(xray: XrayDecoder) throws {
        switch (xray.displayStyle, xray.childIfPresent(0)) {
        case let (.enum("cgImage"), cgImage as CGImage):
            self = .cgImage(cgImage)
        default:
            self = .unknown
        }
    }
}
