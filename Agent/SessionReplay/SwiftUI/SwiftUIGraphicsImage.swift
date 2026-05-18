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
                // Try to extract maskColor using reflection
                if let maskColorChild = xray.childIfPresent("maskColor") {
                    let maskDecoder = XrayDecoder(subject: maskColorChild)
                    if let baseChild = maskDecoder.childIfPresent(SwiftUIConstants.basePath) {
                        // iOS 26+ ResolvedHDR structure
                        let baseDecoder = XrayDecoder(subject: baseChild)
                        if let red: Float = try? baseDecoder.extract(SwiftUIConstants.linearRedPath),
                           let green: Float = try? baseDecoder.extract(SwiftUIConstants.linearGreenPath),
                           let blue: Float = try? baseDecoder.extract(SwiftUIConstants.linearBluePath),
                           let opacity: Float = try? baseDecoder.extract(SwiftUIConstants.opacityPath) {
                            return Color._ResFoundColor(linearRed: red, linearGreen: green, linearBlue: blue, opacity: opacity)
                        }
                    }
                }
                // Fallback to legacy type
                if let legacy = xray.childIfPresent(type: Color._ResHighDef.self, "maskColor") {
                    return legacy.base
                }
                return nil
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
