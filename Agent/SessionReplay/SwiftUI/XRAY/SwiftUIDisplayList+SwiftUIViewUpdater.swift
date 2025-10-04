//
//  DisplayList+SwiftUIViewUpdater.swift
//  Agent
//
//  Created by Chris Dillard on 10/1/25.
//  Copyright © 2025 New Relic. All rights reserved.
//
#if os(iOS)

import Foundation
import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIDisplayList.SwiftUIViewUpdater.ViewCache: XrayConvertible {
    init(xray: XrayDecoder) throws {
        map = try xray.extract(SwiftUIConstants.mapPath)
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIDisplayList.SwiftUIViewUpdater.ViewCache.CacheKey: XrayConvertible {
    init(xray: XrayDecoder) throws {
        id = try xray.extract(SwiftUIConstants.idPath)
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIDisplayList.Index.ID: XrayConvertible {
    init(xray: XrayDecoder) throws {
        identity = try xray.extract(SwiftUIConstants.identityPath)
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIDisplayList.SwiftUIViewUpdater.ViewInfo: XrayConvertible {
    init(xray: XrayDecoder) throws {
        let baseLayer: CALayer = try xray.extract(type: CALayer.self, SwiftUIConstants.layerPath)

        let hostView = xray.rawChildIfExists(type: UIView.self, SwiftUIConstants.viewPath)

        let metrics: (frame: CGRect, alpha: CGFloat, intrinsic: CGSize) = {
            if let hv = hostView {
                let containerView: UIView = (try? xray.extract(type: UIView.self, SwiftUIConstants.containerPath)) ?? UIView()
                let rectInHost = containerView.convert(containerView.bounds, to: hv)
                return (rectInHost, hv.alpha, containerView.intrinsicContentSize)
            } else {
                let containerLayer: CALayer = (try? xray.extract(type: CALayer.self, SwiftUIConstants.containerPath)) ?? CALayer()
                let frameInLayer = containerLayer.convert(containerLayer.bounds, to: baseLayer)
                let alpha = CGFloat(containerLayer.opacity)
                let size = containerLayer.preferredFrameSize()
                return (frameInLayer, alpha, size)
            }
        }()

        self.frame = metrics.frame
        self.alpha = metrics.alpha
        self.intrinsicContentSize = metrics.intrinsic

        self.borderWidth        = baseLayer.borderWidth
        self.cornerRadius       = baseLayer.cornerRadius
        self.backgroundColor    = baseLayer.backgroundColor?.safeColor
        self.borderColor        = baseLayer.borderColor?.safeColor
        self.isHidden           = baseLayer.isHidden
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIDisplayList.Content: XrayConvertible {
    init(xray: XrayDecoder) throws {
        seed = try xray.extract(SwiftUIConstants.seedPath)
        value = try xray.extract(SwiftUIConstants.valuePath)
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIDisplayList.Content.Value: XrayConvertible {
    init(xray: XrayDecoder) throws {
        guard case let .enum(caseName) = xray.displayStyle else {
            self = .unknown
            return
        }

        let child = xray.childIfPresent(0)

        switch caseName {
        case SwiftUIConstants.shape.rawValue:
            self = try Self.parseShape(xray, child)
        case SwiftUIConstants.text.rawValue:
            self = try Self.parseText(xray, child)
        case SwiftUIConstants.platformView.rawValue:
            self = .platformView
        case SwiftUIConstants.image.rawValue:
            self = try Self.parseImage(xray, child)
        case SwiftUIConstants.drawing.rawValue:
            self = Self.parseDrawing(child)
        case SwiftUIConstants.color.rawValue:
            self = try Self.parseColor(xray, child)
        default:
            self = SwiftUIDisplayList.Content.Value.unknown
        }
    }

    private static func parseShape(_ xray: XrayDecoder, _ child: Any?) throws -> Self {
        guard let tuple = child as? (SwiftUI.Path, Any, SwiftUI.FillStyle) else {
            return SwiftUIDisplayList.Content.Value.unknown
        }
        return try .shape(tuple.0, xray.xray(tuple.1), tuple.2)
    }

    private static func parseText(_ xray: XrayDecoder, _ child: Any?) throws -> Self {
        guard let tuple = child as? (Any, CGSize) else {
            return SwiftUIDisplayList.Content.Value.unknown
        }
        return try SwiftUIDisplayList.Content.Value.text(xray.xray(tuple.0), tuple.1)
    }

    private static func parseImage(_ xray: XrayDecoder, _ child: Any?) throws -> Self {
        guard let img = child else {
            return SwiftUIDisplayList.Content.Value.unknown
        }
        return try SwiftUIDisplayList.Content.Value.image(xray.xray(img))
    }

    private static func parseDrawing(_ child: Any?) -> Self {
        guard let (contents, origin, _) = child as? (NSObject, CGPoint, Any),
              let drawing = SwiftUIDrawingThingy(contents: contents, origin: origin) else {
            return SwiftUIDisplayList.Content.Value.unknown
        }
        return SwiftUIDisplayList.Content.Value.drawing(ErasedSwiftUIImageRepresentable(drawing))
    }

    private static func parseColor(_ xray: XrayDecoder, _ child: Any?) throws -> Self {
        guard let col = child else {
            return SwiftUIDisplayList.Content.Value.unknown
        }

        if #available(iOS 26, tvOS 26, *) {
            let cView = try xray.xray(type: ColorView.self, col)
            return SwiftUIDisplayList.Content.Value.color(cView.color.base)
        }
        else {
            let resolution = try xray.xray(col) as Color._ResFoundColor
            return SwiftUIDisplayList.Content.Value.color(resolution)
        }
    }
}
@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIDisplayList.DisplayListItem: XrayConvertible {
    init(xray: XrayDecoder) throws {
        identity = try xray.extract(SwiftUIConstants.identityPath)
        value = try xray.extract(SwiftUIConstants.valuePath)
        frame = try xray.extract(SwiftUIConstants.framePath)
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIDisplayList.DisplayListItem.Value: XrayConvertible {
    init(xray: XrayDecoder) throws {
        switch (xray.displayStyle, xray.childIfPresent(0)) {
        case let (RunTimeTypeInspector.DisplayStyle.enum(SwiftUIConstants.effect.rawValue), tuple as (Any, Any)):
            let p1 = try xray.xray(tuple.0) as SwiftUIDisplayList.Effect
            let p2 = try xray.xray(tuple.1) as SwiftUIDisplayList
            self = try SwiftUIDisplayList.DisplayListItem.Value.effect(p1,p2)

        case let (RunTimeTypeInspector.DisplayStyle.enum(SwiftUIConstants.content.rawValue), value):
            self = try SwiftUIDisplayList.DisplayListItem.Value.content(xray.xray(value))

        default:
            self = SwiftUIDisplayList.DisplayListItem.Value.unknown
        }
    }
}
#endif
