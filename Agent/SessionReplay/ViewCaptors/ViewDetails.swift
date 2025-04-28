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
    let viewId: Int
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
    
    var isVisible: Bool {
        isHidden &&
        alpha > 0 &&
        frame != .zero
    }
    
    var isClear: Bool {
        alpha <= 1
    }
    
    init(view: UIView) {
        if let superview = view.superview,
           let window = view.window {
            frame = superview.convert(view.frame, to: window.screen.fixedCoordinateSpace)
        } else {
            frame = view.frame
        }
        backgroundColor = view.backgroundColor
        alpha = view.alpha
        isHidden = view.isHidden
        cornerRadius = view.layer.cornerRadius
        borderWidth = view.layer.borderWidth
        
        // Checking if we have a border, because asking for the layer's
        // border color will always give us something
        if view.layer.borderWidth > 0, let borderColor = view.layer.borderColor {
            self.borderColor = UIColor(cgColor: borderColor)
        } else {
            self.borderColor = nil
        }
        
        viewName = String(describing: type(of: view))
        
        if let identifier = view.sessionReplayIdentifier {
            viewId = identifier
        } else {
            viewId = IDGenerator.shared.getId()
            view.sessionReplayIdentifier = viewId
        }
    }
}

extension ViewDetails: Hashable {
    
}

fileprivate var associatedSessionReplayViewIDKey: String = "SessionReplayID"

internal extension UIView {
    var sessionReplayIdentifier: Int? {
        set {
            withUnsafePointer(to: &associatedSessionReplayViewIDKey) {
                objc_setAssociatedObject(self, $0, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
        
        get {
            withUnsafePointer(to: &associatedSessionReplayViewIDKey) {
                objc_getAssociatedObject(self, $0) as? Int
            }
        }
    }
}


