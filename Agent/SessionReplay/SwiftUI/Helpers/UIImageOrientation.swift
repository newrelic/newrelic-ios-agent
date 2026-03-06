//
//  UIImageOrientation.swift
//  Agent
//
//  Created by Chris Dillard on 9/29/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import UIKit
import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
internal extension UIImage.Orientation {
    // The conversion from UIImage UIKit Orientation Style to SwiftUI SwiftUIImage Orientation Style
    init(_ orientation: SwiftUI.Image.Orientation) {
        switch orientation {
        case SwiftUI.Image.Orientation.up: self = UIImage.Orientation.up
        case SwiftUI.Image.Orientation.down: self = UIImage.Orientation.down
        case SwiftUI.Image.Orientation.left: self = UIImage.Orientation.left
        case SwiftUI.Image.Orientation.right: self = UIImage.Orientation.right
        case SwiftUI.Image.Orientation.upMirrored: self = UIImage.Orientation.upMirrored
        case SwiftUI.Image.Orientation.downMirrored: self = UIImage.Orientation.downMirrored
        case SwiftUI.Image.Orientation.leftMirrored: self = UIImage.Orientation.leftMirrored
        case SwiftUI.Image.Orientation.rightMirrored: self = UIImage.Orientation.rightMirrored
        }
    }
}
