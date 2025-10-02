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
                // High definition path
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
