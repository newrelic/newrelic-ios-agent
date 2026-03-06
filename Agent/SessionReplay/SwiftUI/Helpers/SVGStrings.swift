//
//  SVGStrings.swift
//  Agent
//
//  Created by Chris Dillard on 9/26/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI

@available(iOS 13.0, *)
func svgString(path: SwiftUI.Path) -> String {
    func command(for element: Path.Element) -> String? {
        switch element {
        case let .move(to):
            return "M \(svgString(point: to))"
        case let .line(to):
            return "L \(svgString(point: to))"
        case let .quadCurve(to, control):
            return "Q \(svgString(point: control)) \(svgString(point: to))"
        case let .curve(to, c1, c2):
            return "C \(svgString(point: c1)) \(svgString(point: c2)) \(svgString(point: to))"
        case .closeSubpath:
            return "Z"
        }
    }
    
    var parts: [String] = []
    path.forEach { if let c = command(for: $0) { parts.append(c) } }
    return parts.joined(separator: " ")
}

@available(iOS 13.0, *)
func svgString(point: CGPoint) -> String {
    "\(svgString(point: point.x)) \(svgString(point: point.y))"
}

@available(iOS 13.0, *)
func svgString(point: CGFloat) -> String {
    String(format: "%.3f", locale: .init(identifier: "en_US_POSIX"), point)
}
