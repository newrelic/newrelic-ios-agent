//
//  VCExtractor.swift
//  Agent
//
//  Created by Chris Dillard on 10/1/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import UIKit

// Extract VC from UIViewController
extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while let responder = parentResponder {
            if let viewController = responder as? UIViewController {
                return viewController
            }
            parentResponder = responder.next
        }
        return nil
    }
}

// Extract VC from UIView
func extractVC(from hostingSubview: UIView) -> UIViewController?{
    var responder: UIResponder? = hostingSubview
    while let current = responder {
        if let hosting = current as? UIViewController {
            return hosting
        }
        responder = current.next
    }
    return nil
}
