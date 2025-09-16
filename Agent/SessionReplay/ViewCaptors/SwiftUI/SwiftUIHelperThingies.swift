//
//  SwiftUIHelperThingies.swift
//  Agent
//
//  Created by Chris Dillard on 9/16/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit
@_implementationOnly import NewRelicPrivate

// Helper function to create SwiftUI TextField Thingy
@available(iOS 14.0, *)
func SwiftUITextFieldThingy(isSecure: Bool, viewDetails: ViewDetails) -> any SessionReplayViewThingy {
    return UITextFieldThingy(view: UITextField(), viewDetails: viewDetails)
}

// Helper function to create SwiftUI Button Thingy
@available(iOS 14.0, *)
func SwiftUIButtonThingy(title: String, viewDetails: ViewDetails) -> any SessionReplayViewThingy {
    let button = UIButton()
    button.setTitle(title, for: .normal)
    return UIViewThingy(view: button, viewDetails: viewDetails) // Could be UIButtonThingy if it exists
}
