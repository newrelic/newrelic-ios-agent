//
//  SwiftUIViewAttributes.swift
//  Agent
//
//  Created by Chris Dillard on 9/30/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import CoreGraphics
import UIKit

// Swift
public struct SwiftUIViewAttributes: Equatable {

    // Core geometry
    public internal(set) var frame: CGRect
    public internal(set) var clip: CGRect

    // Visual appearance
    public internal(set) var backgroundColor: CGColor?
    public internal(set) var layerBorderColor: CGColor?
    public internal(set) var layerBorderWidth: CGFloat
    public internal(set) var layerCornerRadius: CGFloat
    public internal(set) var alpha: CGFloat

    // Visibility & layout
    var isHidden: Bool
    var intrinsicContentSize: CGSize

    // Future masking support
    var hide: Bool?   // TODO: HANDLE MASKING
}
