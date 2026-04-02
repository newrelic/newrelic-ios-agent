//
//  CALayer+EffectiveCornerRadius.swift
//  Agent
//
//  Copyright © 2025 New Relic. All rights reserved.
//

import QuartzCore

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
}
