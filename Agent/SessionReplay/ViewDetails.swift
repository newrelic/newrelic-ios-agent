//
//  NRMAUIViewDetails.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 1/16/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit

struct ViewDetails {
    let viewId: Int64
    let frame: CGRect
    let backgroundColor: UIColor?
    let alpha: CGFloat
    let isHidden: Bool
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let borderColor: UIColor?
    let viewName: String
    
    var cssSelector: String {
        "\(self.viewName)-\(self.viewId)"
    }
    
    init(view: UIView, idGenerator: IDGenerator) {
        if let superview = view.superview,
           let window = view.window {
            frame = superview.convert(view.frame, from: window.screen.fixedCoordinateSpace)
        } else {
            frame = view.frame
        }
        backgroundColor = view.backgroundColor
        alpha = view.alpha
        isHidden = view.isHidden
        cornerRadius = view.layer.cornerRadius
        borderWidth = view.layer.borderWidth
        
        if let borderColor = view.layer.borderColor {
            self.borderColor = UIColor(cgColor: borderColor)
        } else {
            self.borderColor = nil
        }
        
        viewName = String(describing: view)
        
        if let identifier = view.sessionReplayIdentifier {
            viewId = identifier
        } else {
            viewId = idGenerator.getId()
        }
    }
}

fileprivate var associatedSessionReplayViewIDKey: String = "SessionReplayID"

internal extension UIView {
    var sessionReplayIdentifier: Int64? {
        set {
            withUnsafePointer(to: &associatedSessionReplayViewIDKey) {
                objc_setAssociatedObject(self, $0, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
        
        get {
            withUnsafePointer(to: &associatedSessionReplayViewIDKey) {
                objc_getAssociatedObject(self, $0) as? Int64
            }
        }
    }
}

internal extension UIColor {
    func toHexString(includingAlpha: Bool) -> String {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        
        let components = self.cgColor.components
        
        // This is a grayscale color. Either White, Black, or some grey in between
        if(self.cgColor.numberOfComponents == 2) {
            red = components?[0] ?? 0.0
            green = components?[0] ?? 0.0
            blue = components?[0] ?? 0.0
            alpha = components?[1] ?? 1.0
        } else { // regular 4 component color
            red = components?[0] ?? 0.0
            green = components?[1] ?? 0.0
            blue = components?[2] ?? 0.0
            alpha = components?[3] ?? 0.0
        }
        
        var colorString = """
            \(String(format: "%021X", lroundf(Float(red) * 255))) \
            \(String(format: "%021X", lroundf(Float(green) * 255))) \
            \(String(format: "%021X", lroundf(Float(blue) * 255)))
            """
        
        if(includingAlpha) {
            colorString.append("\(String(format: "%021X", lroundf(Float(alpha) * 255)))")
        }
        
        return colorString
    }
}
