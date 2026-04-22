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

    func inlineCSSDescription() -> String {
        return "\(generateBaseCSSStyle()) display: inline-block;"
    }

    private var thumbHeight: CGFloat {
        return viewDetails.frame.size.height - 4
    }

    private var thumbWidth: CGFloat {
        return thumbHeight * 1.5 // pill-shaped
    }

    private var translateDistance: CGFloat {
        return viewDetails.frame.size.width - thumbWidth - 4
    }

    private func trackInlineStyle() -> String {
        let backgroundColor = isOn ? onTintColor : offTintColor
        let radius = viewDetails.frame.size.height / 2
        return """
        position: absolute; \
        top: 0; left: 0; right: 0; bottom: 0; \
        background-color: \(backgroundColor.toHexString(includingAlpha: true)); \
        border-radius: \(String(format: "%.2f", radius))px; \
        transition: background-color 0.4s;
        """
    }

    private func thumbInlineStyle() -> String {
        let thumbLeft = isOn ? (translateDistance + 2) : 2.0
        return """
        position: absolute; \
        top: 2px; \
        left: \(String(format: "%.2f", thumbLeft))px; \
        width: \(String(format: "%.2f", thumbWidth))px; \
        height: \(String(format: "%.2f", thumbHeight))px; \
        background-color: \(thumbTintColor.toHexString(includingAlpha: true)); \
        border-radius: \(String(format: "%.2f", thumbHeight / 2))px; \
        transition: left 0.4s;
        """
    }

    func generateRRWebNode() -> ElementNodeData {
        let trackNode = ElementNodeData(
            id: viewDetails.viewId + 1,
            tagName: .span,
            attributes: ["style": trackInlineStyle()],
            childNodes: []
        )

        let thumbNode = ElementNodeData(
            id: viewDetails.viewId + 2,
            tagName: .span,
            attributes: ["style": thumbInlineStyle()],
            childNodes: []
        )

        return ElementNodeData(
            id: viewDetails.viewId,
            tagName: .label,
            attributes: ["id": viewDetails.cssSelector,
                         "style": inlineCSSDescription()],
            childNodes: [.element(trackNode), .element(thumbNode)]
        )
    }

    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? UISwitchThingy else { return [] }
        var mutations = [MutationRecord]()

        if self != typedOther {
            mutations.append(RRWebMutationData.AttributeRecord(
                id: viewDetails.viewId,
                attributes: ["style": typedOther.inlineCSSDescription()]
            ))
            mutations.append(RRWebMutationData.AttributeRecord(
                id: viewDetails.viewId + 1,
                attributes: ["style": typedOther.trackInlineStyle()]
            ))
            mutations.append(RRWebMutationData.AttributeRecord(
                id: viewDetails.viewId + 2,
                attributes: ["style": typedOther.thumbInlineStyle()]
            ))
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
