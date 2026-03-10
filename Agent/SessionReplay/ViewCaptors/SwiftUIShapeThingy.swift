//
//  SwiftUIShapeThingy.swift
//  Agent
//
//  Created by Mike Bruin on 2/2/26.
//  Copyright © 2026 New Relic. All rights reserved.
//

import SwiftUI
import UIKit

@available(iOS 13.0, tvOS 13.0, *)
class SwiftUIShapeThingy: SessionReplayViewThingy {
    var viewDetails: ViewDetails
    var isMasked: Bool
    var isBlocked: Bool
    let path: SwiftUI.Path
    let fillColor: ResolvedColor
    let fillStyle: SwiftUI.FillStyle

    var shouldRecordSubviews: Bool {
        false
    }

    var subviews: [any SessionReplayViewThingy] = []

    init(viewDetails: ViewDetails, path: SwiftUI.Path, fillColor: ResolvedColor, fillStyle: SwiftUI.FillStyle) {
        self.viewDetails = viewDetails
        self.isMasked = viewDetails.isMasked ?? false
        self.isBlocked = viewDetails.blockView ?? false
        self.path = path
        self.fillColor = fillColor
        self.fillStyle = fillStyle
    }

    func cssDescription() -> String {
        return """
                #\(viewDetails.cssSelector) { \
                \(inlineCSSDescription())\
                }
                """
    }

    func inlineCSSDescription() -> String {
        return "\(generateBaseCSSStyle()) overflow: hidden;"
    }

    private func convertPathToSVGData() -> String {
        let cgPath = path.cgPath
        var pathData = ""

        cgPath.applyWithBlock { elementPtr in
            let element = elementPtr.pointee

            switch element.type {
            case .moveToPoint:
                let point = element.points[0]
                pathData += "M \(point.x) \(point.y) "

            case .addLineToPoint:
                let point = element.points[0]
                pathData += "L \(point.x) \(point.y) "

            case .addQuadCurveToPoint:
                let control = element.points[0]
                let end = element.points[1]
                pathData += "Q \(control.x) \(control.y) \(end.x) \(end.y) "

            case .addCurveToPoint:
                let control1 = element.points[0]
                let control2 = element.points[1]
                let end = element.points[2]
                pathData += "C \(control1.x) \(control1.y) \(control2.x) \(control2.y) \(end.x) \(end.y) "

            case .closeSubpath:
                pathData += "Z "

            @unknown default:
                break
            }
        }

        return pathData.trimmingCharacters(in: .whitespaces)
    }

    private func getFillColorHex() -> String {
        // First try to get the UIColor directly
        if let uiColor = fillColor.uiColor {
            return uiColor.toHexString(includingAlpha: true)
        }

        // Last resort: transparent
        return "#00000000"
    }

    private func getFillRule() -> String {
        return fillStyle.isEOFilled ? "evenodd" : "nonzero"
    }

    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        let svgPathData = convertPathToSVGData()
        let fillColorHex = getFillColorHex()
        let fillRule = getFillRule()

        // Create SVG path element
        let pathNode = ElementNodeData(
            id: viewDetails.viewId + 1000000,
            tagName: .path,
            attributes: [
                "d": svgPathData,
                "fill": fillColorHex,
                "fill-rule": fillRule
            ],
            childNodes: [],
            isSVG: true
        )

        // Create SVG element with viewBox matching the frame
        let svgNode = ElementNodeData(
            id: viewDetails.viewId + 2000000,
            tagName: .svg,
            attributes: [
                "viewBox": "0 0 \(viewDetails.frame.width) \(viewDetails.frame.height)",
                "width": "100%",
                "height": "100%",
                "preserveAspectRatio": "none"
            ],
            childNodes: [],
            isSVG: true
        )

        // Create container div
        let containerNode = ElementNodeData(
            id: viewDetails.viewId,
            tagName: .div,
            attributes: ["id": viewDetails.cssSelector],
            childNodes: []
        )
        containerNode.attributes["style"] = inlineCSSDescription()

        // Return separate AddRecords for each node (container, svg, path)
        // rrweb requires each node to be added individually with parent references
        let addContainerNode: RRWebMutationData.AddRecord = .init(
            parentId: parentNodeId,
            nextId: viewDetails.nextId,
            node: .element(containerNode)
        )
        let addSvgNode: RRWebMutationData.AddRecord = .init(
            parentId: viewDetails.viewId,
            nextId: nil,
            node: .element(svgNode)
        )
        let addPathNode: RRWebMutationData.AddRecord = .init(
            parentId: viewDetails.viewId + 2000000,
            nextId: nil,
            node: .element(pathNode)
        )

        return [addContainerNode, addSvgNode, addPathNode]
    }

    func generateRRWebNode() -> ElementNodeData {
        let svgPathData = convertPathToSVGData()
        let fillColorHex = getFillColorHex()
        let fillRule = getFillRule()

        // Create SVG path element
        let pathNode = ElementNodeData(
            id: viewDetails.viewId + 1000000,
            tagName: .path,
            attributes: [
                "d": svgPathData,
                "fill": fillColorHex,
                "fill-rule": fillRule
            ],
            childNodes: [],
            isSVG: true
        )

        // Create SVG element
        let svgNode = ElementNodeData(
            id: viewDetails.viewId + 2000000,
            tagName: .svg,
            attributes: [
                "viewBox": "0 0 \(viewDetails.frame.width) \(viewDetails.frame.height)",
                "width": "100%",
                "height": "100%",
                "preserveAspectRatio": "none"
            ],
            childNodes: [.element(pathNode)],
            isSVG: true
        )

        // Create and return container div
        let containerNode = ElementNodeData(
            id: viewDetails.viewId,
            tagName: .div,
            attributes: ["id": viewDetails.cssSelector, "style": inlineCSSDescription()],
            childNodes: [.element(svgNode)]
        )

        return containerNode
    }

    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? SwiftUIShapeThingy else {
            return []
        }

        var mutations = [MutationRecord]()

        // Check if we need to update the container style
        let newStyle = typedOther.inlineCSSDescription()
        var containerAttributes = [String: String]()
        containerAttributes["style"] = newStyle

        if !containerAttributes.isEmpty {
            let containerRecord = RRWebMutationData.AttributeRecord(
                id: viewDetails.viewId,
                attributes: containerAttributes
            )
            mutations.append(containerRecord)
        }

        // Check if the path or fill changed
        let oldPathData = convertPathToSVGData()
        let newPathData = typedOther.convertPathToSVGData()
        let oldFillColor = getFillColorHex()
        let newFillColor = typedOther.getFillColorHex()
        let oldFillRule = getFillRule()
        let newFillRule = typedOther.getFillRule()

        if oldPathData != newPathData || oldFillColor != newFillColor || oldFillRule != newFillRule {
            var pathAttributes = [String: String]()
            pathAttributes["d"] = newPathData
            pathAttributes["fill"] = newFillColor
            pathAttributes["fill-rule"] = newFillRule

            let pathRecord = RRWebMutationData.AttributeRecord(
                id: viewDetails.viewId + 1000000,
                attributes: pathAttributes
            )
            mutations.append(pathRecord)
        }

        return mutations
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIShapeThingy: Equatable {
    static func == (lhs: SwiftUIShapeThingy, rhs: SwiftUIShapeThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails &&
               lhs.convertPathToSVGData() == rhs.convertPathToSVGData() &&
               lhs.getFillColorHex() == rhs.getFillColorHex() &&
               lhs.getFillRule() == rhs.getFillRule()
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension SwiftUIShapeThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
        hasher.combine(convertPathToSVGData())
        hasher.combine(getFillColorHex())
        hasher.combine(getFillRule())
    }
}
