//
//  SwiftUIContext.swift
//  Agent
//
//  Created by Chris Dillard on 10/1/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI

//@available(iOS 13.0, *)
struct SwiftUIContext {
    var frame: CGRect
    var clip: CGRect
    var tintColor: Color._ResFoundColor?
    
    // Internal convenience for current frame offset
    @inline(__always) private var _originOffset: CGPoint {
        CGPoint(x: frame.minX, y: frame.minY)
    }
    
    // Translate an arbitrary rect into this context\'s coordinate space.
    @inlinable
    func convert(frame rect: CGRect) -> CGRect {
        var translated = rect
        translated.origin.x += _originOffset.x
        translated.origin.y += _originOffset.y
        return translated
    }
    
    // Mutating variant updating our own frame by another rect\'s origin.
    @inlinable
    mutating func convert(to rect: CGRect) {
        frame.origin.x += rect.minX
        frame.origin.y += rect.minY
    }
}
