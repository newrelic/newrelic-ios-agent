//
//  DisplayList+XRAY.swift
//  Agent
//
//  Created by Chris Dillard on 9/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

//#if os(iOS)

import Foundation
import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIDisplayList: XrayConvertible {
    init(xray: XrayDecoder) throws {
        items = try xray.extract(SwiftUIConstants.itemsPath)
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIDisplayList.Identity: XrayConvertible {
    init(xray: XrayDecoder) throws {
        value = try xray.extract(SwiftUIConstants.valuePath)
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIDisplayList.DisplayListSeed: XrayConvertible {
    init(xray: XrayDecoder) throws {
        value = try xray.extract(SwiftUIConstants.valuePath)
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIDisplayList.ViewRenderer: XrayConvertible {
    init(xray: XrayDecoder) throws {
        renderer = try xray.extract(SwiftUIConstants.rendererPath)
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIDisplayList.SwiftUIViewUpdater: XrayConvertible {
    init(xray: XrayDecoder) throws {
        viewCache = try xray.extract(SwiftUIConstants.viewCachePath)
        lastList = try xray.extract(SwiftUIConstants.lastListPath)
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIDisplayList.Effect: XrayConvertible {
    init(xray: XrayDecoder) throws {
        let style = xray.displayStyle
        let child = xray.childIfPresent(0)

        switch style {
        case RunTimeTypeInspector.DisplayStyle.enum(SwiftUIConstants.identity.rawValue):
            self = SwiftUIDisplayList.Effect.identify

        case RunTimeTypeInspector.DisplayStyle.enum(SwiftUIConstants.clip.rawValue):
            if let tuple = child as? (SwiftUI.Path, SwiftUI.FillStyle, Any) {
                self = SwiftUIDisplayList.Effect.clip(tuple.0, tuple.1)
            } else {
                self = SwiftUIDisplayList.Effect.unknown
            }

        case RunTimeTypeInspector.DisplayStyle.enum(SwiftUIConstants.filter.rawValue):
            self = try SwiftUIDisplayList.Effect.filter(xray.xray(child))

        case RunTimeTypeInspector.DisplayStyle.enum(SwiftUIConstants.platformGroup.rawValue):
            self = SwiftUIDisplayList.Effect.platformGroup

        default:
            self = SwiftUIDisplayList.Effect.unknown
        }
    }
}

//#endif
