//
//  SwiftUIViewThingySupport.swift
//  Agent
//
//  Created by Chris Dillard on 9/26/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import UIKit

internal struct SwiftUIBridgeUIImageResource {
    let image: CGImage
    let tintColor: UIColor?
    
    internal init(image: CGImage, tintColor: UIColor?) {
        self.image = image
        self.tintColor = tintColor
    }
}

extension SwiftUIBridgeUIImageResource: SwiftUIThingyData {
    var mimeType: String { return "image/png" }
    
    func determineIdentifier() -> String {
        // TODO: Fix
        tintColor.map { String(image.hashValue) + String($0.toHexString(includingAlpha: true)) ?? String(image.hashValue) } ?? ""
    }
    
    func determineData() -> Data {
        // TODO: Fix tintColor removal
        return image.optimizedPngData() ?? Data()
    }
}
public protocol SwiftUIThingyData {
    var mimeType: String { get }
    func determineIdentifier() -> String
    func determineData() -> Data
}
