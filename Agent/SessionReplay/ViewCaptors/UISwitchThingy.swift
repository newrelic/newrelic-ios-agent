//
//  UISwitchThingy.swift
//  Agent
//
//  Created by Diego Martinez on 3/17/26.
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation
import UIKit
@_implementationOnly import NewRelicPrivate

#if os(iOS)
class UISwitchThingy: SessionReplayViewThingy {
    var isMasked: Bool
    var isBlocked: Bool
    var subviews = [any SessionReplayViewThingy]()

    var shouldRecordSubviews: Bool {
        false
    }

    var viewDetails: ViewDetails

    // UISwitch-specific properties
    let isOn: Bool
    let onTintColor: UIColor
    let thumbTintColor: UIColor
    let offTintColor: UIColor

    init(view: UISwitch, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        self.isBlocked = viewDetails.blockView ?? false
        // Respect masking if explicitly set
        if let isMasked = viewDetails.isMasked {
            self.isMasked = isMasked
        } else {
            self.isMasked = false // Default to not masked for switches
        }

        // Capture UISwitch properties
        self.isOn = view.isOn

        // Capture colors with defaults matching iOS system appearance
        self.onTintColor = view.onTintColor ?? UIColor.systemGreen
        self.thumbTintColor = view.thumbTintColor ?? UIColor.white

        // For off state, use tintColor if available, otherwise default gray
        if let tintColor = view.tintColor, tintColor != UIColor.clear {
            self.offTintColor = tintColor
        } else {
            // iOS default off color is a light gray
            self.offTintColor = UIColor(red: 0.78, green: 0.78, blue: 0.80, alpha: 1.0)
        }
    }

    func cssDescription() -> String {
        let onColor = onTintColor.toHexString(includingAlpha: true)
        let offColor = offTintColor.toHexString(includingAlpha: true)
        let thumbColor = thumbTintColor.toHexString(includingAlpha: true)
        let thumbHeight = viewDetails.frame.size.height - 4
        let thumbWidth = thumbHeight * 1.5 // Make it pill-shaped (wider than tall)
        let translateDistance = viewDetails.frame.size.width - thumbWidth - 4

        return """
        .switch#\(viewDetails.cssSelector) {
        }
        .switch#\(viewDetails.cssSelector) input {
            opacity: 0;
            width: 0;
            height: 0;
        }
        .switch#\(viewDetails.cssSelector) .slider {
            position: absolute;
            cursor: pointer;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background-color: \(offColor);
            transition: 0.4s;
            border-radius: \(String(format: "%.2f", viewDetails.frame.size.height / 2))px;
        }
        .switch#\(viewDetails.cssSelector) .slider:before {
            position: absolute;
            content: "";
            height: \(String(format: "%.2f", thumbHeight))px;
            width: \(String(format: "%.2f", thumbWidth))px;
            left: 2px;
            bottom: 2px;
            background-color: \(thumbColor);
            transition: 0.4s;
            border-radius: \(String(format: "%.2f", thumbHeight / 2))px;
        }
        .switch#\(viewDetails.cssSelector).checked .slider {
            background-color: \(onColor);
        }
        .switch#\(viewDetails.cssSelector).checked .slider:before {
            transform: translateX(\(String(format: "%.2f", translateDistance))px);
        }
        """
    }

    func generateRRWebNode() -> ElementNodeData {
        // Create hidden checkbox input
        let inputNode = ElementNodeData(
            id: viewDetails.viewId + 1,
            tagName: .input,
            attributes: [
                "type": "checkbox",
                "checked": isOn ? "checked" : ""
            ],
            childNodes: []
        )

        // Create slider span (thumb will be created by CSS ::before)
        let sliderNode = ElementNodeData(
            id: viewDetails.viewId + 2,
            tagName: .span,
            attributes: [
                "class": "slider round"
            ],
            childNodes: []
        )

        // Create label container (the .switch)
        return ElementNodeData(
            id: viewDetails.viewId,
            tagName: .label,
            attributes: [
                "id": viewDetails.cssSelector,
                "class": isOn ? "switch checked" : "switch",
                "style": "\(generateBaseCSSStyle()) display: inline-block;"
            ],
            childNodes: [.element(inputNode), .element(sliderNode)]
        )
    }

    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        // Create hidden checkbox input
        let inputNode = ElementNodeData(
            id: viewDetails.viewId + 1,
            tagName: .input,
            attributes: [
                "type": "checkbox",
                "checked": isOn ? "checked" : ""
            ],
            childNodes: []
        )

        // Create slider span (thumb will be created by CSS ::before)
        let sliderNode = ElementNodeData(
            id: viewDetails.viewId + 2,
            tagName: .span,
            attributes: [
                "class": "slider round"
            ],
            childNodes: []
        )

        // Create label container (the .switch)
        let node = ElementNodeData(
            id: viewDetails.viewId,
            tagName: .label,
            attributes: [
                "id": viewDetails.cssSelector,
                "class": isOn ? "switch checked" : "switch",
                "style": "\(generateBaseCSSStyle()) display: inline-block;"
            ],
            childNodes: [.element(inputNode), .element(sliderNode)]
        )

        return [.init(parentId: parentNodeId, nextId: viewDetails.nextId, node: .element(node))]
    }

    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? UISwitchThingy else { return [] }
        var mutations = [MutationRecord]()

        let labelId = viewDetails.viewId
        let inputId = viewDetails.viewId + 1

        // Check if anything changed
        if self != typedOther {
            // Always update style (includes position) and class
            let labelAttributes: [String: String] = [
                "style": "\(typedOther.generateBaseCSSStyle()) display: inline-block;",
                "class": typedOther.isOn ? "switch checked" : "switch"
            ]
            mutations.append(RRWebMutationData.AttributeRecord(id: labelId, attributes: labelAttributes))

            // Update checkbox checked state
            let inputAttributes: [String: String] = [
                "checked": typedOther.isOn ? "checked" : ""
            ]
            mutations.append(RRWebMutationData.AttributeRecord(id: inputId, attributes: inputAttributes))
        }

        return mutations
    }
}

extension UISwitchThingy: Equatable {
    static func == (lhs: UISwitchThingy, rhs: UISwitchThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails &&
            lhs.isOn == rhs.isOn &&
            lhs.onTintColor == rhs.onTintColor &&
            lhs.thumbTintColor == rhs.thumbTintColor &&
            lhs.offTintColor == rhs.offTintColor
    }
}

extension UISwitchThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
        hasher.combine(isOn)
        hasher.combine(onTintColor)
        hasher.combine(thumbTintColor)
        hasher.combine(offTintColor)
    }
}
#endif
