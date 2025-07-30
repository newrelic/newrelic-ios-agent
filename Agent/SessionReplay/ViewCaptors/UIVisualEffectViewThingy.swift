//
//  UIVisualEffectViewThingy.swift
//  Agent
//
//  Created by Mike Bruin on 7/3/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit

class UIVisualEffectViewThingy: SessionReplayViewThingy {
    var isMasked: Bool
    
    var subviews = [any SessionReplayViewThingy]()
    
    var shouldRecordSubviews: Bool {
        true
    }
    
    var viewDetails: ViewDetails
    private let blurIntensity: CGFloat
    
    init(view: UIVisualEffectView, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        self.isMasked = viewDetails.isMasked ?? false
        
        // Determine blur style and intensity based on the effect
        var intensity: CGFloat = 10.0
        var backgroundColor: UIColor?
        
        if let blurEffect = view.effect as? UIBlurEffect {
            // Use the description of the blur effect to determine the style
            let blurDescription = String(describing: blurEffect)
            
            if blurDescription.localizedCaseInsensitiveContains("Dark") {
                intensity = 15.0
                backgroundColor = UIColor(red: 8.0/255.0, green: 8.0/255.0, blue: 8.0/255.0, alpha: 0.85)
            } else if blurDescription.localizedCaseInsensitiveContains("Light") {
                intensity = 10.0
                backgroundColor = UIColor(red: 248.0/255.0, green: 248.0/255.0, blue: 248.0/255.0, alpha: 0.85)
            } else if blurDescription.localizedCaseInsensitiveContains("ExtraLight") {
                intensity = 5.0
                backgroundColor = UIColor(red: 252.0/255.0, green: 252.0/255.0, blue: 252.0/255.0, alpha: 0.6)
            } else if blurDescription.localizedCaseInsensitiveContains("Prominent") {
                intensity = 20.0
                backgroundColor = UIColor(red: 240.0/255.0, green: 240.0/255.0, blue: 240.0/255.0, alpha: 0.9)
            } else if blurDescription.localizedCaseInsensitiveContains("Regular") {
                intensity = 10.0
                backgroundColor = UIColor(red: 245.0/255.0, green: 245.0/255.0, blue: 245.0/255.0, alpha: 0.8)
            } else if blurDescription.localizedCaseInsensitiveContains("System") {
                intensity = 12.0
                backgroundColor = UIColor(red: 245.0/255.0, green: 245.0/255.0, blue: 245.0/255.0, alpha: 0.8)
            }
        } else if view.effect is UIVibrancyEffect {
            // Handle vibrancy effect
            intensity = 8.0
            backgroundColor = UIColor(white: 1.0, alpha: 0.3)
        }
        
        self.blurIntensity = intensity
        
        if backgroundColor == nil {
            // Override with system appearance if available
            if #available(iOS 12.0, *) {
                if view.traitCollection.userInterfaceStyle == .dark {
                    self.viewDetails.backgroundColor = UIColor(red: 8.0/255.0, green: 8.0/255.0, blue: 8.0/255.0, alpha: 0.85)
                } else {
                    self.viewDetails.backgroundColor = UIColor(red: 248.0/255.0, green: 248.0/255.0, blue: 248.0/255.0, alpha: 0.85)
                }
            }
        } else {
            self.viewDetails.backgroundColor = backgroundColor
        }
    }
    
    func cssDescription() -> String {
        return """
        #\(viewDetails.cssSelector) { \
        \(generateBaseCSSStyle()) \
        -webkit-backdrop-filter: blur(\(blurIntensity)px); \
        box-shadow: 0px 0.5px 0px rgba(0, 0, 0, 0.3);\
        }
        """
    }
    
    func generateRRWebNode() -> ElementNodeData {
        return ElementNodeData(id: viewDetails.viewId,
                               tagName: .div,
                               attributes: ["id":viewDetails.cssSelector],
                               childNodes: [])
    }
    
    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? UIVisualEffectViewThingy else {
            return []
        }
        
        var attributes = generateBaseDifferences(from: typedOther)
        if self.blurIntensity != typedOther.blurIntensity {
            // Update the style attribute with the new blur intensity
            attributes["style"] = """
            \(generateBaseCSSStyle()) \
            -webkit-backdrop-filter: blur(\(blurIntensity)px); \
            box-shadow: 0px 0.5px 0px rgba(0, 0, 0, 0.3);
            """
        }
        
        return [RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: attributes)]
    }
}

extension UIVisualEffectViewThingy: Equatable {
    static func == (lhs: UIVisualEffectViewThingy, rhs: UIVisualEffectViewThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails &&
                lhs.blurIntensity == rhs.blurIntensity
    }
}

extension UIVisualEffectViewThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
        hasher.combine(blurIntensity)
    }
}
