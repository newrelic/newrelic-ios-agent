//
//  SwiftUIShapeThingyTests.swift
//  NewRelicAgentTests
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation
import XCTest
import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
class SwiftUIShapeThingyTests: XCTestCase {

    // MARK: - Test Helpers

    func makeViewDetails(
        frame: CGRect = CGRect(x: 10, y: 20, width: 100, height: 50),
        clip: CGRect = CGRect(x: 0, y: 0, width: 200, height: 200),
        viewId: Int = 42,
        parentId: Int = 1,
        isMasked: Bool? = nil
    ) -> ViewDetails {
        return ViewDetails(
            frame: frame,
            clip: clip,
            backgroundColor: .clear,
            alpha: 1.0,
            isHidden: false,
            viewName: "SwiftUIShapeView",
            parentId: parentId,
            cornerRadius: 0,
            borderWidth: 0,
            borderColor: nil,
            viewId: viewId,
            view: nil,
            maskApplicationText: nil,
            maskUserInputText: nil,
            maskAllImages: isMasked,
            maskAllUserTouches: nil, blockView: nil,
            sessionReplayIdentifier: nil
        )
    }

    func makeTestPath() -> SwiftUI.Path {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 50))
        path.addLine(to: CGPoint(x: 0, y: 50))
        path.closeSubpath()
        return path
    }

    func makeTestColor(red: Float = 1.0, green: Float = 0.0, blue: Float = 0.0, alpha: Float = 1.0) -> ResolvedColor {
        return ResolvedColor(
            linearRed: red,
            linearGreen: green,
            linearBlue: blue,
            opacity: alpha
        )
    }

    // MARK: - Initialization Tests

    func testInit() {
        let details = makeViewDetails(isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        XCTAssertEqual(thingy.viewDetails.viewId, 42)
        XCTAssertFalse(thingy.isMasked)
        XCTAssertTrue(thingy.shouldRecordSubviews)
        XCTAssertTrue(thingy.subviews.isEmpty)
    }

    // MARK: - CSS Generation Tests

    func testCSSDescription() {
        let details = makeViewDetails(
            frame: CGRect(x: 10, y: 20, width: 100, height: 50),
            viewId: 42,
            isMasked: false
        )
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let css = thingy.cssDescription()
        XCTAssertTrue(css.contains("#SwiftUIShapeView-42"))
        XCTAssertTrue(css.contains("position: fixed"))
        XCTAssertTrue(css.contains("left: 10.00px"))
        XCTAssertTrue(css.contains("top: 20.00px"))
        XCTAssertTrue(css.contains("width: 100.00px"))
        XCTAssertTrue(css.contains("height: 50.00px"))
    }

    func testInlineCSSDescription() {
        let details = makeViewDetails(frame: CGRect(x: 10, y: 20, width: 100, height: 50), isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let css = thingy.inlineCSSDescription()
        XCTAssertTrue(css.contains("display: block"))
        XCTAssertTrue(css.contains("position: fixed"))
        XCTAssertTrue(css.contains("background-color: #00000000"))

        // Test shape inline CSS
        let shapeCss = thingy.shapeInlineCSSDescription()
        XCTAssertTrue(shapeCss.contains("overflow: hidden"))
    }

    // MARK: - SVG Path Conversion Tests

    func testConvertPathToSVGData_Rectangle() {
        let details = makeViewDetails(isMasked: false)
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        path.addLine(to: CGPoint(x: 0, y: 10))
        path.closeSubpath()

        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        // Use reflection or the node generation to verify path data
        let node = thingy.generateRRWebNode()
        // The structure is: container > shape div > SVG > path
        if case .element(let shapeDiv) = node.childNodes.first,
           case .element(let svgElement) = shapeDiv.childNodes.first,
           case .element(let pathElement) = svgElement.childNodes.first {
            let pathData = pathElement.attributes["d"] ?? ""
            XCTAssertTrue(pathData.contains("M 0.0 0.0"))
            XCTAssertTrue(pathData.contains("L 10.0 0.0"))
            XCTAssertTrue(pathData.contains("L 10.0 10.0"))
            XCTAssertTrue(pathData.contains("L 0.0 10.0"))
            XCTAssertTrue(pathData.contains("Z"))
        } else {
            XCTFail("Expected path element in SVG")
        }
    }

    func testConvertPathToSVGData_Curve() {
        let details = makeViewDetails(isMasked: false)
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addCurve(
            to: CGPoint(x: 100, y: 100),
            control1: CGPoint(x: 50, y: 0),
            control2: CGPoint(x: 50, y: 100)
        )

        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let node = thingy.generateRRWebNode()
        if case .element(let shapeDiv) = node.childNodes.first,
           case .element(let svgElement) = shapeDiv.childNodes.first,
           case .element(let pathElement) = svgElement.childNodes.first {
            let pathData = pathElement.attributes["d"] ?? ""
            XCTAssertTrue(pathData.contains("M 0.0 0.0"))
            XCTAssertTrue(pathData.contains("C"))
        } else {
            XCTFail("Expected path element in SVG")
        }
    }

    // MARK: - Fill Color Tests

    func testGetFillColorHex_Red() {
        let details = makeViewDetails(isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let node = thingy.generateRRWebNode()
        if case .element(let shapeDiv) = node.childNodes.first,
           case .element(let svgElement) = shapeDiv.childNodes.first,
           case .element(let pathElement) = svgElement.childNodes.first {
            let fillColor = pathElement.attributes["fill"] ?? ""
            XCTAssertTrue(fillColor.hasPrefix("#"))
            XCTAssertEqual(fillColor.count, 9) // #RRGGBBAA format
        } else {
            XCTFail("Expected path element in SVG")
        }
    }

    func testGetFillColorHex_Transparent() {
        let details = makeViewDetails(isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let node = thingy.generateRRWebNode()
        if case .element(let shapeDiv) = node.childNodes.first,
           case .element(let svgElement) = shapeDiv.childNodes.first,
           case .element(let pathElement) = svgElement.childNodes.first {
            let fillColor = pathElement.attributes["fill"] ?? ""
            XCTAssertTrue(fillColor.hasSuffix("00")) // Alpha should be 00
        } else {
            XCTFail("Expected path element in SVG")
        }
    }

    // MARK: - Fill Rule Tests

    func testGetFillRule_NonZero() {
        let details = makeViewDetails(isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle(eoFill: false)

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let node = thingy.generateRRWebNode()
        if case .element(let shapeDiv) = node.childNodes.first,
           case .element(let svgElement) = shapeDiv.childNodes.first,
           case .element(let pathElement) = svgElement.childNodes.first {
            let fillRule = pathElement.attributes["fill-rule"] ?? ""
            XCTAssertEqual(fillRule, "nonzero")
        } else {
            XCTFail("Expected path element in SVG")
        }
    }

    func testGetFillRule_EvenOdd() {
        let details = makeViewDetails(isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle(eoFill: true)

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let node = thingy.generateRRWebNode()
        if case .element(let shapeDiv) = node.childNodes.first,
           case .element(let svgElement) = shapeDiv.childNodes.first,
           case .element(let pathElement) = svgElement.childNodes.first {
            let fillRule = pathElement.attributes["fill-rule"] ?? ""
            XCTAssertEqual(fillRule, "evenodd")
        } else {
            XCTFail("Expected path element in SVG")
        }
    }

    // MARK: - RRWeb Node Generation Tests (Full Snapshot)

    func testGenerateRRWebNode_ContainerStructure() {
        let details = makeViewDetails(viewId: 42, isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let node = thingy.generateRRWebNode()

        // Verify container div
        XCTAssertEqual(node.id, 42)
        XCTAssertEqual(node.tagName, .div)
        XCTAssertEqual(node.attributes["id"], "SwiftUIShapeView-42")
        XCTAssertNotNil(node.attributes["style"])
        XCTAssertEqual(node.childNodes.count, 1)
    }

    func testGenerateRRWebNode_SVGStructure() {
        let details = makeViewDetails(
            frame: CGRect(x: 0, y: 0, width: 100, height: 50),
            viewId: 42,
            isMasked: false
        )
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let node = thingy.generateRRWebNode()

        // Verify shape div and SVG element
        if case .element(let shapeDiv) = node.childNodes.first,
           case .element(let svgElement) = shapeDiv.childNodes.first {
            XCTAssertEqual(svgElement.id, 42 + 3000000)
            XCTAssertEqual(svgElement.tagName, .svg)
            XCTAssertEqual(svgElement.attributes["viewBox"], "0 0 100.0 50.0")
            XCTAssertEqual(svgElement.attributes["width"], "100%")
            XCTAssertEqual(svgElement.attributes["height"], "100%")
            XCTAssertEqual(svgElement.attributes["preserveAspectRatio"], "none")
            XCTAssertEqual(svgElement.isSVG, true)
            XCTAssertEqual(svgElement.childNodes.count, 1)
        } else {
            XCTFail("Expected SVG element in shape div")
        }
    }

    func testGenerateRRWebNode_PathStructure() {
        let details = makeViewDetails(viewId: 42, isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let node = thingy.generateRRWebNode()

        // Verify path element
        if case .element(let shapeDiv) = node.childNodes.first,
           case .element(let svgElement) = shapeDiv.childNodes.first,
           case .element(let pathElement) = svgElement.childNodes.first {
            XCTAssertEqual(pathElement.id, 42 + 2000000)
            XCTAssertEqual(pathElement.tagName, .path)
            XCTAssertNotNil(pathElement.attributes["d"])
            XCTAssertNotNil(pathElement.attributes["fill"])
            XCTAssertNotNil(pathElement.attributes["fill-rule"])
            XCTAssertEqual(pathElement.isSVG, true)
            XCTAssertTrue(pathElement.childNodes.isEmpty)
        } else {
            XCTFail("Expected path element in SVG")
        }
    }

    // MARK: - RRWeb Addition Node Tests (Mutations)

    func testGenerateRRWebAdditionNode_ReturnsSeparateRecords() {
        let details = makeViewDetails(viewId: 42, parentId: 10, isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let records = thingy.generateRRWebAdditionNode(parentNodeId: 10)

        // Should return 4 separate AddRecords: container, shape, svg, path
        XCTAssertEqual(records.count, 4)
    }

    func testGenerateRRWebAdditionNode_ContainerRecord() {
        var details = makeViewDetails(viewId: 42, parentId: 10, isMasked: false)
        details.nextId = 99
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let records = thingy.generateRRWebAdditionNode(parentNodeId: 10)

        // First record should be the container div
        XCTAssertEqual(records[0].parentId, 10)
        XCTAssertEqual(records[0].nextId, 99)

        if case .element(let containerNode) = records[0].node {
            XCTAssertEqual(containerNode.id, 42)
            XCTAssertEqual(containerNode.tagName, .div)
            XCTAssertEqual(containerNode.attributes["id"], "SwiftUIShapeView-42")
            XCTAssertNotNil(containerNode.attributes["style"])
            XCTAssertTrue(containerNode.childNodes.isEmpty) // Should be empty, not nested
        } else {
            XCTFail("Expected element node")
        }
    }

    func testGenerateRRWebAdditionNode_ShapeRecord() {
        let details = makeViewDetails(viewId: 42, parentId: 10, isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let records = thingy.generateRRWebAdditionNode(parentNodeId: 10)

        // Second record should be the shape div
        XCTAssertEqual(records[1].parentId, 42) // Parent is container
        XCTAssertNil(records[1].nextId)

        if case .element(let shapeNode) = records[1].node {
            XCTAssertEqual(shapeNode.id, 42 + 1000000)
            XCTAssertEqual(shapeNode.tagName, .div)
            XCTAssertNotNil(shapeNode.attributes["style"])
            XCTAssertTrue(shapeNode.childNodes.isEmpty) // Should be empty, not nested
        } else {
            XCTFail("Expected element node")
        }
    }

    func testGenerateRRWebAdditionNode_SVGRecord() {
        let details = makeViewDetails(
            frame: CGRect(x: 0, y: 0, width: 100, height: 50),
            viewId: 42,
            parentId: 10,
            isMasked: false
        )
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let records = thingy.generateRRWebAdditionNode(parentNodeId: 10)

        // Third record should be the SVG element
        XCTAssertEqual(records[2].parentId, 42 + 1000000) // Parent is shape div
        XCTAssertNil(records[2].nextId)

        if case .element(let svgNode) = records[2].node {
            XCTAssertEqual(svgNode.id, 42 + 3000000)
            XCTAssertEqual(svgNode.tagName, .svg)
            XCTAssertEqual(svgNode.attributes["viewBox"], "0 0 100.0 50.0")
            XCTAssertEqual(svgNode.isSVG, true)
            XCTAssertTrue(svgNode.childNodes.isEmpty) // Should be empty, not nested
        } else {
            XCTFail("Expected element node")
        }
    }

    func testGenerateRRWebAdditionNode_PathRecord() {
        let details = makeViewDetails(viewId: 42, parentId: 10, isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let records = thingy.generateRRWebAdditionNode(parentNodeId: 10)

        // Fourth record should be the path element
        XCTAssertEqual(records[3].parentId, 42 + 3000000) // Parent is SVG
        XCTAssertNil(records[3].nextId)

        if case .element(let pathNode) = records[3].node {
            XCTAssertEqual(pathNode.id, 42 + 2000000)
            XCTAssertEqual(pathNode.tagName, .path)
            XCTAssertNotNil(pathNode.attributes["d"])
            XCTAssertNotNil(pathNode.attributes["fill"])
            XCTAssertNotNil(pathNode.attributes["fill-rule"])
            XCTAssertEqual(pathNode.isSVG, true)
            XCTAssertTrue(pathNode.childNodes.isEmpty)
        } else {
            XCTFail("Expected element node")
        }
    }

    // MARK: - Difference Generation Tests

    func testGenerateDifference_NoChanges() {
        let details = makeViewDetails(isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy1 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let thingy2 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let mutations = thingy1.generateDifference(from: thingy2)

        // Should have mutations for container and shape div styles
        XCTAssertTrue(mutations.count == 2)
    }

    func testGenerateDifference_FrameChange() {
        let details1 = makeViewDetails(frame: CGRect(x: 10, y: 20, width: 100, height: 50), isMasked: false)
        let details2 = makeViewDetails(frame: CGRect(x: 20, y: 30, width: 100, height: 50), isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy1 = SwiftUIShapeThingy(
            viewDetails: details1,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let thingy2 = SwiftUIShapeThingy(
            viewDetails: details2,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let mutations = thingy1.generateDifference(from: thingy2)

        // Frame change should result in style attribute mutation
        XCTAssertFalse(mutations.isEmpty)
    }

    func testGenerateDifference_ColorChange() {
        let details = makeViewDetails(isMasked: false)
        let path = makeTestPath()
        let color1 = makeTestColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let color2 = makeTestColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        let fillStyle = SwiftUI.FillStyle()

        let thingy1 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color1,
            fillStyle: fillStyle
        )

        let thingy2 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color2,
            fillStyle: fillStyle
        )

        let mutations = thingy1.generateDifference(from: thingy2)

        // Color change should result in path attribute mutation
        XCTAssertFalse(mutations.isEmpty)
    }

    func testGenerateDifference_PathChange() {
        let details = makeViewDetails(isMasked: false)

        var path1 = SwiftUI.Path()
        path1.addRect(CGRect(x: 0, y: 0, width: 10, height: 10))

        var path2 = SwiftUI.Path()
        path2.addEllipse(in: CGRect(x: 0, y: 0, width: 10, height: 10))

        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy1 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path1,
            fillColor: color,
            fillStyle: fillStyle
        )

        let thingy2 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path2,
            fillColor: color,
            fillStyle: fillStyle
        )

        let mutations = thingy1.generateDifference(from: thingy2)

        // Path change should result in path attribute mutation
        XCTAssertFalse(mutations.isEmpty)
    }

    func testGenerateDifference_FillStyleChange() {
        let details = makeViewDetails(isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle1 = SwiftUI.FillStyle(eoFill: false)
        let fillStyle2 = SwiftUI.FillStyle(eoFill: true)

        let thingy1 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle1
        )

        let thingy2 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle2
        )

        let mutations = thingy1.generateDifference(from: thingy2)

        // Fill style change should result in path attribute mutation
        XCTAssertFalse(mutations.isEmpty)
    }

    func testGenerateDifference_WrongType() {
        let details = makeViewDetails(isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let otherThingy = UIViewThingy(viewDetails: details)

        let mutations = thingy.generateDifference(from: otherThingy)

        // Different types should return empty mutations
        XCTAssertTrue(mutations.isEmpty)
    }

    // MARK: - Equality Tests

    func testEquality_SameProperties() {
        let details = makeViewDetails(isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy1 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let thingy2 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        XCTAssertEqual(thingy1, thingy2)
    }

    func testEquality_DifferentPath() {
        let details = makeViewDetails(isMasked: false)

        var path1 = SwiftUI.Path()
        path1.addRect(CGRect(x: 0, y: 0, width: 10, height: 10))

        var path2 = SwiftUI.Path()
        path2.addRect(CGRect(x: 0, y: 0, width: 20, height: 20))

        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy1 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path1,
            fillColor: color,
            fillStyle: fillStyle
        )

        let thingy2 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path2,
            fillColor: color,
            fillStyle: fillStyle
        )

        XCTAssertNotEqual(thingy1, thingy2)
    }

    func testEquality_DifferentColor() {
        let details = makeViewDetails(isMasked: false)
        let path = makeTestPath()
        let color1 = makeTestColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let color2 = makeTestColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        let fillStyle = SwiftUI.FillStyle()

        let thingy1 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color1,
            fillStyle: fillStyle
        )

        let thingy2 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color2,
            fillStyle: fillStyle
        )

        XCTAssertNotEqual(thingy1, thingy2)
    }

    // MARK: - Masking Tests

    func testMaskedShape_GenerateRRWebNode() {
        let details = makeViewDetails(viewId: 42, isMasked: true)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let node = thingy.generateRRWebNode()

        // Verify container div
        XCTAssertEqual(node.id, 42)
        XCTAssertEqual(node.childNodes.count, 1)

        // Verify shape div is masked
        if case .element(let shapeDiv) = node.childNodes.first {
            XCTAssertEqual(shapeDiv.id, 42 + 1000000)
            XCTAssertEqual(shapeDiv.attributes["data-nr-masked"], "image")
            XCTAssertTrue(shapeDiv.childNodes.isEmpty) // No SVG when masked
            XCTAssertTrue(shapeDiv.attributes["style"]?.contains("background: #CCCCCC;") ?? false)
        } else {
            XCTFail("Expected shape div in container")
        }
    }

    func testMaskedShape_GenerateRRWebAdditionNode() {
        let details = makeViewDetails(viewId: 42, parentId: 10, isMasked: true)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let records = thingy.generateRRWebAdditionNode(parentNodeId: 10)

        // Should return only 2 records when masked: container, shape
        XCTAssertEqual(records.count, 2)

        // Verify shape record is masked
        if case .element(let shapeNode) = records[1].node {
            XCTAssertEqual(shapeNode.attributes["data-nr-masked"], "shape")
            XCTAssertTrue(shapeNode.childNodes.isEmpty)
        } else {
            XCTFail("Expected element node")
        }
    }

    // MARK: - Hashable Tests

    func testHashable_SameProperties() {
        let details = makeViewDetails(isMasked: false)
        let path = makeTestPath()
        let color = makeTestColor()
        let fillStyle = SwiftUI.FillStyle()

        let thingy1 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        let thingy2 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color,
            fillStyle: fillStyle
        )

        XCTAssertEqual(thingy1.hashValue, thingy2.hashValue)
    }

    func testHashable_DifferentProperties() {
        let details = makeViewDetails(isMasked: false)
        let path = makeTestPath()
        let color1 = makeTestColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let color2 = makeTestColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        let fillStyle = SwiftUI.FillStyle()

        let thingy1 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color1,
            fillStyle: fillStyle
        )

        let thingy2 = SwiftUIShapeThingy(
            viewDetails: details,
            path: path,
            fillColor: color2,
            fillStyle: fillStyle
        )

        // Different properties should typically result in different hash values
        // (though hash collisions are technically possible)
        XCTAssertNotEqual(thingy1.hashValue, thingy2.hashValue)
    }
}
