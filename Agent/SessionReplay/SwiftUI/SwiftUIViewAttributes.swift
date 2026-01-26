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
struct SwiftUIViewAttributes: Equatable {

    // Core geometry
    internal(set) var frame: CGRect
    internal(set) var clip: CGRect

    // Visual appearance
    internal(set) var backgroundColor: CGColor?
    internal(set) var layerBorderColor: CGColor?
    internal(set) var layerBorderWidth: CGFloat
    internal(set) var layerCornerRadius: CGFloat
    internal(set) var alpha: CGFloat

    // Visibility & layout
    var isHidden: Bool
    var intrinsicContentSize: CGSize

    // masking support
    var maskApplicationText: Bool?
    var maskUserInputText: Bool?
    var maskAllImages: Bool?
    var maskAllUserTouches: Bool?
    
    var sessionReplayIdentifier: String?

}
