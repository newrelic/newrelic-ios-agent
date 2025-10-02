//
//  SwiftUIConstants.swift
//  Agent
//
//  Created by Chris Dillard on 9/26/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

enum SwiftUIConstants: String {

    case UIGraphicsView = "SwiftUI._UIGraphicsView"
    case text = "text"
    case storage = "storage"
    case color = "color"
    case drawing = "drawing"
    case shape = "shape"
    case image = "image"
    case platformView = "platformView"
    case container = "container"
    case value = "value"
    case renderer = "renderer"
    case items = "items"
    case identity = "identity"
    case frame = "frame"
    case viewCache = "viewCache"
    case lastList = "lastList"
    case view = "view"
    case layer = "layer"
    case maskColor = "maskColor"
    case seed = "seed"

    case effect = "effect"
    case content = "content"
    case map = "map"
    case id = "id"

    case clip = "clip"
    case filter = "filter"
    case platformGroup = "platformGroup"
    case colorMultiply = "colorMultiply"

    case base = "base"

    // MARK: - RunTimeTypeInspector.Path Computed Properties
    static var textPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(text.rawValue) }
    static var storagePath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(storage.rawValue) }
    static var colorPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(color.rawValue) }
    static var drawingPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(drawing.rawValue) }
    static var shapePath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(shape.rawValue) }
    static var imagePath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(image.rawValue) }
    static var platformViewPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(platformView.rawValue) }
    static var containerPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(container.rawValue) }
    static var valuePath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(value.rawValue) }
    static var rendererPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(renderer.rawValue) }
    static var itemsPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(items.rawValue) }
    static var identityPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(identity.rawValue) }
    static var framePath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(frame.rawValue) }
    static var viewCachePath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(viewCache.rawValue) }
    static var lastListPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(lastList.rawValue) }
    static var viewPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(view.rawValue) }
    static var layerPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(layer.rawValue) }
    static var maskColorPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(maskColor.rawValue) }
    static var seedPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(seed.rawValue) }
    static var effectPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(effect.rawValue) }
    static var contentPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(content.rawValue) }
    static var mapPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(map.rawValue) }
    static var idPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(id.rawValue) }
    static var clipPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(clip.rawValue) }
    static var filterPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(filter.rawValue) }
    static var platformGroupPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(platformGroup.rawValue) }
    static var colorMultiplyPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(colorMultiply.rawValue) }
    
    static var basePath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path(base.rawValue) }
    
    // make static path strucutre like above for linearRed linearGreen linearBlue opacity
    static var linearRedPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path("linearRed") }
    static var linearGreenPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path("linearGreen") }
    static var linearBluePath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path("linearBlue") }
    static var opacityPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path("opacity") }
    
    static var headroomPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path("_headroom") }
    
    static var paintPath: RunTimeTypeInspector.Path { RunTimeTypeInspector.Path("paint") }
}
enum DrawingConstants {
    static let maxSize = 1024
    static let targetClass: AnyClass? = NSClassFromString("RBMovedDisplayListContents")
    static let renderSelector = NSSelectorFromString("renderInContext:options:")
    static let boundingRectKey = "boundingRect"
    static let rasterScaleKey = "rasterizationscale"
}
