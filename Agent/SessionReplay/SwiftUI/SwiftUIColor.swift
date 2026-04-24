//
//  SwiftUIColor.swift
//  Agent
//
//  Created by Chris Dillard on 9/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import SwiftUI

/// Convert a linear-light component to sRGB gamma-encoded.
/// SwiftUI's internal color types store values in linear space, but
/// UIColor(red:green:blue:alpha:) expects sRGB gamma-encoded values.
@inline(__always)
private func linearToSRGB(_ c: Float) -> Float {
    if c <= 0.0031308 {
        return c * 12.92
    } else {
        return 1.055 * powf(c, 1.0 / 2.4) - 0.055
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUI.Color {
    // Pre-iOS 26 internal color types
    struct _ResFoundColor: Hashable {
        let linearRed: Float
        let linearGreen: Float
        let linearBlue: Float
        let opacity: Float

        var uiColor: UIColor {
            UIColor(red: CGFloat(linearToSRGB(linearRed)),
                    green: CGFloat(linearToSRGB(linearGreen)),
                    blue: CGFloat(linearToSRGB(linearBlue)),
                    alpha: CGFloat(opacity))
        }
    }
    
    struct _ResHighDef {
        let base: _ResFoundColor
        let _headroom: Float
    }
}

@available(iOS 13.0, tvOS 13.0, *)
internal struct ColorView {
    // Store the base color components directly to avoid version-specific types
    let linearRed: Float
    let linearGreen: Float
    let linearBlue: Float
    let opacity: Float
    let headroom: Float

    var uiColor: UIColor {
        UIColor(red: CGFloat(linearToSRGB(linearRed)),
                green: CGFloat(linearToSRGB(linearGreen)),
                blue: CGFloat(linearToSRGB(linearBlue)),
                alpha: CGFloat(opacity))
    }

    // Direct component initializer
    init(linearRed: Float, linearGreen: Float, linearBlue: Float, opacity: Float, headroom: Float) {
        self.linearRed = linearRed
        self.linearGreen = linearGreen
        self.linearBlue = linearBlue
        self.opacity = opacity
        self.headroom = headroom
    }

    // Convenience initializers for version compatibility
    init(from highDef: SwiftUI.Color._ResHighDef) {
        self.init(linearRed: highDef.base.linearRed,
                  linearGreen: highDef.base.linearGreen,
                  linearBlue: highDef.base.linearBlue,
                  opacity: highDef.base.opacity,
                  headroom: highDef._headroom)
    }

}

@available(iOS 13.0, tvOS 13.0, *)
internal struct ResolvedColor: Hashable {
    let linearRed: Float?
    let linearGreen: Float?
    let linearBlue: Float?
    let opacity: Float?

    var uiColor: UIColor? {
        guard let r = linearRed, let g = linearGreen, let b = linearBlue, let a = opacity else {
            return nil
        }
        return UIColor(red: CGFloat(linearToSRGB(r)),
                       green: CGFloat(linearToSRGB(g)),
                       blue: CGFloat(linearToSRGB(b)),
                       alpha: CGFloat(a))
    }

    // Direct component initializer
    init(linearRed: Float?, linearGreen: Float?, linearBlue: Float?, opacity: Float?) {
        self.linearRed = linearRed
        self.linearGreen = linearGreen
        self.linearBlue = linearBlue
        self.opacity = opacity
    }

    init(paint: SwiftUI.Color._ResFoundColor?) {
        self.init(linearRed: paint?.linearRed,
                  linearGreen: paint?.linearGreen,
                  linearBlue: paint?.linearBlue,
                  opacity: paint?.opacity)
    }
}

@available(iOS 13.0, tvOS 13.0, *)
private extension XrayDecoder {
    func get<T>(_ key: RunTimeTypeInspector.Path, _ r: XrayDecoder) throws -> T { try r.extract(key) }
    func getIfPresent<T>(_ key: RunTimeTypeInspector.Path, _ r: XrayDecoder) -> T? { r.rawChildIfExists(key) }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUI.Color._ResFoundColor: XrayConvertible {
    init(xray r: XrayDecoder) throws {
        (linearRed, linearGreen, linearBlue, opacity) = try (
            r.get(SwiftUIConstants.linearRedPath,r),
            r.get(SwiftUIConstants.linearGreenPath,r),
            r.get(SwiftUIConstants.linearBluePath,r),
            r.get(SwiftUIConstants.opacityPath,r)
        )
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUI.Color._ResHighDef: XrayConvertible {
    init(xray r: XrayDecoder) throws {
        (base, _headroom) =
        try (r.get(SwiftUIConstants.basePath,r), r.get(SwiftUIConstants.headroomPath,r))
    }
}


@available(iOS 13.0, tvOS 13.0, *)
extension ColorView: XrayConvertible {
    init(xray r: XrayDecoder) throws {
        // Try to extract the color structure using reflection
        // In iOS 26+, SwiftUI uses ResolvedHDR internally, but we access it via reflection

        // First get the "color" child from ColorView
        guard let colorChild = r.childIfPresent(SwiftUIConstants.colorPath) else {
            throw XRayDecoderError.notFound(XRayDecoderError.XrayDecoderContext(
                typeOfSubject: r.runTimeTypeInspector.typeOfSubject,
                pathsXRAY: [SwiftUIConstants.colorPath]))
        }

        let colorDecoder = XrayDecoder(subject: colorChild)

        // Try to get base color and headroom from the color structure
        if let baseChild = colorDecoder.childIfPresent(SwiftUIConstants.basePath) {
            // Extract color components from base (iOS 26+ ResolvedHDR structure)
            let baseDecoder = XrayDecoder(subject: baseChild)
            let red: Float = try baseDecoder.extract(SwiftUIConstants.linearRedPath)
            let green: Float = try baseDecoder.extract(SwiftUIConstants.linearGreenPath)
            let blue: Float = try baseDecoder.extract(SwiftUIConstants.linearBluePath)
            let alpha: Float = try baseDecoder.extract(SwiftUIConstants.opacityPath)
            let hdr: Float = try colorDecoder.extract(SwiftUIConstants.headroomPath)

            self.init(linearRed: red, linearGreen: green, linearBlue: blue, opacity: alpha, headroom: hdr)
        } else {
            // Fallback: try legacy type path
            let legacyColor: SwiftUI.Color._ResHighDef = try r.get(SwiftUIConstants.colorPath, r)
            self.init(from: legacyColor)
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension ResolvedColor: XrayConvertible {
    init(xray r: XrayDecoder) throws {
        if #available(iOS 26, tvOS 26, *) {
            // Try to extract paint using reflection
            if let paintChild = r.childIfPresent(SwiftUIConstants.paintPath) {
                let paintDecoder = XrayDecoder(subject: paintChild)

                // iOS 26+: Color structure is paint -> color (ResolvedHDR) -> base (Resolved) -> linearRed/linearGreen/linearBlue/opacity
                if let colorChild = paintDecoder.childIfPresent(SwiftUIConstants.colorPath) {
                    let colorDecoder = XrayDecoder(subject: colorChild)

                    // Extract from base child (Resolved)
                    if let baseChild = colorDecoder.childIfPresent(SwiftUIConstants.basePath) {
                        let baseDecoder = XrayDecoder(subject: baseChild)
                        let red: Float? = try? baseDecoder.extract(SwiftUIConstants.linearRedPath)
                        let green: Float? = try? baseDecoder.extract(SwiftUIConstants.linearGreenPath)
                        let blue: Float? = try? baseDecoder.extract(SwiftUIConstants.linearBluePath)
                        let alpha: Float? = try? baseDecoder.extract(SwiftUIConstants.opacityPath)

                        self.init(linearRed: red, linearGreen: green, linearBlue: blue, opacity: alpha)
                    } else {
                        // Fallback: try extracting directly from colorDecoder
                        let red: Float? = try? colorDecoder.extract(SwiftUIConstants.linearRedPath)
                        let green: Float? = try? colorDecoder.extract(SwiftUIConstants.linearGreenPath)
                        let blue: Float? = try? colorDecoder.extract(SwiftUIConstants.linearBluePath)
                        let alpha: Float? = try? colorDecoder.extract(SwiftUIConstants.opacityPath)

                        self.init(linearRed: red, linearGreen: green, linearBlue: blue, opacity: alpha)
                    }
                } else {
                    // Fallback: try to extract directly from paintDecoder
                    let red: Float? = try? paintDecoder.extract(SwiftUIConstants.linearRedPath)
                    let green: Float? = try? paintDecoder.extract(SwiftUIConstants.linearGreenPath)
                    let blue: Float? = try? paintDecoder.extract(SwiftUIConstants.linearBluePath)
                    let alpha: Float? = try? paintDecoder.extract(SwiftUIConstants.opacityPath)

                    self.init(linearRed: red, linearGreen: green, linearBlue: blue, opacity: alpha)
                }
            } else if let colorView = r.childIfPresent(type: ColorView.self, SwiftUIConstants.paintPath) {
                // Try ColorView approach
                self.init(linearRed: colorView.linearRed, linearGreen: colorView.linearGreen,
                          linearBlue: colorView.linearBlue, opacity: colorView.opacity)
            } else {
                self.init(linearRed: nil, linearGreen: nil, linearBlue: nil, opacity: nil)
            }
        } else {
            // Pre-iOS 26 (including iOS 18): try multiple extraction paths

            // First try: extract legacy _ResFoundColor directly
            if let legacyPaint: SwiftUI.Color._ResFoundColor = r.getIfPresent(SwiftUIConstants.paintPath, r) {
                self.init(paint: legacyPaint)
                return
            }

            // Second try: extract from paint child with color path (iOS 18 structure)
            if let paintChild = r.childIfPresent(SwiftUIConstants.paintPath) {
                let paintDecoder = XrayDecoder(subject: paintChild)

                // Try to extract color components directly from paint
                if let red: Float = try? paintDecoder.extract(SwiftUIConstants.linearRedPath),
                   let green: Float = try? paintDecoder.extract(SwiftUIConstants.linearGreenPath),
                   let blue: Float = try? paintDecoder.extract(SwiftUIConstants.linearBluePath),
                   let alpha: Float = try? paintDecoder.extract(SwiftUIConstants.opacityPath) {
                    self.init(linearRed: red, linearGreen: green, linearBlue: blue, opacity: alpha)
                    return
                }

                // Try color -> base path
                if let colorChild = paintDecoder.childIfPresent(SwiftUIConstants.colorPath) {
                    let colorDecoder = XrayDecoder(subject: colorChild)

                    if let baseChild = colorDecoder.childIfPresent(SwiftUIConstants.basePath) {
                        let baseDecoder = XrayDecoder(subject: baseChild)
                        let red: Float? = try? baseDecoder.extract(SwiftUIConstants.linearRedPath)
                        let green: Float? = try? baseDecoder.extract(SwiftUIConstants.linearGreenPath)
                        let blue: Float? = try? baseDecoder.extract(SwiftUIConstants.linearBluePath)
                        let alpha: Float? = try? baseDecoder.extract(SwiftUIConstants.opacityPath)

                        self.init(linearRed: red, linearGreen: green, linearBlue: blue, opacity: alpha)
                        return
                    }
                }
            }

            // Last resort: all nil
            self.init(linearRed: nil, linearGreen: nil, linearBlue: nil, opacity: nil)
        }
    }
}
