//
//  CALayer+EffectiveCornerRadius.swift
//  Agent
//
//  Copyright © 2025 New Relic. All rights reserved.
//

import QuartzCore
import SwiftUI

extension CALayer {
    /// Returns the corner radius that should be recorded in session replay.
    ///
    /// SwiftUI emits a two-layer structure when `.cornerRadius()` and `.shadow()` are
    /// combined on the same view:
    ///   - outer CALayer  — cornerRadius 0, masksToBounds false  (carries the shadow)
    ///   - inner CALayer  — cornerRadius N, masksToBounds true   (carries the clip)
    ///
    /// Reading `layer.cornerRadius` directly on the outer layer always returns 0.
    /// This property falls through to the first immediate sublayer that clips its
    /// contents, which is where the authored radius lives.
    var effectiveCornerRadius: CGFloat {
        if cornerRadius > 0 { return cornerRadius }
        return sublayers?.first(where: { $0.masksToBounds && $0.cornerRadius > 0 })?.cornerRadius ?? 0
    }

    /// Returns the masked corners that correspond to `effectiveCornerRadius`.
    /// Follows the same fallthrough logic so the two values always refer to
    /// the same layer.
    var effectiveMaskedCorners: CACornerMask {
        if cornerRadius > 0 { return maskedCorners }
        return sublayers?.first(where: { $0.masksToBounds && $0.cornerRadius > 0 })?.maskedCorners
            ?? [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    }
}

@available(iOS 13.0, *)
extension SwiftUI.Path {
    /// Returns the corner radius if this path appears to be a rounded rectangle.
    ///
    /// SwiftUI `.cornerRadius(r)` and `.clipShape(RoundedRectangle(cornerRadius: r))`
    /// both generate a rounded-rect CGPath whose first move lands at
    /// `(rect.minX + r, rect.minY)`.  We recover `r` from that relationship.
    ///
    /// Returns `nil` for non-rounded paths (plain rects, circles whose moveTo
    /// doesn't match the pattern, custom shapes, etc.) so callers can fall back
    /// to whatever radius they already have.
    var approximateCornerRadius: CGFloat? {
        let bounds = boundingRect
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        var elements: [Path.Element] = []
        forEach { elements.append($0) }
        let preview = elements.prefix(4).map { e -> String in
            switch e {
            case .move(let p): return "M(\(String(format:"%.2f",p.x)),\(String(format:"%.2f",p.y)))"
            case .line(let p): return "L(\(String(format:"%.2f",p.x)),\(String(format:"%.2f",p.y)))"
            case .curve(let p,_,_): return "C(\(String(format:"%.2f",p.x)),\(String(format:"%.2f",p.y)))"
            case .quadCurve(let p,_): return "Q(\(String(format:"%.2f",p.x)),\(String(format:"%.2f",p.y)))"
            case .closeSubpath: return "Z"
            }
        }.joined(separator:" ")
        //NRLOG_DEBUG("NR_CR_PATH bounds=\(String(format:"(%.1f,%.1f,%.1f,%.1f)",bounds.minX,bounds.minY,bounds.width,bounds.height)) elements=[\(preview)]")

        var firstMovePoint: CGPoint? = nil
        forEach { element in
            guard firstMovePoint == nil else { return }
            if case .move(let to) = element { firstMovePoint = to }
        }

        guard let p = firstMovePoint else { return nil }
        let r = p.x - bounds.minX
        // Sanity-check: radius must be positive and at most half the shorter side.
        guard r > 0, r <= min(bounds.width, bounds.height) / 2 + 0.5 else { return nil }
        return r
    }
}
