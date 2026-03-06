//
//  SwiftUIGraphicsFilter.swift
//  Agent
//
//  Created by Chris Dillard on 9/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
internal enum SwiftUIGraphicsFilter {
    case colorMultiply(Color._ResFoundColor)
    case unknown
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIGraphicsFilter: XrayConvertible {
    init(xray: XrayDecoder) throws {
        // Capture possible first child once
        let candidate = xray.childIfPresent(0)
        
        // Match enum case name explicitly
        if case RunTimeTypeInspector.DisplayStyle.enum(SwiftUIConstants.colorMultiply.rawValue) = xray.displayStyle {
            if #available(iOS 26, tvOS 26, *) {
                // Try to extract color using reflection
                if let candidateObj = candidate {
                    let candidateDecoder = XrayDecoder(subject: candidateObj)
                    if let baseChild = candidateDecoder.childIfPresent(SwiftUIConstants.basePath) {
                        // iOS 26+ path: extract from ResolvedHDR structure
                        let baseDecoder = XrayDecoder(subject: baseChild)
                        if let red: Float = try? baseDecoder.extract(SwiftUIConstants.linearRedPath),
                           let green: Float = try? baseDecoder.extract(SwiftUIConstants.linearGreenPath),
                           let blue: Float = try? baseDecoder.extract(SwiftUIConstants.linearBluePath),
                           let opacity: Float = try? baseDecoder.extract(SwiftUIConstants.opacityPath) {
                            let color = Color._ResFoundColor(linearRed: red, linearGreen: green, linearBlue: blue, opacity: opacity)
                            self = SwiftUIGraphicsFilter.colorMultiply(color)
                            return
                        }
                    }
                }
                // Fallback to legacy type
                let resolution = try xray.xray(type: Color._ResHighDef.self, candidate).base
                self = SwiftUIGraphicsFilter.colorMultiply(resolution)
            }
            else {
                self = try SwiftUIGraphicsFilter.colorMultiply(try xray.xray(candidate))
            }
            return
        }
        
        // Fallback
        self = SwiftUIGraphicsFilter.unknown
    }
}
