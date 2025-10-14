//
//  SwiftUIColor.swift
//  Agent
//
//  Created by Chris Dillard on 9/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUI.Color {
    struct _ResFoundColor: Hashable {
        let linearRed: Float
        let linearGreen: Float
        let linearBlue: Float
        let opacity: Float
        
        var uiColor: UIColor {
            UIColor(red: CGFloat(linearRed),
                    green: CGFloat(linearGreen),
                    blue: CGFloat(linearBlue),
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
    let color: SwiftUI.Color._ResHighDef
}

@available(iOS 13.0, tvOS 13.0, *)
internal struct ResolvedColor: Hashable {
    let paint: SwiftUI.Color._ResFoundColor?
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
            r.get(SwiftUIConstants.linearRedPath,r),
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
        color = try r.get(SwiftUIConstants.colorPath,r)
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension ResolvedColor: XrayConvertible {
    init(xray r: XrayDecoder) throws {
        if #available(iOS 26, tvOS 26, *) {
            paint = r.childIfPresent(type: ColorView.self, SwiftUIConstants.paintPath)?.color.base
        }
        else {
            paint = r.getIfPresent(SwiftUIConstants.paintPath,r)
        }
    }
}
